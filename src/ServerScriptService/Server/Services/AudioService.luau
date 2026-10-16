--!strict
-- World sounds everyone hears (S2.6, architecture §14): the siren on every police unit and the
-- alarm at a crime site when its alarm trips. Sounds are positional and fade with distance
-- (AudioConfig). A sound with no approved Roblox-owned ID is skipped (AudioRules.playable), so
-- nothing plays until the owner's choices are recorded in assets/ART_SOURCES.md.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local AudioConfig = require(Shared.Config.AudioConfig)
local AudioRules = require(Shared.Rules.AudioRules)
local EventBus = require(Shared.Util.EventBus)
local WorldService = require(script.Parent.WorldService)

local AudioService = {}

local ALARM_SECONDS = 8

-- Builds a Sound from a config entry, or nil when it may not play.
function AudioService.make(name: string, parent: Instance): Sound?
	local def = AudioConfig.Sounds[name]
	if not def or not AudioRules.playable(def, AudioConfig.ApprovedIds) then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	for property, value in AudioRules.soundProps(def) do
		(sound :: any)[property] = value
	end
	sound.Parent = parent
	return sound
end

local function onUnit(unit: Instance)
	if not unit:IsA("Model") or unit.Name ~= "PoliceUnit" then
		return
	end
	local chassis = unit.PrimaryPart or unit:WaitForChild("Chassis", 5)
	if chassis and chassis:IsA("BasePart") then
		local siren = AudioService.make("Siren", chassis)
		if siren then
			siren:Play()
		end
	end
end

local function onCrimeStarted(payload: { [string]: any })
	if payload.Silent then
		return
	end
	local anchor: BasePart? = nil
	for _, site in WorldService.getCrimeSites() do
		if site.Id == payload.LocationId then
			anchor = site.Anchor
		end
	end
	if not anchor then
		local player = Players:GetPlayerByUserId(payload.UserId)
		local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		anchor = if root and root:IsA("BasePart") then root else nil
	end
	if anchor then
		local alarm = AudioService.make("Alarm", anchor)
		if alarm then
			alarm:Play()
			task.delay(ALARM_SECONDS, function()
				alarm:Destroy()
			end)
		end
	end
end

function AudioService.init()
	for _, problem in AudioRules.validate(AudioConfig.Sounds, AudioConfig.ApprovedIds) do
		warn(`[Audio] {problem}`)
	end
	local pending = {}
	for name, def in AudioConfig.Sounds do
		if def.SoundId == "" then
			table.insert(pending, name)
		end
	end
	table.sort(pending)
	if #pending > 0 then
		print(`[Audio] waiting for approved Roblox-owned IDs: {table.concat(pending, ", ")} (assets/ART_SOURCES.md)`)
	end
end

function AudioService.start()
	local folder = Workspace:WaitForChild("NpcVehicles", 10)
	if folder then
		folder.ChildAdded:Connect(onUnit)
		for _, unit in folder:GetChildren() do
			task.spawn(onUnit, unit)
		end
	end
	EventBus.subscribe("CrimeStarted", onCrimeStarted)
end

return AudioService
