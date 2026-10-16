--!strict
-- Server authority for holdout crimes (S2.3; replaces RobberyService, architecture §10). Every
-- crime site — the store, the four ATMs, the gas station — runs the RobberyRules engine with its
-- crime's numbers from CrimeConfig. The client only triggers the site's ProximityPrompt and
-- shows what the server publishes.
-- Flow: prompt → validate (alive, not jailed, not observed, not in a safe zone, on foot, near the
-- prompt, site free and off cooldown, no other crime live, cash data loaded) → alarm roll (stars,
-- or a silent crime) → holdout inside the site's Area (server bounds query, R1.4) →
-- CrimeCompleted: the spree adds the cash (D-001). Death, bust, observation, leaving the area or
-- disconnecting fail it with no cash.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Remotes = require(Shared.Net.Remotes)
local CrimeConfig = require(Shared.Config.CrimeConfig)
local WantedConfig = require(Shared.Config.WantedConfig)
local CrimeRules = require(Shared.Rules.CrimeRules)
local RobberyRules = require(Shared.Robbery.RobberyRules)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local EventBus = require(Shared.Util.EventBus)

local Services = script.Parent
local WorldService = require(Services.WorldService)
local WantedService = require(Services.WantedService)
local JailService = require(Services.JailService)
local EconomyService = require(Services.EconomyService)
local PoliceService = require(Services.PoliceService)
local CharacterValidationService = require(Services.CharacterValidationService)
local MilestoneLog = require(script.Parent.Parent.Dev.MilestoneLog)
local LoopGuard = require(script.Parent.Parent.Util.LoopGuard)
local AreaCheck = require(script.Parent.Parent.Crime.AreaCheck)

local CrimeService = {}

type Site = {
	Id: string,
	CrimeId: string,
	Crime: CrimeConfig.Crime,
	State: RobberyRules.StoreState,
	Anchor: BasePart,
	Area: BasePart,
	Folder: Instance,
}
type Live = { Session: RobberyRules.Session, Site: Site, Character: Model, LastInProgressReport: number, Alarm: boolean }

local sites: { [string]: Site } = {}
local live: { [Player]: Live } = {}
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

-- Display only: cooldown and busy state for the client's markers. The server decides every start.
local function publishSite(site: Site)
	local cooldownUntil = site.State.CooldownUntil
	site.Folder:SetAttribute("RobberyCooldownUntil", if cooldownUntil == -math.huge then 0 else cooldownUntil)
	site.Folder:SetAttribute("RobberyBusy", site.State.ActiveSession ~= nil)
end

local function publish(player: Player, entry: Live?)
	local session = entry and entry.Session
	local isLive = session ~= nil and RobberyRules.isLive(session)
	player:SetAttribute(PlayerAttributes.RobberyPhase, if isLive then (session :: any).Phase else nil)
	player:SetAttribute(PlayerAttributes.RobberyHoldEndsAt, if isLive then (session :: any).HoldEndsAt else nil)
	player:SetAttribute(PlayerAttributes.RobberyReward, if isLive then (session :: any).Reward else nil)
	player:SetAttribute(PlayerAttributes.CrimeName, if isLive and entry then entry.Site.Crime.Name else nil)
end

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function isAlive(character: Model?): boolean
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and rootOf(character) ~= nil
end

local function endSession(player: Player, entry: Live)
	if live[player] == entry then
		live[player] = nil
	end
	PoliceService.setDispatchHold(player, false)
	publish(player, nil)
end

local function failSession(player: Player, entry: Live, reason: Types.RobberyFailReason)
	if live[player] ~= entry then
		return -- already ended: a duplicate failure never notifies or changes anything twice
	end
	endSession(player, entry)
	notify(player, "Failed", { Reason = reason, Id = entry.Session.Id, CrimeId = entry.Site.CrimeId, Name = entry.Site.Crime.Name })
	print(`[Crime] {player.Name} {entry.Site.CrimeId} at {entry.Site.Id} failed: {reason}`)
	EventBus.publish("CrimeFailed", { UserId = player.UserId, CrimeId = entry.Site.CrimeId, LocationId = entry.Site.Id, Reason = reason })
end

-- Is this player in a live holdout? (car theft and vehicle rules use it)
function CrimeService.isBusy(player: Player): boolean
	return live[player] ~= nil
end

