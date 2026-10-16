--!strict
-- Pure dispatch and busting rules for NPC police. Unit-tested in PoliceDispatch.spec.
local PoliceDispatchRules = {}

-- How many units a target with `stars` should have (0 when not wanted).
function PoliceDispatchRules.unitsFor(stars: number, maxUnits: number): number
	if type(stars) ~= "number" or stars <= 0 then
		return 0
	end
	return math.max(0, maxUnits)
end

-- Picks a spawn node index: random among nodes within [min, max] of the target; otherwise the
-- node just beyond max; otherwise the farthest node. Returns nil only for an empty list.
function PoliceDispatchRules.chooseSpawnNode(
	nodes: { Vector3 },
	target: Vector3,
	minDistance: number,
	maxDistance: number,
	rng: Random
): number?
	if #nodes == 0 then
		return nil
	end
	local band, beyond, farthest = {}, nil :: number?, 1
	local beyondDistance, farthestDistance = math.huge, -1
	for i, node in nodes do
		local d = Vector3.new(node.X - target.X, 0, node.Z - target.Z).Magnitude
		if d >= minDistance and d <= maxDistance then
			table.insert(band, i)
		elseif d > maxDistance and d < beyondDistance then
			beyond, beyondDistance = i, d
		end
		if d > farthestDistance then
			farthest, farthestDistance = i, d
		end
	end
	if #band > 0 then
		return band[rng:NextInteger(1, #band)]
	end
	return beyond or farthest
end

export type Candidate = { Id: number, Stars: number, Held: boolean, Present: boolean }

-- Who the unit chases this tick (R1.6, audit F2): its current target while still present and
-- wanted; otherwise the highest-stars wanted candidate that isn't held (ties: lowest Id).
function PoliceDispatchRules.pickTarget(currentId: number?, candidates: { Candidate }): number?
	if currentId then
		for _, c in candidates do
			if c.Id == currentId and c.Present and c.Stars > 0 then
				return currentId
			end
		end
	end
	local best: Candidate? = nil
	for _, c in candidates do
		if c.Present and not c.Held and c.Stars > 0 then
			if best == nil or c.Stars > best.Stars or (c.Stars == best.Stars and c.Id < best.Id) then
				best = c
			end
		end
	end
	return if best then best.Id else nil
end

-- Wanted heat holds (counts as seen) while a unit sees the player, or while they are wanted
-- with no unit assigned: nobody escapes just because the only unit is busy elsewhere (F2).
function PoliceDispatchRules.heatHeld(stars: number, assigned: boolean, seen: boolean): boolean
	return seen or (stars > 0 and not assigned)
end

export type BustState = { Progress: number }

function PoliceDispatchRules.newBustState(): BustState
	return { Progress = 0 }
end

-- Busting needs the combat rules' permission (`allowed`, i.e. the target is wanted), the unit
-- within range, and the target nearly stopped, continuously for BustSeconds.
function PoliceDispatchRules.updateBust(
	state: BustState,
	dt: number,
	distance: number,
	targetSpeed: number,
	allowed: boolean,
	config: { BustRange: number, BustSeconds: number, BustMaxTargetSpeed: number }
): boolean
	if allowed and distance <= config.BustRange and targetSpeed <= config.BustMaxTargetSpeed then
		state.Progress += dt
	else
		state.Progress = 0
	end
	return state.Progress >= config.BustSeconds
end

return PoliceDispatchRules
