--!strict
-- Pure dispatch and busting rules for NPC police. Unit-tested in PoliceDispatch.spec.
local PoliceDispatchRules = {}

-- How many units a target with `stars` should have (0 when not wanted): UnitsByStars, with the
-- last entry for anything above (D-002, S2.5).
function PoliceDispatchRules.unitsFor(stars: number, unitsByStars: { number }): number
	if type(stars) ~= "number" or stars ~= stars or stars < 1 or #unitsByStars == 0 then
		return 0
	end
	return math.max(0, unitsByStars[math.min(math.floor(stars), #unitsByStars)])
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

export type Candidate = { Id: number, Stars: number, Held: boolean, Present: boolean, Assigned: number? }

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

-- Units per wanted player this tick (S2.5, D-002): each wants unitsFor(stars); a held player
-- (robbery holdout) keeps the units already on them but gets no new ones. Under the cap every
-- wanted player gets one unit before anyone gets a second, highest stars first (ties: lowest
-- Id). Returns {[Id]: units} for the players who get at least one.
function PoliceDispatchRules.allocate(candidates: { Candidate }, unitsByStars: { number }, cap: number): { [number]: number }
	local wanted: { { Id: number, Stars: number, Want: number } } = {}
	for _, c in candidates do
		if c.Present then
			local want = PoliceDispatchRules.unitsFor(c.Stars, unitsByStars)
			if c.Held then
				want = math.min(want, c.Assigned or 0)
			end
			if want > 0 then
				table.insert(wanted, { Id = c.Id, Stars = c.Stars, Want = want })
			end
		end
	end
	table.sort(wanted, function(a, b)
		return if a.Stars ~= b.Stars then a.Stars > b.Stars else a.Id < b.Id
	end)
	local result: { [number]: number } = {}
	local left = if type(cap) == "number" and cap == cap then math.max(0, math.floor(cap)) else 0
	for _, w in wanted do
		if left <= 0 then
			break
		end
		result[w.Id] = 1
		left -= 1
	end
	for _, w in wanted do
		local has = result[w.Id]
		if left <= 0 or not has then
			break
		end
		local extra = math.min(w.Want - has, left)
		result[w.Id] = has + extra
		left -= extra
	end
	return result
end

-- Where a roadblock goes (S2.5): on the grid road the player is travelling, `ahead` studs along
-- it in their direction; a spot inside an intersection moves back to just before it. Returns
-- (centre, roadAxis): "X" when the road runs along X (the barrier spans Z), else "Z". nil when
-- the player isn't on a grid road running their way or the spot would leave the grid.
function PoliceDispatchRules.roadblockSpot(position: Vector3, direction: Vector3, ahead: number, lines: { number }, roadWidth: number): (Vector3?, string?)
	local flatDir = Vector3.new(direction.X, 0, direction.Z)
	if flatDir.Magnitude < 1e-3 or #lines == 0 then
		return nil, nil
	end
	local alongX = math.abs(flatDir.X) >= math.abs(flatDir.Z)
	local across = if alongX then position.Z else position.X
	local along = if alongX then position.X else position.Z
	local sign = math.sign(if alongX then flatDir.X else flatDir.Z)
	local road: number? = nil
	for _, line in lines do
		if math.abs(across - line) <= roadWidth / 2 then
			road = line
		end
	end
	if not road then
		return nil, nil
	end
	local spot = along + sign * ahead
	for _, line in lines do
		if math.abs(spot - line) < roadWidth / 2 + 2 then
			spot = line - sign * (roadWidth / 2 + 6)
		end
	end
	if spot < lines[1] or spot > lines[#lines] then
		return nil, nil
	end
	if alongX then
		return Vector3.new(spot, 0, road), "X"
	end
	return Vector3.new(road, 0, spot), "Z"
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
