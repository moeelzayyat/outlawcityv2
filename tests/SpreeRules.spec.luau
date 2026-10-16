-- SpreeRules (S2.1): unbanked cash × multiplier, banking, bust, escape, reputation, caps, NaN.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpreeRules = require(ReplicatedStorage.Shared.Rules.SpreeRules)
local SpreeConfig = require(ReplicatedStorage.Shared.Config.SpreeConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Assert = require(script.Parent.Assert)

local C = SpreeConfig
local CLEAR = { InSafehouse = true, Seen = false, Observed = false, Jailed = false }

local function fresh()
	return SpreeRules.new(C)
end

local function withCrimes(n: number, base: number?)
	local s = fresh()
	for i = 1, n do
		SpreeRules.addCrime(s, "spree-1", base or 800, 1, 100 + i, C)
	end
	return s
end

local function bankFacts(overrides: { [string]: any })
	local f = table.clone(CLEAR) :: any
	for k, v in overrides do
		f[k] = v
	end
	return f
end

return {
	["defaults match the design"] = function()
		Assert.equal(C.MultiplierStart, 1.0)
		Assert.equal(C.MultiplierStep, 0.5)
		Assert.equal(C.MultiplierCap, 4.0)
		Assert.equal(C.BankSeconds, 5)
		Assert.equal(C.ReputationCap, 50)
		Assert.truthy(C.MaxUnbanked <= EconomyConfig.MaxTransaction, "a bank is one economy transaction")
	end,
	["a new player has no spree"] = function()
		local s = fresh()
		Assert.equal(s.Active, false)
		Assert.equal(s.Unbanked, 0)
		Assert.equal(SpreeRules.canBank(s), false)
	end,
	["the first crime starts a spree and pays base x 1.0"] = function()
		local s = fresh()
		local ok, err, added = SpreeRules.addCrime(s, "spree-1", 800, 1, 100, C)
		Assert.equal(ok, true, tostring(err))
		Assert.equal(added, 800)
		Assert.equal(s.Active, true)
		Assert.equal(s.Id, "spree-1")
		Assert.equal(s.StartedAt, 100)
		Assert.equal(s.Unbanked, 800)
		Assert.equal(s.Multiplier, 1.5, "the next crime pays more")
	end,
	["each crime raises the multiplier by 0.5"] = function()
		local s = fresh()
		local adds = {}
		for i = 1, 4 do
			local _, _, added = SpreeRules.addCrime(s, "spree-1", 1000, 1, i, C)
			table.insert(adds, added)
		end
		Assert.equal(adds[1], 1000)
		Assert.equal(adds[2], 1500)
		Assert.equal(adds[3], 2000)
		Assert.equal(adds[4], 2500)
		Assert.equal(s.Unbanked, 7000)
		Assert.equal(s.Crimes, 4)
	end,
	["the multiplier stops at the cap"] = function()
		local s = withCrimes(10, 100)
		Assert.equal(s.Multiplier, C.MultiplierCap)
		local _, _, added = SpreeRules.addCrime(s, "x", 100, 1, 999, C)
		Assert.equal(added, 400, "x4.0 at the cap")
	end,
	["fractional payouts round down"] = function()
		local s = withCrimes(1, 801) -- next crime x1.5
		local _, _, added = SpreeRules.addCrime(s, "x", 801, 1, 200, C)
		Assert.equal(added, 1201)
	end,
	["unbanked cash never exceeds MaxUnbanked"] = function()
		local s = fresh()
		for i = 1, 400 do
			SpreeRules.addCrime(s, "spree-1", 900000, 3, i, C)
		end
		Assert.equal(s.Unbanked, C.MaxUnbanked)
	end,
	["bad amounts and stars are refused and change nothing"] = function()
		local s = withCrimes(1)
		for _, case in { { 0 / 0, 1, "InvalidAmount" }, { -5, 1, "InvalidAmount" }, { 0, 1, "InvalidAmount" }, { 1.5, 1, "InvalidAmount" }, { math.huge, 1, "InvalidAmount" }, { "800", 1, "InvalidAmount" }, { 800, 0 / 0, "InvalidStars" }, { 800, -1, "InvalidStars" } } do
			local ok, err, added = SpreeRules.addCrime(s, "spree-1", case[1], case[2], 300, C)
			Assert.equal(ok, false)
			Assert.equal(err, case[3])
			Assert.equal(added, 0)
		end
		Assert.equal(s.Unbanked, 800)
		Assert.equal(s.Crimes, 1)
	end,
	["a spree needs an id to start"] = function()
		local ok, err = SpreeRules.addCrime(fresh(), "", 800, 1, 1, C)
		Assert.equal(ok, false)
		Assert.equal(err, "InvalidSpreeId")
	end,
	["peak stars remember the highest stars seen"] = function()
		local s = withCrimes(1)
		SpreeRules.noteStars(s, 3)
		SpreeRules.noteStars(s, 2)
		SpreeRules.noteStars(s, 0 / 0)
		Assert.equal(s.PeakStars, 3)
	end,
	["banking needs 5 continuous seconds inside a safehouse, unseen"] = function()
		local s = withCrimes(2)
		for _ = 1, 4 do
			Assert.equal(SpreeRules.stepBank(s, 1, CLEAR, C.BankSeconds), false)
		end
		Assert.equal(SpreeRules.stepBank(s, 1, CLEAR, C.BankSeconds), true)
	end,
	["any break in the conditions restarts banking"] = function()
		for _, broken in { { InSafehouse = false }, { Seen = true }, { Observed = true }, { Jailed = true } } do
			local s = withCrimes(1)
			SpreeRules.stepBank(s, 4, CLEAR, C.BankSeconds)
			Assert.equal(SpreeRules.stepBank(s, 1, bankFacts(broken), C.BankSeconds), false)
			Assert.equal(s.BankProgress, 0)
			Assert.equal(SpreeRules.stepBank(s, 4, CLEAR, C.BankSeconds), false, "starts over")
		end
	end,
	["a NaN or negative step never advances banking"] = function()
		local s = withCrimes(1)
		Assert.equal(SpreeRules.stepBank(s, 0 / 0, CLEAR, C.BankSeconds), false)
		Assert.equal(SpreeRules.stepBank(s, -10, CLEAR, C.BankSeconds), false)
		Assert.equal(SpreeRules.stepBank(s, math.huge, CLEAR, C.BankSeconds), false)
		Assert.equal(s.BankProgress, 0)
	end,
	["nothing to bank without a spree"] = function()
		local s = fresh()
		Assert.equal(SpreeRules.stepBank(s, 10, CLEAR, C.BankSeconds), false)
		Assert.equal(SpreeRules.bank(s, 10, C), nil)
	end,
	["banking pays the unbanked once and ends the spree"] = function()
		local s = withCrimes(3, 1000) -- 1000 + 1500 + 2000
		SpreeRules.noteStars(s, 2)
		local result = SpreeRules.bank(s, 160, C) :: SpreeRules.BankResult
		Assert.equal(result.SpreeId, "spree-1")
		Assert.equal(result.Amount, 4500)
		Assert.equal(result.Crimes, 3)
		Assert.equal(result.PeakStars, 2)
		Assert.equal(result.Duration, 59)
		Assert.equal(result.Reputation, 6)
		Assert.equal(s.Active, false)
		Assert.equal(s.Unbanked, 0)
		Assert.equal(s.Multiplier, C.MultiplierStart)
		Assert.equal(SpreeRules.bank(s, 161, C), nil, "never twice")
	end,
	["reputation is peak stars x crimes, capped"] = function()
		Assert.equal(SpreeRules.reputationFor(3, 4, C.ReputationCap), 12)
		Assert.equal(SpreeRules.reputationFor(3, 40, C.ReputationCap), C.ReputationCap)
		Assert.equal(SpreeRules.reputationFor(0 / 0, 4, C.ReputationCap), 0)
		Assert.equal(SpreeRules.reputationFor(0, 4, C.ReputationCap), 0)
	end,
	["a bust loses the unbanked cash and resets the multiplier"] = function()
		local s = withCrimes(3, 1000)
		local id, lost = SpreeRules.bust(s, C)
		Assert.equal(id, "spree-1")
		Assert.equal(lost, 4500)
		Assert.equal(s.Active, false)
		Assert.equal(s.Unbanked, 0)
		Assert.equal(s.Multiplier, C.MultiplierStart)
		local _, again = SpreeRules.bust(s, C)
		Assert.equal(again, 0, "nothing more to lose")
	end,
	["escaping keeps the spree and its multiplier"] = function()
		local s = withCrimes(2, 1000)
		SpreeRules.stepBank(s, 3, CLEAR, C.BankSeconds)
		Assert.equal(SpreeRules.onEscaped(s), true)
		Assert.equal(s.Unbanked, 2500)
		Assert.equal(s.Multiplier, 2.0)
		Assert.equal(s.BankProgress, 0)
	end,
	["a new crime after banking starts a fresh spree at x1.0"] = function()
		local s = withCrimes(3, 1000)
		SpreeRules.bank(s, 200, C)
		local _, _, added = SpreeRules.addCrime(s, "spree-2", 1000, 1, 300, C)
		Assert.equal(added, 1000)
		Assert.equal(s.Id, "spree-2")
		Assert.equal(s.Crimes, 1)
	end,
}
