--!strict
-- The daily objective (S2.9, architecture §13, D-016): one per UTC day for everyone, rotating
-- through ObjectiveConfig.Daily; no streak. Completed crimes and banked sprees advance it
-- (EventBus). Progress is saved in the profile's Objectives map (today's keys only) and the reward
-- is paid once through the reward ledger (EconomyService.grantReward, tx "objective:<day>:<id>"),
-- with a "<day>:<id>:paid" marker saved after. A guarded loop does every save and payment, one
-- player at a time, so writes never race. Publishes the Objective* attributes for the client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ObjectiveConfig = require(Shared.Config.ObjectiveConfig)
local ObjectiveRules = require(Shared.Rules.ObjectiveRules)
local LeaderboardRules = require(Shared.Rules.LeaderboardRules)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local EventBus = require(Shared.Util.EventBus)
local LoopGuard = require(script.Parent.Parent.Util.LoopGuard)
local EconomyService = require(script.Parent.EconomyService)

local ObjectiveService = {}

type State = { Day: number, Progress: number, Paid: boolean, Dirty: boolean }

local states: { [Player]: State } = {}

local function today(): number
	return LeaderboardRules.dayIndex(os.time())
end

local function objectiveFor(day: number): ObjectiveRules.Objective
	return ObjectiveRules.forDay(ObjectiveConfig.Daily :: any, day) :: ObjectiveRules.Objective
end

local function publish(player: Player, state: State)
	local objective = objectiveFor(state.Day)
	player:SetAttribute(PlayerAttributes.ObjectiveText, objective.Text)
	player:SetAttribute(PlayerAttributes.ObjectiveProgress, state.Progress)
	player:SetAttribute(PlayerAttributes.ObjectiveTarget, objective.Target)
	player:SetAttribute(PlayerAttributes.ObjectiveReward, objective.Reward)
	player:SetAttribute(PlayerAttributes.ObjectiveDone, state.Paid)
end

-- Today's state for a loaded player (reads the saved progress the first time each day).
local function stateFor(player: Player): State?
	local day = today()
	local state = states[player]
	if state and state.Day == day then
		return state
	end
	local saved = EconomyService.getObjectives(player)
	if not saved then
		return nil -- data not loaded yet
	end
	local objective = objectiveFor(day)
	local key = ObjectiveRules.key(day, objective.Id)
	local progress = saved[key] or 0
	local paid = saved[key .. ":paid"] == 1
	local older = 0
	for savedKey in saved do
		if ObjectiveRules.prune({ [savedKey] = 0 }, day)[savedKey] == nil then
			older += 1
		end
	end
	state = {
		Day = day,
		Progress = math.min(progress, objective.Target),
		Paid = paid,
		-- Save once to drop older days; a complete but unpaid objective is paid by the loop.
		Dirty = older > 0 or (ObjectiveRules.complete(objective, progress) and not paid),
	}
	states[player] = state
	publish(player, state)
	return state
end

local function onEvent(userId: number, event: ObjectiveRules.Event)
	local player = Players:GetPlayerByUserId(userId)
	local state = player and stateFor(player)
	if not player or not state or state.Paid then
		return
	end
	local progress = ObjectiveRules.advance(objectiveFor(state.Day), state.Progress, event)
	if progress ~= state.Progress then
		state.Progress = progress
		state.Dirty = true
		publish(player, state)
	end
end

-- Saves and, when complete, pays one player's objective. Runs inside the guarded loop.
local function flush(player: Player, state: State)
	local objective = objectiveFor(state.Day)
	local key = ObjectiveRules.key(state.Day, objective.Id)
	if ObjectiveRules.complete(objective, state.Progress) and not state.Paid then
		local paid, err = EconomyService.grantReward(player, objective.Reward, ObjectiveRules.txId(state.Day, objective.Id), "daily objective")
		if paid or err == "DuplicateTransaction" then
			state.Paid = true
			print(`[Objective] {player.Name}: "{objective.Text}" done; +{objective.Reward}{if paid then "" else " (already paid)"}`)
			EventBus.publish("ObjectiveCompleted", { UserId = player.UserId, ObjectiveId = objective.Id, Reward = objective.Reward })
		else
			warn(`[Objective] {player.Name}: reward not paid yet ({tostring(err)}); retrying`)
			return -- stays dirty
		end
	end
	local map: { [string]: number } = { [key] = state.Progress }
	if state.Paid then
		map[key .. ":paid"] = 1
	end
	local ok, err = EconomyService.setObjectives(player, map)
	if ok then
		state.Dirty = false
	else
		warn(`[Objective] {player.Name}: progress not saved ({tostring(err)}); retrying`)
	end
	publish(player, state)
end

function ObjectiveService.get(player: Player): State?
	return states[player]
end

function ObjectiveService.init() end

function ObjectiveService.start()
	EventBus.subscribe("CrimeCompleted", function(payload)
		onEvent(payload.UserId, { Kind = "Crime" })
	end)
	EventBus.subscribe("SpreeBanked", function(payload)
		onEvent(payload.UserId, { Kind = "Banked", Amount = payload.Amount })
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	LoopGuard.run("Objectives", 1, function()
		for _, player in Players:GetPlayers() do
			local state = stateFor(player) -- also rolls over to a new UTC day
			if state and state.Dirty then
				flush(player, state)
			end
		end
	end)
end

return ObjectiveService
