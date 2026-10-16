-- Profile v4 (architecture §6): the v3 -> v4 migration fixture, v4 validation, and the shared
-- profile copy helpers every write path uses.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)
local Assert = require(script.Parent.Assert)

local C = EconomyConfig

-- A v3 record as the live store holds it (JSON round-tripped), from a player who bought the
-- Muscle and has one ledger reward still listed.
local FIXTURE_V3 = [[{"Version":3,"Cash":4300,"RecentTransactions":["buy:muscle-1","robbery:Store1:abc"],"OwnedVehicles":["Coupe","Muscle"],"PaidRewards":["robbery:Store1:abc"]}]]

local function roundTrip(value: any): any
	return HttpService:JSONDecode(HttpService:JSONEncode(value))
end

local function v4(overrides: { [string]: any }?): { [string]: any }
	local record = {
		Version = 4,
		Cash = 100,
		RecentTransactions = {},
		OwnedVehicles = { "Coupe" },
		PaidRewards = {},
		Reputation = 0,
		BestSpree = 0,
		Customization = {},
		Stats = {},
		Objectives = {},
		Settings = {},
	}
	for key, value in overrides or {} do
		record[key] = value
	end
	return record
end

return {
	["the v3 fixture migrates to v4 keeping every v3 field and adding defaults"] = function()
		local p, kind = EconomyRules.validateSaved(HttpService:JSONDecode(FIXTURE_V3), C)
		Assert.equal(kind, "Migrated")
		Assert.equal(p.Version, 4)
		Assert.equal(p.Cash, 4300)
		Assert.equal(p.RecentTransactions[2], "robbery:Store1:abc")
		Assert.equal(EconomyRules.ownsVehicle(p, "Muscle"), true)
		Assert.equal(p.PaidRewards[1], "robbery:Store1:abc")
		Assert.equal(p.Reputation, 0)
		Assert.equal(p.BestSpree, 0)
		Assert.equal(p.Stats.Sprees, 0)
		Assert.equal(p.Stats.PlayDays, 0)
		Assert.equal(next(p.Customization), nil)
		Assert.equal(next(p.Objectives), nil)
		Assert.equal(next(p.Settings), nil)
	end,
	["a migrated profile round-trips through the store as Existing and unchanged"] = function()
		local p = EconomyRules.validateSaved(HttpService:JSONDecode(FIXTURE_V3), C)
		p.Reputation = 36
		p.BestSpree = 12400
		p.Customization.Muscle = "SunsetOrange"
		p.Stats.Busts = 2
		p.Objectives.Daily_ATM = 1
		p.Settings.Music = false
		local again, kind = EconomyRules.validateSaved(roundTrip(p), C)
		Assert.equal(kind, "Existing")
		Assert.equal(again.Cash, 4300)
		Assert.equal(again.Reputation, 36)
		Assert.equal(again.BestSpree, 12400)
		Assert.equal(again.Customization.Muscle, "SunsetOrange")
		Assert.equal(again.Stats.Busts, 2)
		Assert.equal(again.Objectives.Daily_ATM, 1)
		Assert.equal(again.Settings.Music, false)
	end,
	["a cash-only v1 record migrates straight to v4"] = function()
		local p, kind = EconomyRules.validateSaved({ Cash = 900, RecentTransactions = { "a" } }, C)
		Assert.equal(kind, "Migrated")
		Assert.equal(p.Version, C.ProfileVersion)
		Assert.equal(p.Cash, 900)
		Assert.equal(p.Stats.Banked, 0)
	end,
	["a v4 record missing a section or holding a bad number is Corrupt"] = function()
		for _, bad in {
			v4({ Reputation = -1 }),
			v4({ BestSpree = 0 / 0 }),
			v4({ Reputation = 1.5 }),
			v4({ Stats = "none" }),
			v4({ Stats = { Busts = -2 } }),
			v4({ Customization = 5 }),
			v4({ Objectives = "x" }),
			v4({ Settings = true }),
		} do
			local profile, why = EconomyRules.validateSaved(bad, C)
			Assert.equal(profile, nil)
			Assert.equal(why, "Corrupt")
		end
		local missing = v4()
		missing.Stats = nil
		Assert.equal((EconomyRules.validateSaved(missing, C)), nil, "v4 without Stats")
	end,
	["bad map entries are dropped and the maps are bounded"] = function()
		local customization = { Coupe = "Red", [""] = "Blue", Muscle = 7, Sport = string.rep("x", C.PaintIdMaxLength + 1) }
		local settings = { Music = true, Volume = 0.5, Bad = "loud", Inf = math.huge }
		local objectives: { [string]: any } = { Daily = 1, Neg = -1 }
		for i = 1, C.MaxObjectives + 5 do
			objectives[`o{i}`] = i
		end
		local p = EconomyRules.validateSaved(v4({ Customization = customization, Settings = settings, Objectives = objectives }), C)
		Assert.equal(p.Customization.Coupe, "Red")
		Assert.equal(p.Customization.Muscle, nil)
		Assert.equal(p.Customization.Sport, nil)
		Assert.equal(p.Settings.Music, true)
		Assert.equal(p.Settings.Volume, 0.5)
		Assert.equal(p.Settings.Bad, nil)
		Assert.equal(p.Settings.Inf, nil)
		Assert.equal(p.Objectives.Neg, nil)
		local count = 0
		for _ in p.Objectives do
			count += 1
		end
		Assert.equal(count, C.MaxObjectives)
	end,
	["cloneProfile is deep and assignProfile replaces every field"] = function()
		local p = EconomyRules.newProfile(C)
		p.Customization.Coupe = "Red"
		local copy = EconomyRules.cloneProfile(p)
		copy.Stats.Busts = 9
		copy.Customization.Coupe = "Blue"
		table.insert(copy.OwnedVehicles, "Muscle")
		Assert.equal(p.Stats.Busts, 0, "nested table not shared")
		Assert.equal(p.Customization.Coupe, "Red")
		Assert.equal(#p.OwnedVehicles, 1)
		local target = EconomyRules.newProfile(C)
		local identity = target
		;(target :: any).Stray = true
		EconomyRules.assignProfile(target, copy)
		Assert.equal(target, identity, "same table")
		Assert.equal(target.Stats.Busts, 9)
		Assert.equal((target :: any).Stray, nil, "fields the source lacks are removed")
	end,
}