-- Tries to start the crime at `siteId` for `player`. Everything is checked here, on the server.
function CrimeService.tryStart(player: Player, siteId: string): (boolean, Types.RobberyStartError?)
	local site = sites[siteId]
	if not site or player.Parent ~= Players then
		return false, "TooFar"
	end
	local crime = site.Crime
	local character = player.Character
	local root = rootOf(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local t = now()
	local facts: RobberyRules.StartFacts = {
		Alive = isAlive(character),
		Jailed = JailService.isJailed(player),
		InSafeZone = player:GetAttribute(PlayerAttributes.InSafeZone) == true,
		InVehicle = humanoid ~= nil and humanoid.SeatPart ~= nil,
		DistanceToRegister = if root then (root.Position - site.Anchor.Position).Magnitude else math.huge,
		HasActiveSession = live[player] ~= nil,
		CashReady = EconomyService.getStatus(player) == "Loaded",
		Observed = CharacterValidationService.isObserved(player),
	}
	local ok, err = RobberyRules.canStart(site.State, facts, t, crime)
	if not ok then
		notify(player, "Rejected", {
			Reason = err,
			CrimeId = site.CrimeId,
			CooldownLeft = if err == "StoreCooldown" then math.ceil(site.State.CooldownUntil - t) else nil,
		})
		return false, err
	end
	local session = RobberyRules.start(site.State, HttpService:GenerateGUID(false), player.UserId, siteId, t, crime)
	local alarm = CrimeRules.alarmTrips(crime.AlarmChance, rng:NextNumber())
	local entry: Live = { Session = session, Site = site, Character = character :: Model, LastInProgressReport = t, Alarm = alarm }
	live[player] = entry
	if alarm then
		if crime.PoliceDispatchAtHoldEnd then
			PoliceService.setDispatchHold(player, true)
		end
		WantedService.reportCrime(player, crime.WantedCrime)
	end
	publish(player, entry)
	publishSite(site)
	notify(player, "Started", { Id = session.Id, HoldEndsAt = session.HoldEndsAt, Reward = session.Reward, CrimeId = site.CrimeId, Name = crime.Name, Alarm = alarm })
	print(`[Crime] {player.Name} started {site.CrimeId} at {site.Id} ({if alarm then "alarm" else "silent"})`)
	EventBus.publish("CrimeStarted", { UserId = player.UserId, CrimeId = site.CrimeId, LocationId = site.Id, Silent = not alarm })
	MilestoneLog.mark(player, "FirstRobbery")
	return true, nil
end

local function tick()
	local t = now()
	for player, entry in live do
		local session = entry.Session
		local site = entry.Site
		local character = player.Character
		local facts: RobberyRules.TickFacts = {
			Connected = player.Parent == Players,
			Alive = character == entry.Character and isAlive(character), -- a reset or respawn counts as death
			Jailed = JailService.isJailed(player),
			-- Server bounds query over the character's parts, not the root position alone (R1.4).
			InArea = character ~= nil and AreaCheck.characterInside(site.Area, character),
			Observed = CharacterValidationService.isObserved(player),
		}
		local event, reason = RobberyRules.tick(session, site.State, facts, t, site.Crime)
		if event == "Failed" then
			failSession(player, entry, reason :: Types.RobberyFailReason)
		elseif event == "HoldComplete" then
			-- D-001: the crime's cash goes into the player's spree now; escaping no longer pays.
			endSession(player, entry)
			notify(player, "Completed", { Id = session.Id, Reward = session.Reward, CrimeId = site.CrimeId, Name = site.Crime.Name })
			print(`[Crime] {player.Name} {site.CrimeId} at {site.Id} complete; +{session.Reward} to the spree`)
			EventBus.publish("CrimeCompleted", { UserId = player.UserId, CrimeId = site.CrimeId, LocationId = site.Id, Amount = session.Reward, Stars = WantedService.getStars(player) })
		elseif session.Phase == "Holding" and entry.Alarm and t - entry.LastInProgressReport >= 1 then
			-- Keep an alarmed criminal hot while inside so heat can't decay before the holdout ends.
			entry.LastInProgressReport = t
			WantedService.reportCrime(player, site.Crime.InProgressCrime)
		end
	end
	for _, site in sites do
		publishSite(site)
	end
end

-- Studio dev tools only: lets a solo tester repeat crimes without waiting out cooldowns.
function CrimeService.clearCooldownsForTesting()
	for _, site in sites do
		site.State.CooldownUntil = -math.huge
		publishSite(site)
	end
end

function CrimeService.getSiteIds(): { string }
	local ids = {}
	for id in sites do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

function CrimeService.init()
	noticeRemote = Remotes.getEvent("OnRobberyNotice")
	local problems = CrimeRules.validate(CrimeConfig.Crimes, WantedConfig.Crimes)
	for _, problem in problems do
		warn(`[Crime] invalid crime definition: {problem}`)
	end
	for _, info in WorldService.getCrimeSites() do
		local crime = CrimeConfig.Crimes[info.CrimeId]
		if not crime or not crime.Holdout then
			warn(`[Crime] site {info.Id} has unknown holdout crime {info.CrimeId}; skipped`)
			continue
		end
		local site: Site = {
			Id = info.Id,
			CrimeId = info.CrimeId,
			Crime = crime,
			State = RobberyRules.newStore(),
			Anchor = info.Anchor,
			Area = info.Area,
			Folder = info.Folder,
		}
		sites[info.Id] = site
		publishSite(site)
		info.Prompt.ActionText = crime.Verb
		info.Prompt.Triggered:Connect(function(player)
			CrimeService.tryStart(player, site.Id)
		end)
	end
end

function CrimeService.start()
	Players.PlayerRemoving:Connect(function(player)
		local entry = live[player]
		if entry then
			RobberyRules.tick(entry.Session, entry.Site.State, {
				Connected = false, Alive = false, Jailed = false, InArea = false,
			}, now(), entry.Site.Crime)
			live[player] = nil
			print(`[Crime] {player.Name} {entry.Site.CrimeId} failed: Disconnected`)
		end
	end)
	LoopGuard.run("Crime", CrimeConfig.TickInterval, tick)
end

return CrimeService
