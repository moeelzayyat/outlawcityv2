--!strict
-- Server entry point. Creates the network contract, then boots services in a fixed order.
-- Every service exposes init() (setup, may yield) and start() (connect runtime events).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local LoopGuard = require(script.Parent.Util.LoopGuard)
local EventBus = require(ReplicatedStorage.Shared.Util.EventBus)
local PlayerAttributes = require(ReplicatedStorage.Shared.Player.PlayerAttributes)
local Services = script.Parent.Services
local Dev = script.Parent.Dev

type Service = { init: () -> (), start: () -> () }

local modules: { ModuleScript } = {
	Services.AnalyticsService, -- first: its init takes over error reporting
	Services.WorldService,
	Services.PlayerStateService,
	Services.SpawnService,
	Services.EconomyService,
	Services.SafeZoneService,
	Services.JailService,
	Services.WantedService,
	Services.CrimeService,
	Services.SpreeService,
	Services.DealershipService,
	Services.CombatService,
	Services.PoliceService,
	Dev.DevToolsService,
	Dev.MilestoneLog,
	Services.VehicleService,
	Services.ParkedCarService,
	Services.VehicleValidationService,
	Services.CharacterValidationService,
}

local services: { { name: string, service: Service } } = {}
for _, module in modules do
	table.insert(services, { name = module.Name, service = (require :: any)(module) })
end

-- A failing init/start is reported and the boot continues, so one service can't take the
-- whole server down (architecture §5).
Remotes.createAll()
for _, entry in services do
	local ok, err = pcall(entry.service.init)
	if not ok then
		LoopGuard.report(`{entry.name}.init`, tostring(err))
	end
end
for _, entry in services do
	task.spawn(function()
		local ok, err = pcall(entry.service.start)
		if not ok then
			LoopGuard.report(`{entry.name}.start`, tostring(err))
		end
	end)
end
-- Session events for analytics (R1.7).
local function onJoined(player: Player)
	EventBus.publish("PlayerJoined", { UserId = player.UserId })
end
Players.PlayerAdded:Connect(onJoined)
for _, player in Players:GetPlayers() do
	onJoined(player)
end
Players.PlayerRemoving:Connect(function(player)
	local phase = player:GetAttribute(PlayerAttributes.RobberyPhase)
	EventBus.publish("PlayerLeft", { UserId = player.UserId, Phase = if type(phase) == "string" then phase else "Idle" })
end)
Workspace:SetAttribute("ServerReady", true)

-- In Studio, run the unit tests on every playtest unless Workspace.RunTestsOnStart is false.
if RunService:IsStudio() and Workspace:GetAttribute("RunTestsOnStart") ~= false then
	local tests = ServerStorage:FindFirstChild("Tests")
	local runner = tests and tests:FindFirstChild("TestRunner")
	if runner then
		(require :: any)(runner).run(tests)
	end
end

-- In Studio, a multi-client scenario started with
-- StudioTestService:ExecuteMultiplayerTestAsync(n, "<name>") runs from ServerStorage.Tests.Scenarios.
if RunService:IsStudio() then
	local okArgs, args = pcall(function()
		return game:GetService("StudioTestService"):GetTestArgs()
	end)
	local tests = ServerStorage:FindFirstChild("Tests")
	local scenarios = tests and tests:FindFirstChild("Scenarios")
	if okArgs and type(args) == "string" and scenarios then
		task.spawn((require :: any)(scenarios).run, args)
	end
end
