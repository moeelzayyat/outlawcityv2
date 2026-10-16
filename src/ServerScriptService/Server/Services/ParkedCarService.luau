--!strict
-- Parked cars that can be stolen (S2.3, CrimeConfig.CarTheft). Each CityLayout parked-car spot
-- holds an unowned car with a "Steal car" prompt on its body. Stealing completes on the spot:
-- the alarm may trip (1 star), the crime's cash goes into the spree, and the car becomes the
-- thief's getaway car (their old one is despawned). A spot refills CooldownSeconds after it was
-- emptied, once nothing stands in it. The same server checks as every crime apply.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local CrimeConfig = require(Shared.Config.CrimeConfig)
local CrimeRules = require(Shared.Rules.CrimeRules)
local RobberyRules = require(Shared.Robbery.RobberyRules)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local EventBus = require(Shared.Util.EventBus)
local Server = script.Parent.Parent
local CityLayout = require(Server.World.CityLayout)
local LoopGuard = require(Server.Util.LoopGuard)
local VehicleService = require(script.Parent.VehicleService)
local WantedService = require(script.Parent.WantedService)
local JailService = require(script.Parent.JailService)
local EconomyService = require(script.Parent.EconomyService)
local CharacterValidationService = require(script.Parent.CharacterValidationService)
local CrimeService = require(script.Parent.CrimeService)

local ParkedCarService = {}

local CRIME_ID = "CarTheft"
local PARKED_VEHICLE = "Coupe"
local REFILL_CHECK = 2
local SPOT_CLEARANCE = Vector3.new(8, 6, 14)

type Spot = { Id: string, CFrame: CFrame, Car: Model?, State: RobberyRules.StoreState }

local spots: { [string]: Spot } = {}
local rng = Random.new()
local noticeRemote: RemoteEvent

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function notify(player: Player, kind: string, payload: { [string]: any })
	if player.Parent == Players then
		noticeRemote:FireClient(player, kind, payload)
	end
end

local function crime(): CrimeConfig.Crime
	return CrimeConfig.Crimes[CRIME_ID]
end

-- Steals the car at `spotId` for `player`. Returns (ok, err).
function ParkedCarService.trySteal(player: Player, spotId: string): (boolean, string?)
	local spot = spots[spotId]
	local car = spot and spot.Car
	if not spot or not car or not car.Parent or player.Parent ~= Players then
		return false, "TooFar"
	end
	local definition = crime()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local t = now()
	local facts: RobberyRules.StartFacts = {
		Alive = humanoid ~= nil and humanoid.Health > 0 and root ~= nil,
		Jailed = JailService.isJailed(player),
		InSafeZone = player:GetAttribute(PlayerAttributes.InSafeZone) == true,
		InVehicle = humanoid ~= nil and humanoid.SeatPart ~= nil,
		DistanceToRegister = if root then (root.Position - car:GetPivot().Position).Magnitude else math.huge,
		HasActiveSession = CrimeService.isBusy(player),
		CashReady = EconomyService.getStatus(player) == "Loaded",
		Observed = CharacterValidationService.isObserved(player),
	}
	local ok, err = RobberyRules.canStart(spot.State, facts, t, definition)
	if not ok then
		notify(player, "Rejected", { Reason = err, CrimeId = CRIME_ID })
		return false, err
	end
	if not VehicleService.adoptStolen(player, car) then
		return false, "Dead"
	end
	spot.Car = nil
	spot.State.CooldownUntil = t + definition.CooldownSeconds
	local prompt = car:FindFirstChild("StealPrompt", true)
	if prompt then
		prompt:Destroy()
	end
	local alarm = CrimeRules.alarmTrips(definition.AlarmChance, rng:NextNumber())
	if alarm then
		WantedService.reportCrime(player, definition.WantedCrime)
	end
	EventBus.publish("CrimeStarted", { UserId = player.UserId, CrimeId = CRIME_ID, LocationId = spot.Id, Silent = not alarm })
	notify(player, "Completed", { Reward = definition.Reward, CrimeId = CRIME_ID, Name = definition.Name, Alarm = alarm })
	print(`[Crime] {player.Name} stole the car at {spot.Id} ({if alarm then "alarm" else "silent"}); +{definition.Reward} to the spree`)
	EventBus.publish("CrimeCompleted", { UserId = player.UserId, CrimeId = CRIME_ID, LocationId = spot.Id, Amount = definition.Reward, Stars = WantedService.getStars(player) })
	return true, nil
end

local function spotClear(spot: Spot): boolean
	local blockers: { Instance } = {}
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if vehicles then
		table.insert(blockers, vehicles)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(blockers, player.Character)
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = blockers
	return #Workspace:GetPartBoundsInBox(spot.CFrame + Vector3.new(0, SPOT_CLEARANCE.Y / 2, 0), SPOT_CLEARANCE, params) == 0
end

local function fill(spot: Spot)
	local car = VehicleService.spawnParked(PARKED_VEHICLE, spot.CFrame, spot.Id)
	if not car then
		return
	end
	spot.Car = car
	local body = car.PrimaryPart
	if body then
		local definition = crime()
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StealPrompt"
		prompt.ActionText = definition.Verb
		prompt.ObjectText = "Parked car"
		prompt.HoldDuration = CrimeConfig.StealHoldSeconds
		prompt.MaxActivationDistance = definition.PromptDistance
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = body
		prompt.Triggered:Connect(function(player)
			ParkedCarService.trySteal(player, spot.Id)
		end)
	end
end

local function refill()
	local t = now()
	for _, spot in spots do
		if spot.Car and not spot.Car.Parent then
			spot.Car = nil -- destroyed some other way: refill after the normal wait
			spot.State.CooldownUntil = t + crime().CooldownSeconds
		end
		if not spot.Car and t >= spot.State.CooldownUntil and spotClear(spot) then
			fill(spot)
		end
	end
end

-- Studio dev tools only.
function ParkedCarService.getSpotIds(): { string }
	local ids = {}
	for id in spots do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

function ParkedCarService.init()
	noticeRemote = Remotes.getEvent("OnRobberyNotice")
	for _, spec in CityLayout.parkedCars() do
		spots[spec.Name] = { Id = spec.Name, CFrame = spec.CFrame, Car = nil, State = RobberyRules.newStore() }
	end
end

function ParkedCarService.start()
	refill()
	LoopGuard.run("ParkedCars", REFILL_CHECK, refill)
end

return ParkedCarService
