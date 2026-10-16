--!strict
-- Pure vehicle-spawn rules (R1.5, audit F3/F14): whether a player may spawn a car now, and
-- where. A car appears on the nearest free pad within MaxDistance of the player, else on the
-- nearest clear spot beside them within MaxDistance; never on a far pad (spawning used to move
-- the driver up to 700 studs, which broke police line of sight). Positions are plain Vector3s.
-- Unit-tested in ServerStorage.Tests.VehicleSpawn.spec.
local VehicleSpawnRules = {}

export type Facts = { WantedLevel: number, InCrime: boolean, Unbanked: number }
export type Spot = { Position: Vector3, Free: boolean }
export type Choice = { Kind: string, Index: number } -- Kind: "Pad" | "Nearby"

-- Refused while wanted, during a crime, or holding unbanked spree cash (D-004). NaN counts as
-- "not zero", so a broken value refuses rather than allows.
function VehicleSpawnRules.canSpawn(facts: Facts): (boolean, string?)
	if not (facts.WantedLevel <= 0) then
		return false, "Wanted"
	end
	if facts.InCrime then
		return false, "InCrime"
	end
	if not (facts.Unbanked <= 0) then
		return false, "Unbanked"
	end
	return true, nil
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function nearestFree(from: Vector3, spots: { Spot }, maxDistance: number): number?
	local best: number? = nil
	local bestDistance = math.huge
	for index, spot in spots do
		local distance = flatDistance(from, spot.Position)
		if spot.Free and distance <= maxDistance and distance < bestDistance then
			best, bestDistance = index, distance
		end
	end
	return best
end

-- Picks where the car goes: a free pad in range first, then a free nearby spot; nil if none.
function VehicleSpawnRules.choose(from: Vector3, pads: { Spot }, nearby: { Spot }, maxDistance: number): Choice?
	local pad = nearestFree(from, pads, maxDistance)
	if pad then
		return { Kind = "Pad", Index = pad }
	end
	local spot = nearestFree(from, nearby, maxDistance)
	if spot then
		return { Kind = "Nearby", Index = spot }
	end
	return nil
end

return VehicleSpawnRules
