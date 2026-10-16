-- CharacterValidationRules (R1.3): normal on-foot play is never observed; hops, sustained
-- overspeed and non-finite samples are; grace covers authorized moves; the payout window.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.Rules.CharacterValidationRules)
local Config = require(ReplicatedStorage.Shared.Config.CharacterValidationConfig)
local Assert = require(script.Parent.Assert)

local function sample(t: number, pos: Vector3, vel: Vector3?): Rules.Sample
	return { Time = t, Position = pos, Velocity = vel or Vector3.zero }
end

-- Settled state at t=10 standing at `pos` (past the spawn grace).
local function settled(pos: Vector3): Rules.State
	local state = Rules.new(0, Config.SpawnGraceSeconds)
	Rules.observe(state, sample(10, pos), Config)
	return state
end

return {
	["3 minutes of generated normal play produce no observations"] = function()
		local rng = Random.new(42)
		local state = Rules.new(0, Config.SpawnGraceSeconds)
		local t, pos = 0, Vector3.new(0, 5, 0)
		local heading = 0
		local count = 0
		while t < 180 do
			local dt = rng:NextNumber(0.15, 0.35) -- server sample jitter
			if rng:NextNumber() < 0.1 then
				heading = rng:NextNumber(0, math.pi * 2)
			end
			local speed = if rng:NextNumber() < 0.2 then 0 else rng:NextNumber(10, 16) -- idle, walk, run
			local vel = Vector3.new(math.cos(heading), 0, math.sin(heading)) * speed
			local vertical = if rng:NextNumber() < 0.05 then -rng:NextNumber(0, 60) else rng:NextNumber(-2, 2) -- jumps, falls off roofs
			t += dt
			pos += vel * dt + Vector3.new(0, vertical, 0)
			count += #Rules.observe(state, sample(t, pos, vel + Vector3.new(0, vertical / dt, 0)), Config)
		end
		Assert.equal(count, 0)
	end,
	["a 100-stud hop is observed as a teleport"] = function()
		local state = settled(Vector3.zero)
		local observations = Rules.observe(state, sample(10.2, Vector3.new(100, 0, 0)), Config)
		Assert.equal(#observations, 1)
		Assert.equal(observations[1].Kind, "Teleport")
	end,
	["non-finite samples are observed and keep the last good baseline"] = function()
		local state = settled(Vector3.zero)
		for _, bad in { sample(10.2, Vector3.new(0 / 0, 0, 0)), sample(10.2, Vector3.zero, Vector3.new(math.huge, 0, 0)), sample(0 / 0, Vector3.zero) } do
			local observations = Rules.observe(state, bad, Config)
			Assert.equal(#observations, 1)
			Assert.equal(observations[1].Kind, "InvalidState")
		end
		Assert.equal((state.Last :: Rules.Sample).Time, 10, "baseline kept")
	end,
	["sustained overspeed is observed; a short burst is not"] = function()
		local state = settled(Vector3.zero)
		local t, x, kinds = 10, 0, {}
		for _ = 1, 3 do -- 0.6 s at 30 studs/s, then normal
			t += 0.2
			x += 6
			for _, o in Rules.observe(state, sample(t, Vector3.new(x, 0, 0), Vector3.new(30, 0, 0)), Config) do
				table.insert(kinds, o.Kind)
			end
		end
		t += 0.2
		Rules.observe(state, sample(t, Vector3.new(x, 0, 0)), Config)
		Assert.equal(#kinds, 0, "burst")
		for _ = 1, 6 do -- 1.2 s at 30 studs/s
			t += 0.2
			x += 6
			for _, o in Rules.observe(state, sample(t, Vector3.new(x, 0, 0), Vector3.new(30, 0, 0)), Config) do
				table.insert(kinds, o.Kind)
			end
		end
		Assert.equal(#kinds, 1)
		Assert.equal(kinds[1], "SustainedOverspeed")
	end,
	["grace covers spawn and authorized moves, then judging resumes"] = function()
		local state = Rules.new(0, Config.SpawnGraceSeconds)
		Assert.equal(#Rules.observe(state, sample(0.2, Vector3.zero), Config), 0)
		Assert.equal(#Rules.observe(state, sample(0.4, Vector3.new(500, 0, 0)), Config), 0, "spawn grace")
		Rules.observe(state, sample(10, Vector3.new(500, 0, 0)), Config)
		Rules.grant(state, 10, Config.MoveGraceSeconds) -- jail cell / seat
		Assert.equal(#Rules.observe(state, sample(10.2, Vector3.new(-300, 0, 0)), Config), 0, "move grace")
		Assert.equal(#Rules.observe(state, sample(12.4, Vector3.new(-300, 0, 2)), Config), 0, "fresh baseline")
		Assert.equal(#Rules.observe(state, sample(12.6, Vector3.new(-200, 0, 2)), Config), 1, "judged again")
	end,
	["a long vertical fall is not observed"] = function()
		local state = settled(Vector3.new(0, 300, 0))
		Assert.equal(#Rules.observe(state, sample(10.2, Vector3.new(1, 50, 0), Vector3.new(0, -250, 0)), Config), 0)
	end,
	["the payout window"] = function()
		Assert.equal(Rules.isObserved(nil, 100, Config.ObservationWindow), false)
		Assert.equal(Rules.isObserved(95, 100, Config.ObservationWindow), true)
		Assert.equal(Rules.isObserved(100 - Config.ObservationWindow, 100, Config.ObservationWindow), false)
		Assert.equal(Rules.isObserved(0 / 0, 100, Config.ObservationWindow), false)
		Assert.equal(Rules.isObserved("95", 100, Config.ObservationWindow), false)
	end,
}
