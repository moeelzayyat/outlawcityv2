--!strict
-- Server-side observation of player characters on foot (audit F1, D-004). Samples every live,
-- unseated character at 5 Hz, runs CharacterValidationRules, logs observations and stamps the
-- player's ObservedAt attribute (server time). It never moves, resets, kicks or punishes
-- anyone; payout-bearing actions check isObserved() and refuse within the window (R1.4).
-- Seated players are skipped (vehicle validation covers cars) and get grace on leaving a seat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Rules = require(Shared.Rules.CharacterValidationRules)
local Config = require(Shared.Config.CharacterValidationConfig)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local EventBus = require(Shared.Util.EventBus)
local LoopGuard = require(script.Parent.Parent.Util.LoopGuard)

local CharacterValidationService = {}

local tracks: { [Model]: Rules.State } = setmetatable({}, { __mode = "k" }) :: any
local totals = { Samples = 0, Observations = 0, Loops = 0, LoopSeconds = 0, MaxLoopMs = 0 }

local function log(text: string)
	print(`[CharacterValidation] {text}`)
end

-- Authorized server moves of a character (jail cell, scripted teleports) call this first.
function CharacterValidationService.authorizeMove(player: Player, seconds: number?)
	local character = player.Character
	local state = character and tracks[character]
	if state then
		Rules.grant(state, Workspace:GetServerTimeNow(), seconds or Config.MoveGraceSeconds)
	end
end

-- Payout gate: observed within the last ObservationWindow seconds?
function CharacterValidationService.isObserved(player: Player): boolean
	return Rules.isObserved(player:GetAttribute(PlayerAttributes.ObservedAt), Workspace:GetServerTimeNow(), Config.ObservationWindow)
end

local function sampleAll()
	local started = os.clock()
	local now = Workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if not character or not humanoid or not root or humanoid.Health <= 0 then
			continue
		end
		local state = tracks[character]
		if not state then
			state = Rules.new(now, Config.SpawnGraceSeconds)
			tracks[character] = state
		end
		if humanoid.SeatPart then
			Rules.grantLoose(state, now, Config.SeatGraceSeconds)
			continue
		end
		totals.Samples += 1
		local observations = Rules.observe(state, { Time = now, Position = root.Position, Velocity = root.AssemblyLinearVelocity }, Config)
		for _, observation in observations do
			totals.Observations += 1
			player:SetAttribute(PlayerAttributes.ObservedAt, now)
			EventBus.publish("CharacterObserved", { UserId = player.UserId, Kind = observation.Kind })
			log(`observation {observation.Kind} ({player.Name}): {observation.Detail}`)
		end
	end
	local elapsed = os.clock() - started
	totals.Loops += 1
	totals.LoopSeconds += elapsed
	totals.MaxLoopMs = math.max(totals.MaxLoopMs, elapsed * 1000)
end

function CharacterValidationService.getTotals(): { [string]: number }
	return table.clone(totals)
end

function CharacterValidationService.init() end

function CharacterValidationService.start()
	local lastSummary = os.clock()
	LoopGuard.run("CharacterValidation", Config.SampleInterval, function()
		sampleAll()
		if os.clock() - lastSummary >= Config.SummaryInterval then
			lastSummary = os.clock()
			log(string.format(
				"summary: samples=%d observations=%d avgLoop=%.3fms maxLoop=%.3fms",
				totals.Samples,
				totals.Observations,
				if totals.Loops > 0 then totals.LoopSeconds / totals.Loops * 1000 else 0,
				totals.MaxLoopMs
			))
		end
	end)
end

return CharacterValidationService
