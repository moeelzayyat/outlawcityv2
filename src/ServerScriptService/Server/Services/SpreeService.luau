--!strict
-- Server authority for Crime Sprees (S2.2, D-001). One SpreeRules state per player: completed
-- crimes (CrimeCompleted) add base × multiplier to the unbanked cash, an escape keeps the spree,
-- a bust or leaving loses it, and bank() pays it through EconomyService.bankSpree — recorded in
-- the reward ledger first and granted once per spree id ("spree:<id>"). Publishes the
-- SpreeUnbanked / SpreeMultiplier / SpreeCrimes attributes and OnSpreeNotice for the HUD.
-- Banking at a safehouse arrives in S2.4 (SafehouseService calls bank()).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local EventBus = require(Shared.Util.EventBus)
local SpreeRules = require(Shared.Rules.SpreeRules)
local SpreeConfig = require(Shared.Config.SpreeConfig)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local EconomyService = require(script.Parent.EconomyService)
local WantedService = require(script.Parent.WantedService)
local CharacterValidationService = require(script.Parent.CharacterValidationService)

local SpreeService = {}

local states: { [Player]: SpreeRules.Spree } = {}
local banking: { [Player]: boolean } = {}
local noticeRemote: RemoteEvent

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish(player: Player, spree: SpreeRules.Spree)
	player:SetAttribute(PlayerAttributes.SpreeUnbanked, if spree.Active then spree.Unbanked else 0)
	player:SetAttribute(PlayerAttributes.SpreeMultiplier, spree.Multiplier)
	player:SetAttribute(PlayerAttributes.SpreeCrimes, spree.Crimes)
end

local function notify(player: Player, kind: string, payload: { [string]: any })
	if player.Parent == Players then
		noticeRemote:FireClient(player, kind, payload)
	end
end

local function stateFor(player: Player): SpreeRules.Spree
	local spree = states[player]
	if not spree then
		spree = SpreeRules.new(SpreeConfig)
		states[player] = spree
	end
	return spree
end

function SpreeService.get(player: Player): SpreeRules.Spree?
	return states[player]
end

local function onCrimeCompleted(player: Player, amount: any, stars: any)
	local spree = stateFor(player)
	local wasActive = spree.Active
	local ok, err, added = SpreeRules.addCrime(spree, HttpService:GenerateGUID(false), amount, stars, now(), SpreeConfig)
	if not ok then
		warn(`[Spree] {player.Name}: crime refused ({err})`)
		return
	end
	publish(player, spree)
	local payload = { UserId = player.UserId, SpreeId = spree.Id :: string, Unbanked = spree.Unbanked, Multiplier = spree.Multiplier, Crimes = spree.Crimes }
	EventBus.publish(if wasActive then "SpreeUpdated" else "SpreeStarted", payload)
	notify(player, "Added", { Amount = added, Unbanked = spree.Unbanked, Multiplier = spree.Multiplier, Crimes = spree.Crimes })
	print(`[Spree] {player.Name}: +{added} -> {spree.Unbanked} unbanked (crime {spree.Crimes}, next x{spree.Multiplier})`)
end

-- Loses the spree (bust or leaving). Banked cash is never touched.
local function lose(player: Player, reason: string)
	local spree = states[player]
	if not spree then
		return
	end
	local id, lost = SpreeRules.bust(spree, SpreeConfig)
	if not id then
		return
	end
	publish(player, spree)
	EventBus.publish("SpreeLost", { UserId = player.UserId, SpreeId = id, Amount = lost, Reason = reason })
	notify(player, "Lost", { Amount = lost, Reason = reason })
	print(`[Spree] {player.Name}: spree lost ({reason}), -{lost} unbanked`)
end

-- Banks the player's spree now (the safehouse decides when; S2.4). Returns (ok, err).
function SpreeService.bank(player: Player): (boolean, string?)
	local spree = states[player]
	if banking[player] then
		return false, "InFlight"
	end
	if not spree or not SpreeRules.canBank(spree) then
		return false, "NothingToBank"
	end
	if CharacterValidationService.isObserved(player) then
		return false, "Observed"
	end
	local result = SpreeRules.bank(spree, now(), SpreeConfig) :: SpreeRules.BankResult
	banking[player] = true
	publish(player, spree)
	local paid, err, recorded = EconomyService.bankSpree(player, result.SpreeId, result.Amount, result.Reputation)
	banking[player] = nil
	if not paid and err ~= "DuplicateTransaction" and not recorded then
		-- Neither stored nor recorded: give the spree back rather than lose the player's cash.
		spree.Id = result.SpreeId
		spree.Active = true
		spree.Unbanked = result.Amount
		spree.Crimes = result.Crimes
		spree.PeakStars = result.PeakStars
		spree.StartedAt = now() - result.Duration
		spree.Multiplier = math.min(SpreeConfig.MultiplierCap, SpreeConfig.MultiplierStart + SpreeConfig.MultiplierStep * result.Crimes)
		publish(player, spree)
		notify(player, "BankFailed", { Amount = result.Amount })
		warn(`[Spree] {player.Name}: bank of {result.Amount} not stored ({tostring(err)}); spree kept`)
		return false, err
	end
	EventBus.publish("SpreeBanked", {
		UserId = player.UserId,
		SpreeId = result.SpreeId,
		Amount = result.Amount,
		PeakStars = result.PeakStars,
		Duration = result.Duration,
		Crimes = result.Crimes,
	})
	notify(player, "Banked", {
		Amount = result.Amount,
		PeakStars = result.PeakStars,
		Crimes = result.Crimes,
		Duration = result.Duration,
		Reputation = result.Reputation,
		Pending = not paid, -- recorded in the ledger; the claim pays it shortly
	})
	print(`[Spree] {player.Name}: banked {result.Amount} (crimes {result.Crimes}, peak {result.PeakStars}★, {math.floor(result.Duration)}s, +{result.Reputation} rep){if paid then "" else " — recorded, payment pending"}`)
	return true, nil
end

function SpreeService.init()
	noticeRemote = Remotes.getEvent("OnSpreeNotice")
end

function SpreeService.start()
	EventBus.subscribe("CrimeCompleted", function(payload)
		local player = Players:GetPlayerByUserId(payload.UserId)
		if player then
			onCrimeCompleted(player, payload.Amount, payload.Stars or WantedService.getStars(player))
		end
	end)
	EventBus.subscribe("Busted", function(payload)
		local player = Players:GetPlayerByUserId(payload.UserId)
		if player then
			lose(player, "Busted")
			EconomyService.noteBust(player)
		end
	end)
	EventBus.subscribe("Escaped", function(payload)
		local player = Players:GetPlayerByUserId(payload.UserId)
		local spree = player and states[player]
		if spree then
			SpreeRules.onEscaped(spree)
		end
	end)
	EventBus.subscribe("StarsChanged", function(payload)
		local player = Players:GetPlayerByUserId(payload.UserId)
		local spree = player and states[player]
		if spree then
			SpreeRules.noteStars(spree, payload.Stars)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		publish(player, stateFor(player))
	end)
	for _, player in Players:GetPlayers() do
		publish(player, stateFor(player))
	end
	Players.PlayerRemoving:Connect(function(player)
		lose(player, "Left")
		states[player] = nil
		banking[player] = nil
	end)
end

return SpreeService
