-- FunnelRules (R1.7): first-time milestones once per session, onboarding steps in order,
-- repeatable custom events.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FunnelRules = require(ReplicatedStorage.Shared.Rules.FunnelRules)
local Assert = require(script.Parent.Assert)

return {
	["onboarding steps are numbered in funnel order"] = function()
		Assert.equal(FunnelRules.Steps.Joined, 1)
		Assert.equal(FunnelRules.Steps.FirstCar, 2)
		Assert.equal(FunnelRules.Steps.FirstCrime, 3)
		Assert.equal(FunnelRules.Steps.FirstBank, 4)
	end,
	["a first-time milestone logs once"] = function()
		local state = FunnelRules.new()
		local first, step = FunnelRules.mark(state, "FirstCar")
		Assert.equal(first, true)
		Assert.equal(step, 2)
		Assert.equal((FunnelRules.mark(state, "FirstCar")), false)
		Assert.equal((FunnelRules.mark(state, "FirstBust")), true)
		Assert.equal((FunnelRules.mark(state, "FirstBust")), false)
	end,
	["repeatable events always log and are not funnel steps"] = function()
		local state = FunnelRules.new()
		for _ = 1, 3 do
			local log, step = FunnelRules.mark(state, "Left")
			Assert.equal(log, true)
			Assert.equal(step, nil)
		end
	end,
}
