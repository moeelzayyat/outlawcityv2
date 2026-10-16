--!strict
-- Pure economy rules: amount and transaction-id validation, grants, deductions, duplicate
-- protection, profile creation/validation and session-lock claims. No Instances, no clocks.
-- Unit-tested in ServerStorage.Tests.EconomyRules.spec.
local Types = require(script.Parent.Parent.Types)

local EconomyRules = {}

type Config = {
	StartingCash: number,
	MaxBalance: number,
	MaxTransaction: number,
	RecentTransactionLimit: number,
	TransactionIdMaxLength: number,
	ProfileVersion: number,
	StarterVehicles: { string },
	MaxOwnedVehicles: number,
	VehicleIdMaxLength: number,
	MaxPaidRewards: number,
	PaintIdMaxLength: number,
	MaxObjectives: number,
	MaxSettings: number,
	SettingKeyMaxLength: number,
}

local function isWholeFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge and n % 1 == 0
end

local function isWholeNonNegative(n: any): boolean
	return isWholeFinite(n) and n >= 0
end

local STAT_KEYS = { "Sprees", "Banked", "Busts", "PlayDays" }

local function newStats(): Types.ProfileStats
	return { Sprees = 0, Banked = 0, Busts = 0, PlayDays = 0 }
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- A full, independent copy of a profile (every field, every version). The only way profiles
-- are copied, so a new schema field can never be dropped by a hand-written copy.
function EconomyRules.cloneProfile(profile: Types.Profile): Types.Profile
	return deepCopy(profile)
end

-- Makes `target` hold exactly `source`'s fields (target keeps its identity; source is adopted,
-- not copied, so pass a fresh table).
function EconomyRules.assignProfile(target: Types.Profile, source: Types.Profile)
	local t = target :: any
	for key in t do
		if (source :: any)[key] == nil then
			t[key] = nil
		end
	end
	for key, value in source :: any do
		t[key] = value
	end
end

-- Amounts must be whole, finite, positive and no bigger than MaxTransaction.
function EconomyRules.validateAmount(amount: any, config: Config): (boolean, Types.EconomyError?)
	if not isWholeFinite(amount) or amount <= 0 or amount > config.MaxTransaction then
		return false, "InvalidAmount"
	end
	return true, nil
end

function EconomyRules.validateTransactionId(txId: any, config: Config): (boolean, Types.EconomyError?)
	if type(txId) ~= "string" or #txId == 0 or #txId > config.TransactionIdMaxLength then
		return false, "InvalidTransactionId"
	end
	return true, nil
end

function EconomyRules.newProfile(config: Config): Types.Profile
	return {
		Version = config.ProfileVersion,
		Cash = config.StartingCash,
		RecentTransactions = {},
		OwnedVehicles = table.clone(config.StarterVehicles),
		PaidRewards = {},
		Reputation = 0,
		BestSpree = 0,
		Customization = {},
		Stats = newStats(),
		Objectives = {},
		Settings = {},
	}
end

