--!strict
-- Server entry point. Creates the network contract, then boots services in a fixed order.
-- Every service exposes init() (setup, may yield) and start() (connect runtime events).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local LoopGuard = require(script.Parent.Util.LoopGuard)
local Services = script.Parent.Services
local Dev = script.Parent.Dev

type Service = { init: () -> (), start: () -> () }

local modules: { ModuleScript } = {
	Services.WorldService,
	Services.PlayerStateService,
	Services.SpawnService,
	Services.EconomyService,
	Services.SafeZoneService,
	Services.JailService,
	Services.WantedService,
	Services.RobberyService,
	Services.DealershipService,
	Services.CombatService,
	Services.PoliceService,
	Dev.DevToolsService,
	Dev.MilestoneLog,
	Services.VehicleService,
	Services.VehicleValidationService,
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
Workspace:SetAttribute("ServerReady", true)

-- In Studio, run the unit tests on every playtest unless Workspace.RunTestsOnStart is false.
if RunService:IsStudio() and Workspace:GetAttribute("RunTestsOnStart") ~= false then
	local tests = ServerStorage:FindFirstChild("Tests")
	local runner = tests and tests:FindFirstChild("TestRunner")
	if runner then
		(require :: any)(runner).run(tests)
	end
end
