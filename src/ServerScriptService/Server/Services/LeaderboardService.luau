--!strict
-- Biggest Spree boards (S2.9, architecture §13, D-016): every banked spree is submitted to the
-- daily, weekly and all-time OrderedDataStore scopes (best value kept per player); the server
-- re-reads the top rows every RefreshSeconds and pushes them with OnLeaderboard. Submissions are
-- queued and written one at a time by a guarded loop, with retries. Studio uses "studio-" scopes.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local LeaderboardConfig = require(Shared.Config.LeaderboardConfig)
local LeaderboardRules = require(Shared.Rules.LeaderboardRules)
local Remotes = require(Shared.Net.Remotes)
local EventBus = require(Shared.Util.EventBus)
local LoopGuard = require(script.Parent.Parent.Util.LoopGuard)

local LeaderboardService = {}

type Submission = { UserId: number, Amount: number }

local studio = RunService:IsStudio()
local queue: { Submission } = {}
local cache: { [string]: { LeaderboardRules.Row } } = {}
local names: { [number]: string } = {}
local nextRefresh = 0
local remote: RemoteEvent

local function storeFor(board: string): OrderedDataStore
	local scope = LeaderboardRules.scope(board, os.time(), studio, LeaderboardConfig.StudioScopePrefix) :: string
	return DataStoreService:GetOrderedDataStore(LeaderboardConfig.StoreName, scope)
end

local function submit(item: Submission)
	for _, board in LeaderboardConfig.Boards do
		local ok, err = false, nil
		for attempt = 1, LeaderboardConfig.SubmitRetries do
			ok, err = pcall(function()
				storeFor(board):UpdateAsync(tostring(item.UserId), function(old)
					local best = LeaderboardRules.merge(old, item.Amount)
					return if best == old then nil else best -- nil: keep the stored best, no write
				end)
			end)
			if ok then
				break
			end
			task.wait(attempt)
		end
		if not ok then
			warn(`[Leaderboard] {item.UserId}: {board} submit of {item.Amount} failed: {tostring(err)}`)
		end
	end
	print(`[Leaderboard] {item.UserId}: submitted {item.Amount}`)
end

-- Re-reads every board and pushes the rows to all players.
function LeaderboardService.refreshNow()
	for _, board in LeaderboardConfig.Boards do
		local ok, result = pcall(function()
			return storeFor(board):GetSortedAsync(false, LeaderboardConfig.Rows):GetCurrentPage()
		end)
		if not ok then
			warn(`[Leaderboard] {board} read failed: {tostring(result)}`)
			continue
		end
		local entries = result :: { { key: string, value: any } }
		for _, entry in entries do
			local userId = tonumber(entry.key)
			if userId and not names[userId] then
				local okName, name = pcall(function()
					return Players:GetNameFromUserIdAsync(userId)
				end)
				if okName and type(name) == "string" then
					names[userId] = name
				end
			end
		end
		cache[board] = LeaderboardRules.rows(entries, names, LeaderboardConfig.Rows)
		remote:FireAllClients(board, cache[board])
	end
end

function LeaderboardService.getRows(board: string): { LeaderboardRules.Row }
	return cache[board] or {}
end

-- Pending submissions (Studio scenarios wait for 0).
function LeaderboardService.pending(): number
	return #queue
end

function LeaderboardService.init()
	remote = Remotes.getEvent("OnLeaderboard")
end

function LeaderboardService.start()
	EventBus.subscribe("SpreeBanked", function(payload)
		if LeaderboardRules.validAmount(payload.Amount) and type(payload.UserId) == "number" then
			table.insert(queue, { UserId = payload.UserId, Amount = payload.Amount })
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		for board, rows in cache do
			remote:FireClient(player, board, rows)
		end
	end)
	LoopGuard.run("Leaderboard", 1, function()
		local item = table.remove(queue, 1)
		if item then
			submit(item)
		end
		if os.clock() >= nextRefresh then
			nextRefresh = os.clock() + LeaderboardConfig.RefreshSeconds
			LeaderboardService.refreshNow()
		end
	end)
end

return LeaderboardService