-- Checks saved data. nil (never saved) -> a new profile with starting cash. Valid data is
-- returned as-is (never reset to defaults). Anything malformed is reported as corrupt so the
-- caller refuses to load and never overwrites it.
function EconomyRules.validateSaved(saved: any, config: Config): (Types.Profile?, string?)
	if saved == nil then
		return EconomyRules.newProfile(config), "New"
	end
	if type(saved) ~= "table" or not isWholeFinite(saved.Cash) or saved.Cash < 0 or saved.Cash > config.MaxBalance then
		return nil, "Corrupt"
	end
	-- Version 1 records (cash only) predate the field being required.
	local version = if saved.Version == nil then 1 else saved.Version
	if not isWholeFinite(version) or version < 1 or version > config.ProfileVersion then
		return nil, "Corrupt" -- unknown or newer schema: never guess, never downgrade
	end
	local recent = {}
	if type(saved.RecentTransactions) == "table" then
		for _, txId in saved.RecentTransactions do
			if type(txId) == "string" then
				table.insert(recent, txId)
			end
		end
	end
	-- Ownership: starters always; from v2 on, the saved list (it must be a list).
	local owned = table.clone(config.StarterVehicles)
	if version >= 2 then
		if type(saved.OwnedVehicles) ~= "table" then
			return nil, "Corrupt" -- a v2 record without its ownership list is damaged, not empty
		end
		for _, vehicleId in saved.OwnedVehicles do
			if
				type(vehicleId) == "string"
				and #vehicleId > 0
				and #vehicleId <= config.VehicleIdMaxLength
				and not table.find(owned, vehicleId)
				and #owned < config.MaxOwnedVehicles
			then
				table.insert(owned, vehicleId)
			end
		end
	end
	-- Paid-reward ids (v3+, audit remediation): rewards paid from the ledger that the ledger may
	-- still list. Kept until the ledger no longer has them, so a reward can never be paid twice
	-- even after its id has left RecentTransactions.
	local paid = {}
	if version >= 3 then
		if type(saved.PaidRewards) ~= "table" then
			return nil, "Corrupt" -- a v3 record without its paid-reward list is damaged, not empty
		end
		for _, txId in saved.PaidRewards do
			if type(txId) == "string" and not table.find(paid, txId) then
				table.insert(paid, txId)
			end
		end
	end
	-- Progression and settings (v4+, architecture §6). Older records get defaults (migration).
	-- A v4 record missing a section or holding a bad number is damaged, not empty; bad entries
	-- inside the maps are dropped like bad vehicle ids.
	local reputation, bestSpree, stats = 0, 0, newStats()
	local customization: { [string]: string } = {}
	local objectives: { [string]: number } = {}
	local settings: { [string]: boolean | number } = {}
	if version >= 4 then
		if
			not isWholeNonNegative(saved.Reputation)
			or not isWholeNonNegative(saved.BestSpree)
			or type(saved.Stats) ~= "table"
			or type(saved.Customization) ~= "table"
			or type(saved.Objectives) ~= "table"
			or type(saved.Settings) ~= "table"
		then
			return nil, "Corrupt"
		end
		reputation, bestSpree = saved.Reputation, saved.BestSpree
		for _, key in STAT_KEYS do
			local value = saved.Stats[key]
			if value ~= nil then
				if not isWholeNonNegative(value) then
					return nil, "Corrupt"
				end
				(stats :: any)[key] = value
			end
		end
		local count = 0
		for vehicleId, paint in saved.Customization do
			if
				count < config.MaxOwnedVehicles
				and type(vehicleId) == "string"
				and #vehicleId > 0
				and #vehicleId <= config.VehicleIdMaxLength
				and type(paint) == "string"
				and #paint > 0
				and #paint <= config.PaintIdMaxLength
			then
				customization[vehicleId] = paint
				count += 1
			end
		end
		count = 0
		for id, progress in saved.Objectives do
			if count < config.MaxObjectives and type(id) == "string" and #id > 0 and #id <= config.SettingKeyMaxLength and isWholeNonNegative(progress) then
				objectives[id] = progress
				count += 1
			end
		end
		count = 0
		for name, value in saved.Settings do
			local okValue = type(value) == "boolean" or (type(value) == "number" and value == value and math.abs(value) ~= math.huge)
			if count < config.MaxSettings and type(name) == "string" and #name > 0 and #name <= config.SettingKeyMaxLength and okValue then
				settings[name] = value
				count += 1
			end
		end
	end
	return {
		Version = config.ProfileVersion,
		Cash = saved.Cash,
		RecentTransactions = recent,
		OwnedVehicles = owned,
		PaidRewards = paid,
		Reputation = reputation,
		BestSpree = bestSpree,
		Customization = customization,
		Stats = stats,
		Objectives = objectives,
		Settings = settings,
	}, if version < config.ProfileVersion then "Migrated" else "Existing"
end

function EconomyRules.hasTransaction(profile: Types.Profile, txId: string): boolean
	return table.find(profile.RecentTransactions, txId) ~= nil
end

local function remember(profile: Types.Profile, txId: string, config: Config)
	table.insert(profile.RecentTransactions, txId)
	while #profile.RecentTransactions > config.RecentTransactionLimit do
		table.remove(profile.RecentTransactions, 1)
	end
end

