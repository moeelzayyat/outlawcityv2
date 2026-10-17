-- Dispatch and busting rules for NPC police, including the shared combat gate.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Police = ServerScriptService.Server.Police
local PoliceDispatchRules = require(Police.PoliceDispatchRules)
local PoliceConfig = require(Police.PoliceConfig)
local RoadNetwork = require(Police.RoadNetwork)
local CombatRules = require(ReplicatedStorage.Shared.Combat.CombatRules)
local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local Assert = require(script.Parent.Assert)

local POLICE = { Kind = "NpcPolice", WantedStars = 0, InSafeZone = false, SpawnProtectedUntil = 0 }
local function suspect(stars: number)
	return { Kind = "Player", UserId = 1, Status = "Peaceful", WantedStars = stars, InSafeZone = false, SpawnProtectedUntil = 0 }
end

return {
	["units scale 1-2-3 with stars under a server cap of 12 (D-002, D-019)"] = function()
		Assert.equal(table.concat(PoliceConfig.UnitsByStars, ","), "1,2,3")
		Assert.equal(PoliceConfig.ServerUnitCap, 12)
		Assert.equal(PoliceConfig.RoadblockStars, 3)
		Assert.equal(PoliceConfig.RoadblockServerCap, 3)
	end,
	["police cruiser exists and players cannot spawn it"] = function()
		local stats = VehicleConfig.get("Police")
		Assert.truthy(stats, "Police vehicle config")
		Assert.equal(stats.PlayerSpawnable, false)
		Assert.truthy(VehicleConfig.get(VehicleConfig.DefaultVehicleId).PlayerSpawnable ~= false, "Coupe still spawnable")
	end,
	["no dispatch for players who are not wanted"] = function()
		Assert.equal(PoliceDispatchRules.unitsFor(0, PoliceConfig.UnitsByStars), 0)
		Assert.equal(PoliceDispatchRules.unitsFor(-1, PoliceConfig.UnitsByStars), 0)
		Assert.equal(PoliceDispatchRules.unitsFor(nil :: any, PoliceConfig.UnitsByStars), 0)
		Assert.equal(PoliceDispatchRules.unitsFor(0 / 0, PoliceConfig.UnitsByStars), 0)
	end,
	["dispatch activates as soon as a star appears"] = function()
		for stars = 1, 3 do
			Assert.equal(PoliceDispatchRules.unitsFor(stars, PoliceConfig.UnitsByStars), stars)
		end
		Assert.equal(PoliceDispatchRules.unitsFor(5, PoliceConfig.UnitsByStars), 3, "more stars keep the last entry")
	end,
	["spawn node is in the distance band when possible"] = function()
		local network = RoadNetwork.build()
		local target = Vector3.new(0, 0, 0)
		local rng = Random.new(5)
		for _ = 1, 50 do
			local node = assert(PoliceDispatchRules.chooseSpawnNode(network.Nodes, target, PoliceConfig.SpawnMinDistance, PoliceConfig.SpawnMaxDistance, rng))
			local d = RoadNetwork.flatDistance(network.Nodes[node], target)
			Assert.truthy(d >= PoliceConfig.SpawnMinDistance and d <= PoliceConfig.SpawnMaxDistance, `spawn at {d} studs`)
		end
		Assert.equal(PoliceDispatchRules.chooseSpawnNode({}, target, 1, 2, rng), nil)
	end,
	["bust needs range, a stopped target and permission, continuously"] = function()
		local C = PoliceConfig
		local state = PoliceDispatchRules.newBustState()
		local busted = false
		for _ = 1, math.ceil(C.BustSeconds / 0.25) do
			busted = PoliceDispatchRules.updateBust(state, 0.25, C.BustRange - 1, 0, true, C)
		end
		Assert.equal(busted, true)

		local function attempt(distance, speed, allowed)
			local s = PoliceDispatchRules.newBustState()
			local result = false
			for _ = 1, 40 do
				result = result or PoliceDispatchRules.updateBust(s, 0.25, distance, speed, allowed, C)
			end
			return result
		end
		Assert.equal(attempt(C.BustRange + 1, 0, true), false)
		Assert.equal(attempt(5, C.BustMaxTargetSpeed + 1, true), false)
		Assert.equal(attempt(5, 0, false), false)
	end,
	["moving away resets bust progress"] = function()
		local C = PoliceConfig
		local state = PoliceDispatchRules.newBustState()
		PoliceDispatchRules.updateBust(state, C.BustSeconds - 0.1, 5, 0, true, C)
		PoliceDispatchRules.updateBust(state, 0.25, 5, 30, true, C)
		Assert.equal(state.Progress, 0)
	end,
	["combat gate: police may bust wanted players and never unwanted ones"] = function()
		Assert.equal((CombatRules.canHarm(POLICE, suspect(1), { Now = 0, Action = "Bust" })), true)
		local ok, reason = CombatRules.canHarm(POLICE, suspect(0), { Now = 0, Action = "Bust" })
		Assert.equal(ok, false)
		Assert.equal(reason, "NotWanted")
	end,
	["the unit keeps its target while that player is wanted (R1.6)"] = function()
		local c = {
			{ Id = 1, Stars = 1, Held = false, Present = true },
			{ Id = 2, Stars = 3, Held = false, Present = true },
		}
		Assert.equal(PoliceDispatchRules.pickTarget(1, c), 1, "no switch to a higher-star player mid-chase")
	end,
	["a cleared or departed target hands the unit to the most-wanted free player (R1.6)"] = function()
		local c = {
			{ Id = 1, Stars = 0, Held = false, Present = true },
			{ Id = 2, Stars = 2, Held = false, Present = true },
			{ Id = 3, Stars = 3, Held = true, Present = true }, -- robbery holdout: police respond later
			{ Id = 4, Stars = 2, Held = false, Present = true },
		}
		Assert.equal(PoliceDispatchRules.pickTarget(1, c), 2, "highest free stars, ties to the lowest id")
		c[1].Stars, c[1].Present = 3, false
		Assert.equal(PoliceDispatchRules.pickTarget(1, c), 2, "a target who left is dropped")
		Assert.equal(PoliceDispatchRules.pickTarget(nil, { { Id = 9, Stars = 0, Held = false, Present = true } }), nil)
	end,
	["allocation gives units by stars and spreads them under the cap (S2.5)"] = function()
		local U = PoliceConfig.UnitsByStars
		local function c(id: number, stars: number)
			return { Id = id, Stars = stars, Held = false, Present = true }
		end
		local r = PoliceDispatchRules.allocate({ c(1, 3), c(2, 2), c(3, 1), c(4, 0) }, U, 6)
		Assert.equal(r[1], 3)
		Assert.equal(r[2], 2)
		Assert.equal(r[3], 1)
		Assert.equal(r[4], nil, "not wanted")
		-- Seven wanted players, cap 6: one each to the six most wanted, the seventh waits.
		local many = {}
		for id = 1, 7 do
			table.insert(many, c(id, if id <= 2 then 3 else 1))
		end
		r = PoliceDispatchRules.allocate(many, U, 6)
		local total = 0
		for _, n in r do
			total += n
		end
		Assert.equal(total, 6)
		Assert.equal(r[1], 1)
		Assert.equal(r[7], nil, "the least wanted, highest id waits (heat held, R1.6)")
		-- Two 3-star players and one 1-star: 3 + 2 + 1, the extra going to the lower id.
		r = PoliceDispatchRules.allocate({ c(5, 3), c(2, 3), c(9, 1) }, U, 6)
		Assert.equal(r[2], 3)
		Assert.equal(r[5], 2)
		Assert.equal(r[9], 1)
	end,
	["a held player keeps the units on them but gets no new ones (S2.5)"] = function()
		local U = PoliceConfig.UnitsByStars
		local r = PoliceDispatchRules.allocate({ { Id = 1, Stars = 3, Held = true, Present = true, Assigned = 0 } }, U, 6)
		Assert.equal(r[1], nil)
		r = PoliceDispatchRules.allocate({ { Id = 1, Stars = 3, Held = true, Present = true, Assigned = 1 } }, U, 6)
		Assert.equal(r[1], 1)
		r = PoliceDispatchRules.allocate({ { Id = 1, Stars = 2, Held = false, Present = false } }, U, 6)
		Assert.equal(r[1], nil, "departed")
		Assert.equal(next(PoliceDispatchRules.allocate({ { Id = 1, Stars = 2, Held = false, Present = true } }, U, 0 / 0)), nil, "bad cap")
	end,
	["roadblock goes 250 studs ahead on the player's grid road, never in an intersection (S2.5)"] = function()
		local lines, width = { -300, -100, 100, 300 }, 36
		local spot, axis = PoliceDispatchRules.roadblockSpot(Vector3.new(300, 3, 200), Vector3.new(0, 0, -1), 250, lines, width)
		Assert.equal(axis, "Z")
		Assert.equal((spot :: Vector3).X, 300)
		Assert.equal((spot :: Vector3).Z, -50)
		spot, axis = PoliceDispatchRules.roadblockSpot(Vector3.new(-250, 3, 100), Vector3.new(40, 0, 3), 250, lines, width)
		Assert.equal(axis, "X")
		Assert.equal((spot :: Vector3).X, 0)
		Assert.equal((spot :: Vector3).Z, 100)
		spot = PoliceDispatchRules.roadblockSpot(Vector3.new(300, 3, 150), Vector3.new(0, 0, -1), 250, lines, width)
		Assert.equal((spot :: Vector3).Z, -100 + width / 2 + 6, "moved back out of the intersection")
		Assert.equal(PoliceDispatchRules.roadblockSpot(Vector3.new(300, 3, -200), Vector3.new(0, 0, -1), 250, lines, width), nil, "would leave the grid")
		Assert.equal(PoliceDispatchRules.roadblockSpot(Vector3.new(0, 3, 0), Vector3.new(0, 0, -1), 250, lines, width), nil, "not on a grid road")
		Assert.equal(PoliceDispatchRules.roadblockSpot(Vector3.new(300, 3, 200), Vector3.zero, 250, lines, width), nil, "no direction")
	end,
	["heat holds while seen or while wanted with no unit assigned (R1.6)"] = function()
		Assert.equal(PoliceDispatchRules.heatHeld(2, false, false), true, "unassigned wanted player")
		Assert.equal(PoliceDispatchRules.heatHeld(2, true, false), false, "assigned, unseen: decays")
		Assert.equal(PoliceDispatchRules.heatHeld(2, true, true), true, "seen")
		Assert.equal(PoliceDispatchRules.heatHeld(0, false, false), false, "not wanted")
	end,
}
