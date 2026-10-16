--!strict
-- Small SAFE ZONE badge under the Combat button, shown while the server says the player is in a
-- safe zone. Turns amber while wanted, because police can still bust wanted players there.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerAttributes = require(ReplicatedStorage.Shared.Player.PlayerAttributes)

local UiRoot = require(script.Parent.UiRoot)
local HudLayout = require(game:GetService("ReplicatedStorage").Shared.Config.HudLayout)

local SafeZoneHudController = {}

local SAFE_COLOR = Color3.fromRGB(40, 150, 90)
local WANTED_COLOR = Color3.fromRGB(205, 130, 20)

local player = Players.LocalPlayer

function SafeZoneHudController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SafeZoneHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.Text = "SAFE ZONE"
	UiRoot.place(badge, HudLayout.Slots.SafeZoneBadge) -- row 1, left of the centred wanted stars (S2.7)
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 13
	badge.Visible = false
	badge.Parent = UiRoot.mount(gui)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = badge

	local function refresh()
		local inside = player:GetAttribute(PlayerAttributes.InSafeZone) == true
		local wanted = player:GetAttribute(PlayerAttributes.WantedLevel)
		badge.Visible = inside
		badge.BackgroundColor3 = if type(wanted) == "number" and wanted > 0 then WANTED_COLOR else SAFE_COLOR
	end
	player:GetAttributeChangedSignal(PlayerAttributes.InSafeZone):Connect(refresh)
	player:GetAttributeChangedSignal(PlayerAttributes.WantedLevel):Connect(refresh)
	refresh()
end

return SafeZoneHudController