local function precheck(profile: Types.Profile, amount: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	local ok, err = EconomyRules.validateAmount(amount, config)
	if not ok then
		return false, err
	end
	ok, err = EconomyRules.validateTransactionId(txId, config)
	if not ok then
		return false, err
	end
	if EconomyRules.hasTransaction(profile, txId) then
		return false, "DuplicateTransaction"
	end
	return true, nil
end

function EconomyRules.canAfford(profile: Types.Profile, amount: number): boolean
	return isWholeFinite(amount) and amount >= 0 and profile.Cash >= amount
end

-- Adds cash once per transaction id. Never exceeds MaxBalance.
function EconomyRules.grant(profile: Types.Profile, amount: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	local ok, err = precheck(profile, amount, txId, config)
	if not ok then
		return false, err
	end
	if profile.Cash + amount > config.MaxBalance then
		return false, "BalanceCap"
	end
	profile.Cash += amount
	remember(profile, txId, config)
	return true, nil
end

-- Removes cash once per transaction id; refuses if the balance is too small (purchases).
function EconomyRules.deduct(profile: Types.Profile, amount: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	local ok, err = precheck(profile, amount, txId, config)
	if not ok then
		return false, err
	end
	if not EconomyRules.canAfford(profile, amount) then
		return false, "InsufficientFunds"
	end
	profile.Cash -= amount
	remember(profile, txId, config)
	return true, nil
end

function EconomyRules.ownsVehicle(profile: Types.Profile, vehicleId: string): boolean
	return table.find(profile.OwnedVehicles, vehicleId) ~= nil
end

-- Buys a vehicle: takes the price AND records ownership in one step on the same profile, so
-- they are always saved together (never cash without the car, never the car without cash).
-- The price comes from server config, never from the client.
function EconomyRules.purchaseVehicle(profile: Types.Profile, vehicleId: any, price: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	if type(vehicleId) ~= "string" or #vehicleId == 0 or #vehicleId > config.VehicleIdMaxLength then
		return false, "InvalidVehicle"
	end
	local ok, err = precheck(profile, price, txId, config)
	if not ok then
		return false, err
	end
	if EconomyRules.ownsVehicle(profile, vehicleId) then
		return false, "AlreadyOwned"
	end
	if #profile.OwnedVehicles >= config.MaxOwnedVehicles then
		return false, "TooManyVehicles"
	end
	if not EconomyRules.canAfford(profile, price) then
		return false, "InsufficientFunds"
	end
	profile.Cash -= price
	table.insert(profile.OwnedVehicles, vehicleId)
	remember(profile, txId, config)
	return true, nil
end

-- Pays a ledger reward once (audit remediation). Refuses a reward already in PaidRewards or in
-- the recent transaction ids ("DuplicateTransaction"), so it can't pay twice even after the id
-- has aged out of RecentTransactions. Records the id in PaidRewards in the same step.
function EconomyRules.payReward(profile: Types.Profile, amount: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	if type(txId) == "string" and table.find(profile.PaidRewards, txId) then
		return false, "DuplicateTransaction"
	end
	if #profile.PaidRewards >= config.MaxPaidRewards then
		return false, "RewardHistoryFull"
	end
	local ok, err = EconomyRules.grant(profile, amount, txId, config)
	if not ok then
		return false, err
	end
	table.insert(profile.PaidRewards, txId)
	return true, nil
end

-- Drops paid-reward ids the ledger no longer lists (they can never be claimed again).
-- Returns how many were dropped.
function EconomyRules.prunePaidRewards(profile: Types.Profile, stillInLedger: { string }): number
	local kept = {}
	for _, txId in profile.PaidRewards do
		if table.find(stillInLedger, txId) then
			table.insert(kept, txId)
		end
	end
	local dropped = #profile.PaidRewards - #kept
	profile.PaidRewards = kept
	return dropped
end

-- Banks a Crime Spree (S2.2): pays it once as a ledger reward (`txId` = "spree:<id>") and records
-- it in the profile stats in the same step: reputation, best spree, sprees and total banked.
function EconomyRules.bankSpree(profile: Types.Profile, amount: any, reputation: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	local ok, err = EconomyRules.payReward(profile, amount, txId, config)
	if not ok then
		return false, err
	end
	if isWholeNonNegative(reputation) then
		profile.Reputation += reputation
	end
	profile.BestSpree = math.max(profile.BestSpree, amount)
	profile.Stats.Sprees += 1
	profile.Stats.Banked += amount
	return true, nil
end

-- Counts a bust in the profile stats once per transaction id.
function EconomyRules.noteBust(profile: Types.Profile, txId: any, config: Config): (boolean, Types.EconomyError?)
	local ok, err = EconomyRules.validateTransactionId(txId, config)
	if not ok then
		return false, err
	end
	if EconomyRules.hasTransaction(profile, txId) then
		return false, "DuplicateTransaction"
	end
	profile.Stats.Busts += 1
	remember(profile, txId, config)
	return true, nil
end

-- Session lock: a server may claim a record when it is unlocked, already its own, or the
-- other server's lock is older than `timeout` seconds (that server crashed or hung).
function EconomyRules.canClaimLock(lock: any, sessionId: string, now: number, timeout: number): boolean
	if type(lock) ~= "table" or type(lock.Id) ~= "string" then
		return true
	end
	if lock.Id == sessionId then
		return true
	end
	return type(lock.At) ~= "number" or now - lock.At > timeout
end

return EconomyRules
