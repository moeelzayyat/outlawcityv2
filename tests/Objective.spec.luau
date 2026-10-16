-- Daily objective (S2.9): one objective per UTC day, events advance it up to the target, it pays
-- once per day (tx id) and old days are pruned from the profile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ObjectiveRules = require(ReplicatedStorage.Shared.Rules.ObjectiveRules)
local ObjectiveConfig = require(ReplicatedStorage.Shared.Config.ObjectiveConfig)
local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Assert = require(script.Parent.Assert)

local LIST = ObjectiveConfig.Daily :: any

return {
	["one objective per day, rotating; config is sane"] = function()
		Assert.truthy(#LIST >= 1)
		local seen = {}
		for _, o in LIST do
			Assert.truthy(not seen[o.Id], `duplicate {o.Id}`)
			seen[o.Id] = true
			Assert.truthy(o.Target >= 1 and o.Target % 1 == 0, `{o.Id} target`)
			Assert.truthy(o.Reward > 0 and o.Reward <= EconomyConfig.MaxTransaction, `{o.Id} reward`)
			Assert.truthy(#ObjectiveRules.key(99999, o.Id) + #":paid" <= EconomyConfig.SettingKeyMaxLength, `{o.Id} key fits the profile`)
		end
		Assert.equal(ObjectiveRules.forDay(LIST, 20742), ObjectiveRules.forDay(LIST, 20742))
		Assert.truthy(ObjectiveRules.forDay(LIST, 20742) ~= ObjectiveRules.forDay(LIST, 20743), "the next day brings the next objective")
		Assert.equal(ObjectiveRules.forDay({}, 1), nil)
	end,
	["events advance only their own kind, capped at the target"] = function()
		local banks = { Id = "B", Text = "", Kind = "Banks", Target = 3, Reward = 1 }
		local crimes = { Id = "C", Text = "", Kind = "Crimes", Target = 2, Reward = 1 }
		local big = { Id = "A", Text = "", Kind = "BankAmount", Target = 5000, Reward = 1 }
		Assert.equal(ObjectiveRules.advance(banks, 0, { Kind = "Banked", Amount = 10 }), 1)
		Assert.equal(ObjectiveRules.advance(banks, 1, { Kind = "Crime" }), 1, "crimes don't count for banks")
		Assert.equal(ObjectiveRules.advance(crimes, 1, { Kind = "Crime" }), 2)
		Assert.equal(ObjectiveRules.advance(crimes, 2, { Kind = "Crime" }), 2, "capped")
		Assert.equal(ObjectiveRules.advance(big, 0, { Kind = "Banked", Amount = 4050 }), 4050)
		Assert.equal(ObjectiveRules.advance(big, 4050, { Kind = "Banked", Amount = 800 }), 4050, "best bank counts")
		Assert.equal(ObjectiveRules.advance(big, 4050, { Kind = "Banked", Amount = 9000 }), 5000)
		Assert.equal(ObjectiveRules.advance(big, 0, { Kind = "Banked", Amount = 0 / 0 }), 0)
		Assert.equal(ObjectiveRules.complete(big, 5000), true)
		Assert.equal(ObjectiveRules.complete(crimes, 1), false)
	end,
	["the reward pays once per day: the same tx is refused"] = function()
		local o = LIST[1]
		local profile = EconomyRules.newProfile(EconomyConfig)
		local tx = ObjectiveRules.txId(20742, o.Id)
		Assert.equal((EconomyRules.payReward(profile, o.Reward, tx, EconomyConfig)), true)
		local ok, err = EconomyRules.payReward(profile, o.Reward, tx, EconomyConfig)
		Assert.equal(ok, false)
		Assert.equal(err, "DuplicateTransaction")
		Assert.equal(profile.Cash, EconomyConfig.StartingCash + o.Reward)
		Assert.truthy(ObjectiveRules.txId(20743, o.Id) ~= tx, "a new day is a new payment")
	end,
	["old days are pruned and the saved map is validated"] = function()
		local saved = { ["20741:Bank3"] = 2, ["20742:Crimes8"] = 5, ["20742:Crimes8:paid"] = 1 }
		local kept = ObjectiveRules.prune(saved, 20742)
		Assert.equal(kept["20741:Bank3"], nil)
		Assert.equal(kept["20742:Crimes8"], 5)
		Assert.equal(kept["20742:Crimes8:paid"], 1)
		local profile = EconomyRules.newProfile(EconomyConfig)
		Assert.equal((EconomyRules.setObjectives(profile, kept, EconomyConfig)), true)
		Assert.equal(profile.Objectives["20742:Crimes8"], 5)
		Assert.equal((EconomyRules.setObjectives(profile, { ["x"] = -1 }, EconomyConfig)), false, "negative progress refused")
		Assert.equal((EconomyRules.setObjectives(profile, { [string.rep("k", 40)] = 1 }, EconomyConfig)), false, "long key refused")
		Assert.equal(profile.Objectives["20742:Crimes8"], 5, "a refused map changes nothing")
	end,
}
