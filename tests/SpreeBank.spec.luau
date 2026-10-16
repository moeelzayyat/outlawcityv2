-- EconomyRules.bankSpree / noteBust (S2.2): a spree is paid once per spree id together with its
-- profile stats; busts are counted once per transaction id.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Assert = require(script.Parent.Assert)

local C = EconomyConfig

return {
	["banking pays the spree and records its stats in the same step"] = function()
		local p = EconomyRules.newProfile(C)
		local ok, err = EconomyRules.bankSpree(p, 4500, 6, "spree:abc", C)
		Assert.equal(ok, true, tostring(err))
		Assert.equal(p.Cash, C.StartingCash + 4500)
		Assert.equal(p.Reputation, 6)
		Assert.equal(p.BestSpree, 4500)
		Assert.equal(p.Stats.Sprees, 1)
		Assert.equal(p.Stats.Banked, 4500)
		Assert.equal(p.PaidRewards[1], "spree:abc")
	end,
	["the same spree id never pays twice"] = function()
		local p = EconomyRules.newProfile(C)
		EconomyRules.bankSpree(p, 4500, 6, "spree:abc", C)
		local ok, err = EconomyRules.bankSpree(p, 4500, 6, "spree:abc", C)
		Assert.equal(ok, false)
		Assert.equal(err, "DuplicateTransaction")
		Assert.equal(p.Cash, C.StartingCash + 4500)
		Assert.equal(p.Stats.Sprees, 1, "stats untouched by the refused repeat")
	end,
	["best spree keeps the largest; a refused amount changes nothing"] = function()
		local p = EconomyRules.newProfile(C)
		EconomyRules.bankSpree(p, 9000, 10, "spree:1", C)
		EconomyRules.bankSpree(p, 2000, 2, "spree:2", C)
		Assert.equal(p.BestSpree, 9000)
		Assert.equal(p.Reputation, 12)
		local ok, err = EconomyRules.bankSpree(p, 0 / 0, 2, "spree:3", C)
		Assert.equal(ok, false)
		Assert.equal(err, "InvalidAmount")
		Assert.equal(p.Stats.Sprees, 2)
	end,
	["a bad reputation value adds none but the cash is still paid"] = function()
		local p = EconomyRules.newProfile(C)
		Assert.equal((EconomyRules.bankSpree(p, 1000, 0 / 0, "spree:x", C)), true)
		Assert.equal(p.Reputation, 0)
		Assert.equal(p.Cash, C.StartingCash + 1000)
	end,
	["a bust is counted once per transaction id"] = function()
		local p = EconomyRules.newProfile(C)
		Assert.equal((EconomyRules.noteBust(p, "bust:1", C)), true)
		local ok, err = EconomyRules.noteBust(p, "bust:1", C)
		Assert.equal(ok, false)
		Assert.equal(err, "DuplicateTransaction")
		Assert.equal((EconomyRules.noteBust(p, "bust:2", C)), true)
		Assert.equal(p.Stats.Busts, 2)
		Assert.equal(p.Cash, C.StartingCash, "a bust never touches banked cash")
	end,
}
