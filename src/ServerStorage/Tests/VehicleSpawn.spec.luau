-- VehicleSpawnRules (R1.5): no car while wanted, in a crime or holding unbanked cash; the car
-- appears within 30 studs, on a free pad first, never on a far pad.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.Rules.VehicleSpawnRules)
local GameplayConfig = require(ReplicatedStorage.Shared.Config.GameplayConfig)
local Assert = require(script.Parent.Assert)

local MAX = GameplayConfig.VehicleSpawnMaxDistance
local OK = { WantedLevel = 0, InCrime = false, Unbanked = 0 }

local function facts(overrides: { [string]: any }): Rules.Facts
	local f = table.clone(OK) :: any
	for k, v in overrides do
		f[k] = v
	end
	return f
end

local function spot(x: number, z: number, free: boolean?): Rules.Spot
	return { Position = Vector3.new(x, 0, z), Free = free ~= false }
end

return {
	["the spawn distance is 30 studs"] = function()
		Assert.equal(MAX, 30)
	end,
	["a clean player may spawn; wanted, in a crime or unbanked may not"] = function()
		Assert.equal((Rules.canSpawn(OK)), true)
		for _, case in {
			{ { WantedLevel = 2 }, "Wanted" },
			{ { WantedLevel = 0 / 0 }, "Wanted" },
			{ { InCrime = true }, "InCrime" },
			{ { Unbanked = 800 }, "Unbanked" },
			{ { Unbanked = 0 / 0 }, "Unbanked" },
		} do
			local ok, err = Rules.canSpawn(facts(case[1]))
			Assert.equal(ok, false)
			Assert.equal(err, case[2])
		end
	end,
	["the nearest free pad in range wins; an occupied pad passes to the next"] = function()
		local pads = { spot(10, 0), spot(20, 0) }
		local choice = Rules.choose(Vector3.zero, pads, {}, MAX) :: Rules.Choice
		Assert.equal(choice.Kind, "Pad")
		Assert.equal(choice.Index, 1)
		pads[1].Free = false -- a player is standing on it
		choice = Rules.choose(Vector3.zero, pads, {}, MAX) :: Rules.Choice
		Assert.equal(choice.Index, 2)
	end,
	["far pads are never used; a clear spot beside the player is"] = function()
		local pads = { spot(500, 0), spot(-700, 0) }
		local nearby = { spot(12, 0, false), spot(-12, 0), spot(0, 22) }
		local choice = Rules.choose(Vector3.zero, pads, nearby, MAX) :: Rules.Choice
		Assert.equal(choice.Kind, "Nearby")
		Assert.equal(choice.Index, 2)
	end,
	["no free spot in range means no spawn"] = function()
		Assert.equal(Rules.choose(Vector3.zero, { spot(40, 0) }, { spot(12, 0, false), spot(31, 0) }, MAX), nil)
	end,
	["height is ignored when measuring range"] = function()
		local choice = Rules.choose(Vector3.new(0, 80, 0), { spot(25, 0) }, {}, MAX) :: Rules.Choice
		Assert.equal(choice.Kind, "Pad")
	end,
}
