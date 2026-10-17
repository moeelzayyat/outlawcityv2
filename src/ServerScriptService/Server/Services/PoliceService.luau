--!strict
-- NPC police orchestration. A pool of server-simulated police cars (S2.5, D-002): each wanted
-- player gets units by stars (PoliceConfig.UnitsByStars), never more than ServerUnitCap on the
-- server; units plan road routes to their player, report sightings, bust stationary wanted
-- players through CombatService, and are re-assigned or recalled when their player is busted,
-- banks, escapes or leaves. At RoadblockStars a roadblock goes up ahead of the player.
-- Path planning (PolicePathPlanner/RoadNetwork), movement (PoliceDriver) and dispatch rules
-- (PoliceDispatchRules) are separate modules; this service only wires them together.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local VehicleConfig = require(Shared.Config.VehicleConfig)
local Server = script.Parent.Parent
local Police = Server.Police
local PoliceConfig = require(Police.PoliceConfig)
local RoadNetwork = require(Police.RoadNetwork)
local PolicePathPlanner = require(Police.PolicePathPlanner)
local PoliceDispatchRules = require(Police.PoliceDispatchRules)
local PoliceDriver = require(Police.PoliceDriver)
local PoliceCollisionDetector = require(Server.Crime.PoliceCollisionDetector)
local VehicleFactory = require(Server.Vehicle.VehicleFactory)
local CityLayout = require(Server.World.CityLayout)
local WantedService = require(script.Parent.WantedService)
local CombatService = require(script.Parent.CombatService)
local JailService = require(script.Parent.JailService)
local LoopGuard = require(Server.Util.LoopGuard)
local SpreeConfig = require(Shared.Config.SpreeConfig)
local EconomyService = require(script.Parent.EconomyService)
local EventBus = require(ReplicatedStorage.Shared.Util.EventBus)

local PoliceService = {}

local POLICE_VEHICLE_ID = "Police"
local TICK = 0.25

type Unit = {
	Id: number,
	Model: Model,
	Driver: PoliceDriver.PoliceDriver,
	Target: Player,
	Ending: boolean,
	EndToken: number, -- bumped when a re-target cancels a pending despawn
	SeesTarget: boolean,
	Bust: PoliceDispatchRules.BustState,
	NextReplan: number,
	FarSince: number?,
	RamConnection: RBXScriptConnection,
	Stats: {
		Frames: number,
		StepSeconds: number,
		MaxStepMs: number,
		Respawns: number,
	},
}

type Roadblock = { Model: Model, Target: Player, EndsAt: number }

local network = RoadNetwork.build()
local npcFolder: Folder
local units: { Unit } = {}
local nextUnitId = 0
local rng = Random.new()
local lastLog = 0

-- Players the police must not be dispatched to yet (a robbery still in its holdout). Units
-- already chasing the player keep chasing.
local dispatchHolds: { [Player]: boolean } = {}
local roadblocks: { [Player]: Roadblock } = {}
local roadblockReadyAt: { [Player]: number } = {}
local publishedUnits: { [Player]: number } = {}
local wantedSince: { [Player]: number } = {} -- when the current wanted episode began (S2.8)

-- Budget (S2.5): police raycasts per physics frame and the step time of all units together.
local budget = { Frames = 0, StepSeconds = 0, MaxFrameMs = 0, MaxRaysPerFrame = 0, TickRays = 0, MaxUnits = 0 }

-- Event log kept for Studio tests and diagnostics (most recent 60 entries).
local eventLog: { string } = {}
local function logEvent(text: string)
	local line = string.format("%.1f %s", Workspace:GetServerTimeNow() % 1000, text)
	table.insert(eventLog, line)
	if #eventLog > 60 then
		table.remove(eventLog, 1)
	end
	npcFolder:SetAttribute("EventLog", table.concat(eventLog, "\n"))
	print(`[Police] {text}`)
end

