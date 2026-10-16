--!strict
-- Funnel and server diagnostics (R1.7). Consumes EventBus events and never publishes gameplay.
-- Funnel milestones go to Roblox's AnalyticsService (onboarding funnel steps once per player,
-- custom events otherwise); every call is pcall-wrapped so analytics can never break play.
-- Server errors reported by LoopGuard, Main and the bus are counted here, logged, and kept in
-- ServerStorage.Diagnostics (ServerErrors, LastServerError).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RobloxAnalytics = game:GetService("AnalyticsService")

local Shared = ReplicatedStorage.Shared
local EventBus = require(Shared.Util.EventBus)
local FunnelRules = require(Shared.Rules.FunnelRules)
local LoopGuard = require(script.Parent.Parent.Util.LoopGuard)

local AnalyticsService = {}

local states: { [number]: FunnelRules.State } = {}
local joinedAt: { [number]: number } = {}
local serverErrors = 0

local function diagnostics(): Folder
	local folder = ServerStorage:FindFirstChild("Diagnostics")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Diagnostics"
		folder.Parent = ServerStorage
	end
	return folder :: Folder
end

local function reportError(source: string, message: string)
	serverErrors += 1
	local folder = diagnostics()
	folder:SetAttribute("ServerErrors", serverErrors)
	folder:SetAttribute("LastServerError", `{source}: {message}`)
	warn(`[Loop] {source} iteration failed: {message}`)
end

local function log(player: Player, name: string, value: number?)
	local state = states[player.UserId]
	if not state then
		state = FunnelRules.new()
		states[player.UserId] = state
	end
	local first, step = FunnelRules.mark(state, name)
	if not first then
		return
	end
	if step then
		pcall(function()
			RobloxAnalytics:LogOnboardingFunnelStepEvent(player, step, name)
		end)
	else
		pcall(function()
			RobloxAnalytics:LogCustomEvent(player, name, value or 1)
		end)
	end
	print(`[Analytics] {name} ({player.Name}){if value then " " .. tostring(value) else ""}`)
end

local function on(event: string, name: string, value: ((EventBus.Payload) -> number?)?)
	EventBus.subscribe(event, function(payload)
		local player = Players:GetPlayerByUserId(payload.UserId)
		if player then
			log(player, name, if value then value(payload) else nil)
		end
	end)
end

function AnalyticsService.getServerErrors(): number
	return serverErrors
end

function AnalyticsService.init()
	LoopGuard.report = reportError
	EventBus.setErrorHandler(function(event: string, message: string)
		reportError(`EventBus.{event}`, message)
	end)
end

function AnalyticsService.start()
	on("PlayerJoined", "Joined")
	EventBus.subscribe("PlayerJoined", function(payload)
		joinedAt[payload.UserId] = os.clock()
	end)
	on("VehicleSpawned", "FirstCar")
	on("CrimeStarted", "FirstCrime")
	on("SpreeBanked", "FirstBank")
	on("Busted", "FirstBust")
	on("PlayerLeft", "Left", function(payload)
		local started = joinedAt[payload.UserId]
		joinedAt[payload.UserId] = nil
		return if started then math.floor(os.clock() - started) else nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			states[player.UserId] = nil
		end)
	end)
end

return AnalyticsService
