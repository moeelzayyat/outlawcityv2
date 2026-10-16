--!strict
-- The player's own sounds (S2.6, architecture §14): the engine loop of the car they drive (pitch
-- by speed), tyre squeal when it slides, and the bank / bust stings. Display only; a sound with
-- no approved Roblox-owned ID is skipped (AudioRules.playable).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage.Shared
local AudioConfig = require(Shared.Config.AudioConfig)
local AudioRules = require(Shared.Rules.AudioRules)
local Remotes = require(Shared.Net.Remotes)

local AudioController = {}

local player = Players.LocalPlayer

local function make(name: string, parent: Instance): Sound?
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

local function sting(name: string)
	local sound = make(name, SoundService)
	if sound then
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
	end
end

function AudioController.init()
	Remotes.getEvent("OnSpreeNotice").OnClientEvent:Connect(function(kind: string)
		if kind == "Banked" then
			sting("Bank")
		elseif kind == "Lost" then
			sting("Bust")
		end
	end)

	-- Engine and tyres follow the seat the player drives.
	local seat: BasePart? = nil
	local engine: Sound? = nil
	local tyre: Sound? = nil
	local tyreVolume = AudioConfig.Sounds.Tyre.Volume
	local function clear()
		if engine then
			engine:Destroy()
		end
		if tyre then
			tyre:Destroy()
		end
		engine, tyre, seat = nil, nil, nil
	end
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local current = humanoid and humanoid.SeatPart
		if current ~= seat then
			clear()
			if current and current:IsA("VehicleSeat") or (current and current.Name == "DriverSeat") then
				seat = current
				engine = make("Engine", current :: Instance)
				tyre = make("Tyre", current :: Instance)
				if engine then
					engine:Play()
				end
				if tyre then
					tyre.Volume = 0
					tyre:Play()
				end
			end
		end
		if seat then
			local velocity = seat.AssemblyLinearVelocity
			if engine then
				engine.PlaybackSpeed = AudioRules.enginePitch(velocity:Dot(seat.CFrame.LookVector), AudioConfig.EngineTopSpeed, AudioConfig.EnginePitchMin, AudioConfig.EnginePitchMax)
			end
			if tyre then
				tyre.Volume = tyreVolume * AudioRules.tyreLevel(velocity:Dot(seat.CFrame.RightVector), AudioConfig.TyreSlipSpeed, AudioConfig.TyreSlipFull)
			end
		end
	end)
end

return AudioController