local function ignoreList(): { Instance }
	local list: { Instance } = { npcFolder }
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if vehicles then
		table.insert(list, vehicles)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function targetRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function hasLineOfSight(from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList()
	budget.TickRays += 1
	return Workspace:Raycast(from, to - from, params) == nil
end

local function placeOnNode(current: Unit, nodeIndex: number, lookAt: Vector3)
	local stats = VehicleConfig.get(POLICE_VEHICLE_ID)
	assert(stats, "Police vehicle config missing")
	current.Driver:reposition(network.Nodes[nodeIndex], lookAt, VehicleFactory.getRideHeight(stats))
end

local function buildPoliceCar(): Model
	local stats = VehicleConfig.get(POLICE_VEHICLE_ID)
	assert(stats, "Police vehicle config missing")
	local model = VehicleFactory.build(POLICE_VEHICLE_ID, stats)
	model.Name = "PoliceUnit"
	model:SetAttribute("Npc", true)
	-- NPC cars are not drivable by players.
	local seat = model:FindFirstChild("DriverSeat")
	if seat and seat:IsA("Seat") then
		seat.Disabled = true
		local prompt = seat:FindFirstChild("DrivePrompt")
		if prompt then
			prompt:Destroy()
		end
	end
	-- Light bar so the unit reads as police at a glance.
	local chassis = model.PrimaryPart :: BasePart
	for side, color in { [-1] = Color3.fromRGB(255, 40, 40), [1] = Color3.fromRGB(40, 90, 255) } do
		local light = Instance.new("Part")
		light.Name = "LightBar"
		light.Size = Vector3.new(1.6, 0.35, 0.8)
		light.Material = Enum.Material.Neon
		light.Color = color
		light.Massless = true
		light.CanCollide = false
		light.CanQuery = false
		light.CanTouch = false
		light.CFrame = chassis.CFrame * CFrame.new(side * 1.0, stats.ChassisSize.Y / 2 + 2.15, 1.0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chassis
		weld.Part1 = light
		weld.Parent = light
		light.Parent = model
	end
	return model
end

local function despawn(current: Unit, reason: string)
	local index = table.find(units, current)
	if not index then
		return
	end
	table.remove(units, index)
	current.RamConnection:Disconnect()
	current.Driver:destroy()
	local s = current.Stats
	logEvent(string.format(
		"unit %d despawn (%s): frames=%d avgStep=%.3fms maxStep=%.3fms softRecoveries=%d hardRecoveries=%d respawns=%d",
		current.Id,
		reason,
		s.Frames,
		if s.Frames > 0 then s.StepSeconds / s.Frames * 1000 else 0,
		s.MaxStepMs,
		current.Driver.softRecoveries,
		current.Driver.hardRecoveries,
		s.Respawns
	))
	current.Model:Destroy()
end

local function spawnFor(target: Player): Unit?
	local root = targetRoot(target)
	if not root then
		return nil
	end
	local nodeIndex = PoliceDispatchRules.chooseSpawnNode(network.Nodes, root.Position, PoliceConfig.SpawnMinDistance, PoliceConfig.SpawnMaxDistance, rng)
	if not nodeIndex then
		return nil
	end
	local stats = VehicleConfig.get(POLICE_VEHICLE_ID)
	assert(stats, "Police vehicle config missing")
	local model = buildPoliceCar()
	local spawnPosition = network.Nodes[nodeIndex]
	local height = VehicleFactory.getRideHeight(stats) + 0.5
	model:PivotTo(CFrame.lookAt(
		spawnPosition + Vector3.new(0, height, 0),
		Vector3.new(root.Position.X, spawnPosition.Y + height, root.Position.Z)
	))
	model.Parent = npcFolder
	local chassis = model.PrimaryPart :: BasePart
	chassis:SetNetworkOwner(nil)
	local driver = PoliceDriver.new(model, stats, ignoreList())
	if not driver then
		model:Destroy()
		return nil
	end
	nextUnitId += 1
	local current: Unit = {
		Id = nextUnitId,
		Model = model,
		Driver = driver,
		Target = target,
		Ending = false,
		EndToken = 0,
		SeesTarget = false,
		Bust = PoliceDispatchRules.newBustState(),
		NextReplan = 0,
		FarSince = nil,
		RamConnection = PoliceCollisionDetector.attach(chassis, function(event)
			logEvent(string.format("crime detected: %s rammed police at %.0f studs/s", event.Player.Name, event.Speed))
		end),
		Stats = { Frames = 0, StepSeconds = 0, MaxStepMs = 0, Respawns = 0 },
	}
	table.insert(units, current)
	model:SetAttribute("UnitId", current.Id)
	logEvent(string.format("unit %d dispatched to %s from node %s (%.0f studs away)", current.Id, target.Name, network.Names[nodeIndex], (spawnPosition - root.Position).Magnitude))
	return current
end

local function endPursuit(current: Unit, reason: string)
	if current.Ending then
		return
	end
	current.Ending = true
	current.SeesTarget = false
	local token = current.EndToken
	current.Driver:setRoute({}, false)
	logEvent(`unit {current.Id} pursuit ended: {reason}`)
	task.delay(PoliceConfig.DespawnDelay, function()
		if current.Ending and current.EndToken == token then
			despawn(current, reason)
		end
	end)
end

-- Points a unit at a new player (or back at the same one), cancelling a pending despawn.
local function retarget(current: Unit, target: Player)
	current.Target = target
	current.Ending = false
	current.EndToken += 1
	current.SeesTarget = false
	current.Bust = PoliceDispatchRules.newBustState()
	current.NextReplan = 0
	current.FarSince = nil
	logEvent(`unit {current.Id} re-targeted to {target.Name}`)
end

local function bust(current: Unit, target: Player)
	-- JailService re-validates (must be wanted, no duplicate sentence), clears wanted with no
	-- reward and holds the player in the jail cell; release is server-timed. The other units on
	-- this player are recalled by the next allocation (the player is no longer wanted).
	local stars = WantedService.getStars(target)
	local jailed, err = JailService.jailForBust(target)
	logEvent(if jailed then `unit {current.Id} BUSTED {target.Name} -> jail` else `bust of {target.Name} refused: {tostring(err)}`)
	if jailed then
		EventBus.publish("Busted", { UserId = target.UserId, Stars = stars, Unbanked = 0 })
	end
	endPursuit(current, "busted")
end

function PoliceService.setDispatchHold(player: Player, held: boolean)
	dispatchHolds[player] = if held then true else nil
end

local function activeOn(player: Player): { Unit }
	local list = {}
	for _, u in units do
		if not u.Ending and u.Target == player then
			table.insert(list, u)
		end
	end
	return list
end

-- Allocation (S2.5): who gets how many units this tick. Surplus units are recalled; a player
-- short of units takes a recalled unit still on the map first, then a new one under the cap.
local function allocate()
	local candidates: { PoliceDispatchRules.Candidate } = {}
	local byId: { [number]: Player } = {}
	local assigned: { [Player]: { Unit } } = {}
	local now = Workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		byId[player.UserId] = player
		assigned[player] = activeOn(player)
		local stars = WantedService.getStars(player)
		if stars > 0 then
			wantedSince[player] = wantedSince[player] or now
		else
			wantedSince[player] = nil
		end
		-- Protected first spree (S2.8): no dispatch for the first seconds of a new player's first spree.
		local firstSpree = stars > 0 and PoliceDispatchRules.firstSpreeHeld(EconomyService.getSprees(player), now - (wantedSince[player] :: number), SpreeConfig.FirstSpreeDispatchDelay)
		table.insert(candidates, {
			Id = player.UserId,
			Stars = stars,
			Held = dispatchHolds[player] == true or firstSpree,
			Present = true,
			Assigned = #assigned[player],
		})
	end
	for _, u in units do
		if not u.Ending and u.Target.Parent ~= Players then
			endPursuit(u, "target left")
		end
	end
	local want = PoliceDispatchRules.allocate(candidates, PoliceConfig.UnitsByStars, PoliceConfig.ServerUnitCap)
	for player, list in assigned do
		local keep = want[player.UserId] or 0
		for i = #list, keep + 1, -1 do
			endPursuit(list[i], if keep == 0 then "target no longer wanted (escaped, banked or cleared)" else "re-assigned")
			table.remove(list, i)
		end
	end
	local ids = {}
	for id in want do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local sa, sb = WantedService.getStars(byId[a]), WantedService.getStars(byId[b])
		return if sa ~= sb then sa > sb else a < b
	end)
	for _, id in ids do
		local player = byId[id]
		local list = assigned[player]
		local root = targetRoot(player)
		while #list < want[id] and root do
			-- Nearest recalled unit still on the map, else a new unit if the server has room.
			local spare: Unit? = nil
			local best = math.huge
			for _, u in units do
				local chassis = u.Model.PrimaryPart
				if u.Ending and chassis then
					local d = RoadNetwork.flatDistance(chassis.Position, root.Position)
					if d < best then
						spare, best = u, d
					end
				end
			end
			if spare then
				retarget(spare, player)
				table.insert(list, spare)
			elseif #units < PoliceConfig.ServerUnitCap then
				local fresh = spawnFor(player)
				if not fresh then
					break
				end
				table.insert(list, fresh)
			else
				break
			end
		end
	end
	-- PoliceDispatched / PoliceRecalled when a player's unit count changes.
	for _, player in Players:GetPlayers() do
		local count = #activeOn(player)
		local before = publishedUnits[player] or 0
		if count ~= before then
			publishedUnits[player] = count
			EventBus.publish(if count > before then "PoliceDispatched" else "PoliceRecalled", { UserId = player.UserId, Units = count })
		end
	end
end

local function updateUnit(current: Unit, dt: number, now: number)
	local target = current.Target
	local root = targetRoot(target)
	local chassis = current.Model.PrimaryPart
	if not root or not chassis then
		return
	end

	-- Perception.
	local distance = RoadNetwork.flatDistance(root.Position, chassis.Position)
	local sees = distance <= PoliceConfig.SightRange
		and hasLineOfSight(chassis.Position + Vector3.new(0, 3, 0), root.Position + Vector3.new(0, 1.5, 0))
	if sees ~= current.SeesTarget then
		logEvent(if sees then string.format("unit %d sighted %s at %.0f studs", current.Id, target.Name, distance) else `unit {current.Id} lost sight of {target.Name}`)
	end
	current.SeesTarget = sees

	-- Busting through the shared combat rules.
	local allowed = CombatService.canPoliceBust(target)
	if PoliceDispatchRules.updateBust(current.Bust, dt, distance, root.AssemblyLinearVelocity.Magnitude, allowed, PoliceConfig) then
		bust(current, target)
		return
	end

	-- Fallen far behind: respawn closer (out of sight).
	if distance > PoliceConfig.LostTargetRespawnDistance then
		current.FarSince = current.FarSince or now
		if now - (current.FarSince :: number) > PoliceConfig.LostTargetSeconds then
			local node = PoliceDispatchRules.chooseSpawnNode(network.Nodes, root.Position, PoliceConfig.SpawnMinDistance, PoliceConfig.SpawnMaxDistance, rng)
			if node then
				placeOnNode(current, node, root.Position)
				current.Stats.Respawns += 1
				current.NextReplan = 0
				logEvent(`unit {current.Id} respawned closer at node {network.Names[node]}`)
			end
			current.FarSince = nil
		end
	else
		current.FarSince = nil
	end

	-- Route planning: direct chase (refreshed every tick) when close and in sight, otherwise a
	-- road route re-planned every ReplanInterval.
	local chase = sees and distance <= PoliceConfig.DirectChaseRange
	if chase then
		current.Driver:setChaseTarget(root.Position, root.AssemblyLinearVelocity)
		current.NextReplan = 0
	elseif now >= current.NextReplan then
		current.NextReplan = now + PoliceConfig.ReplanInterval
		current.Driver:setRoute(PolicePathPlanner.plan(network, chassis.Position, root.Position), false)
		current.Driver:setIgnoreList(ignoreList())
	end
end

local function removeRoadblock(player: Player, reason: string)
	local block = roadblocks[player]
	if not block then
		return
	end
	roadblocks[player] = nil
	roadblockReadyAt[player] = Workspace:GetServerTimeNow() + PoliceConfig.RoadblockCooldown
	block.Model:Destroy()
	logEvent(`roadblock for {player.Name} removed ({reason})`)
end

local function buildRoadblock(center: Vector3, roadAxis: string): Model
	local width = CityLayout.ROAD_WIDTH - 4 -- 2-stud gaps at the curbs: no car fits through
	local size = if roadAxis == "X" then Vector3.new(2, 4, width) else Vector3.new(width, 4, 2)
	local model = Instance.new("Model")
	model.Name = "Roadblock"
	local base = CityLayout.ROAD_TOP
	local function part(name: string, partSize: Vector3, y: number, color: Color3, material: Enum.Material, collide: boolean)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = collide
		p.Size = partSize
		p.CFrame = CFrame.new(center.X, base + y, center.Z)
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	model.PrimaryPart = part("Barrier", size, size.Y / 2, Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic, true)
	local stripe = if roadAxis == "X" then Vector3.new(2.1, 0.8, width) else Vector3.new(width, 0.8, 2.1)
	part("Stripe", stripe, size.Y - 0.6, Color3.fromRGB(220, 40, 40), Enum.Material.Neon, false)
	return model
end

-- Roadblocks (S2.5): one per player at RoadblockStars+, RoadblockAhead studs ahead on the grid
-- road they travel, for RoadblockSeconds; removed early when they are no longer wanted.
local function updateRoadblocks(now: number)
	for player, block in roadblocks do
		if player.Parent ~= Players or now >= block.EndsAt or WantedService.getStars(player) == 0 then
			removeRoadblock(player, if now >= block.EndsAt then "expired" else "pursuit over")
		end
	end
	local active = 0
	for _ in roadblocks do
		active += 1
	end
	for _, player in Players:GetPlayers() do
		if active >= PoliceConfig.RoadblockServerCap then
			break -- busy servers: a few roadblocks, not one per 3-star player (D-019)
		end
		if roadblocks[player] or WantedService.getStars(player) < PoliceConfig.RoadblockStars or now < (roadblockReadyAt[player] or 0) then
			continue
		end
		local root = targetRoot(player)
		if not root then
			continue
		end
		local velocity = root.AssemblyLinearVelocity
		local direction = if Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 5 then velocity else root.CFrame.LookVector
		local center, axis = PoliceDispatchRules.roadblockSpot(root.Position, direction, PoliceConfig.RoadblockAhead, CityLayout.GRID_LINES, CityLayout.ROAD_WIDTH)
		if not center or not axis then
			continue
		end
		-- Never drop it on a player or a car.
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = ignoreList()
		local probe = if axis == "X" then Vector3.new(6, 8, CityLayout.ROAD_WIDTH) else Vector3.new(CityLayout.ROAD_WIDTH, 8, 6)
		if #Workspace:GetPartBoundsInBox(CFrame.new(center.X, CityLayout.ROAD_TOP + 4, center.Z), probe, params) > 0 then
			continue
		end
		local model = buildRoadblock(center, axis)
		model:SetAttribute("TargetUserId", player.UserId)
		model.Parent = npcFolder
		roadblocks[player] = { Model = model, Target = player, EndsAt = now + PoliceConfig.RoadblockSeconds }
		active += 1
		logEvent(string.format("roadblock for %s at (%.0f, %.0f) across the %s road", player.Name, center.X, center.Z, axis))
		EventBus.publish("RoadblockPlaced", { UserId = player.UserId, X = center.X, Z = center.Z, Seconds = PoliceConfig.RoadblockSeconds })
	end
end

local function tick(dt: number)
	local now = Workspace:GetServerTimeNow()
	budget.TickRays = 0
	allocate()
	budget.MaxUnits = math.max(budget.MaxUnits, #units)
	for _, current in table.clone(units) do
		if not current.Ending and table.find(units, current) then
			updateUnit(current, dt, now)
		end
	end
	updateRoadblocks(now)

	if #units > 0 and now - lastLog >= PoliceConfig.LogInterval then
		lastLog = now
		logEvent(string.format(
			"status: units=%d roadblocks=%d frames=%d avgFrame=%.3fms maxFrame=%.3fms maxRays/frame=%d",
			#units,
			(function()
				local n = 0
				for _ in roadblocks do
					n += 1
				end
				return n
			end)(),
			budget.Frames,
			if budget.Frames > 0 then budget.StepSeconds / budget.Frames * 1000 else 0,
			budget.MaxFrameMs,
			budget.MaxRaysPerFrame
		))
	end
end

local function physicsStep(dt: number)
	if #units == 0 then
		return
	end
	local frameStarted = os.clock()
	local rays = budget.TickRays -- worst case: this frame also carried the last tick's sight checks
	for _, current in table.clone(units) do
		local before = current.Driver.raycasts
		local started = os.clock()
		local event = current.Driver:step(dt, Workspace:GetServerTimeNow())
		local elapsed = os.clock() - started
		rays += current.Driver.raycasts - before
		local s = current.Stats
		s.Frames += 1
		s.StepSeconds += elapsed
		s.MaxStepMs = math.max(s.MaxStepMs, elapsed * 1000)
		if event == "HardRecover" then
			-- Repeated stalls mean the road ahead is blocked (the planner has no traffic data), so
			-- re-enter the network elsewhere, out of sight of the target, instead of retrying.
			local chassis = current.Model.PrimaryPart
			local root = targetRoot(current.Target)
			if chassis and root then
				local node = PoliceDispatchRules.chooseSpawnNode(network.Nodes, root.Position, PoliceConfig.SpawnMinDistance, PoliceConfig.SpawnMaxDistance, rng)
				if node then
					local stalledAt = chassis.Position
					placeOnNode(current, node, root.Position)
					current.NextReplan = 0
					logEvent(`unit {current.Id} hard recovery: stalled repeatedly at ({math.floor(stalledAt.X)}, {math.floor(stalledAt.Z)}); re-entered at node {network.Names[node]}`)
				end
			end
		end
	end
	local frameSeconds = os.clock() - frameStarted
	budget.Frames += 1
	budget.StepSeconds += frameSeconds
	budget.MaxFrameMs = math.max(budget.MaxFrameMs, frameSeconds * 1000)
	budget.MaxRaysPerFrame = math.max(budget.MaxRaysPerFrame, rays)
end

-- PoliceSight (R1.7): published when a player's held state changes. Held while any unit sees
-- them, or while they are wanted with no unit assigned (R1.6; the server cap can leave a wanted
-- player without a unit).
local published: { [Player]: boolean } = {}
local function publishSight()
	for _, player in Players:GetPlayers() do
		local list = activeOn(player)
		local seen = false
		for _, u in list do
			seen = seen or u.SeesTarget
		end
		local held = PoliceDispatchRules.heatHeld(WantedService.getStars(player), #list > 0, seen)
		if published[player] ~= held then
			published[player] = held
			EventBus.publish("PoliceSight", { UserId = player.UserId, Seen = held })
		end
	end
end

function PoliceService.init()
	local existing = Workspace:FindFirstChild("NpcVehicles")
	if existing then
		existing:Destroy()
	end
	npcFolder = Instance.new("Folder")
	npcFolder.Name = "NpcVehicles"
	npcFolder.Parent = Workspace
end

function PoliceService.start()
	Players.PlayerRemoving:Connect(function(player)
		dispatchHolds[player] = nil
		published[player] = nil
		publishedUnits[player] = nil
		wantedSince[player] = nil
		removeRoadblock(player, "player left")
		roadblockReadyAt[player] = nil
	end)
	RunService.PreSimulation:Connect(physicsStep)
	LoopGuard.run("Police", TICK, function(dt: number)
		tick(dt)
		publishSight()
	end)
end

-- True while any unit chasing `player` can see them (safehouses bank only without sight, S2.4).
function PoliceService.sees(player: Player): boolean
	for _, u in activeOn(player) do
		if u.SeesTarget then
			return true
		end
	end
	return false
end

-- Units currently chasing `player` (not counting recalled ones still on the map).
function PoliceService.unitsOn(player: Player): number
	return #activeOn(player)
end

-- The first live unit's model (diagnostics).
function PoliceService.getUnit(): Model?
	local first = units[1]
	return if first then first.Model else nil
end

-- The player the first live unit is chasing (nil when none).
function PoliceService.getTarget(): Player?
	for _, u in units do
		if not u.Ending then
			return u.Target
		end
	end
	return nil
end

function PoliceService.roadblockCount(): number
	local n = 0
	for _ in roadblocks do
		n += 1
	end
	return n
end

function PoliceService.hasRoadblock(player: Player): boolean
	return roadblocks[player] ~= nil
end

-- Budget numbers since the last reset (Studio scenarios read them).
function PoliceService.getBudget(): { Frames: number, AvgFrameMs: number, MaxFrameMs: number, MaxRaysPerFrame: number, MaxUnits: number, Units: number }
	return {
		Frames = budget.Frames,
		AvgFrameMs = if budget.Frames > 0 then budget.StepSeconds / budget.Frames * 1000 else 0,
		MaxFrameMs = budget.MaxFrameMs,
		MaxRaysPerFrame = budget.MaxRaysPerFrame,
		MaxUnits = budget.MaxUnits,
		Units = #units,
	}
end

function PoliceService.resetBudget()
	budget.Frames, budget.StepSeconds, budget.MaxFrameMs, budget.MaxRaysPerFrame, budget.MaxUnits = 0, 0, 0, 0, #units
end

return PoliceService
