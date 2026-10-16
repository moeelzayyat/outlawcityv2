--!strict
-- Safehouse markers and bank progress (S2.4). A floating sign over each safehouse's opening
-- (City.Safehouses.<Id>.Marker): shown at marker distances normally, and from anywhere while the
-- player holds an unbanked spree, when it turns gold and says to bank there. Inside a safehouse a
-- bar under the spree counter fills over the bank time, or says why it can't (police sight).
-- Display only: SafehouseService decides every bank.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local SpreeConfig = require(Shared.Config.SpreeConfig)
local OnboardingConfig = require(Shared.Config.OnboardingConfig)
local OnboardingRules = require(Shared.Onboarding.OnboardingRules)

local UiRoot = require(script.Parent.UiRoot)
local HudLayout = require(game:GetService("ReplicatedStorage").Shared.Config.HudLayout)

local SafehouseMarkerController = {}

local player = Players.LocalPlayer
local UPDATE_SECONDS = 0.25
local GOLD = Color3.fromRGB(255, 205, 70)
local GREEN = Color3.fromRGB(120, 255, 140)
local RED = Color3.fromRGB(255, 90, 90)
local PANEL = Color3.fromRGB(20, 20, 26)

type Sign = { Gui: BillboardGui, Anchor: BasePart, Name: string, Top: TextLabel, Bottom: TextLabel }

local function makeSign(anchor: BasePart, name: string): Sign
	local gui = Instance.new("BillboardGui")
	gui.Name = `Safehouse_{name}`
	gui.Adornee = anchor
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(210, 46)
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = PANEL
	frame.BackgroundTransparency = 0.35
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local function line(y: number, font: Enum.Font): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, -8, 0, 20)
		l.Position = UDim2.fromOffset(4, y)
		l.Font = font
		l.TextSize = OnboardingConfig.MinTextSize
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Parent = frame
		return l
	end
	local top = line(3, Enum.Font.GothamBlack)
	local bottom = line(23, Enum.Font.GothamBold)
	gui.Parent = player:WaitForChild("PlayerGui")
	return { Gui = gui, Anchor = anchor, Name = name, Top = top, Bottom = bottom }
end

local function hasSpree(): boolean
	local unbanked = player:GetAttribute(PlayerAttributes.SpreeUnbanked)
	return type(unbanked) == "number" and unbanked > 0
end

function SafehouseMarkerController.init()
	-- Bank progress bar in its HUD slot under the spree pop (HudLayout, S2.7).
	local gui = Instance.new("ScreenGui")
	gui.Name = "SafehouseHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")
	local bar = Instance.new("Frame")
	bar.Name = "BankBar"
	UiRoot.place(bar, HudLayout.Slots.BankBar)
	bar.BackgroundColor3 = PANEL
	bar.BackgroundTransparency = 0.2
	bar.ClipsDescendants = true
	bar.Visible = false
	bar.Parent = UiRoot.mount(gui)
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = GREEN
	fill.BackgroundTransparency = 0.45
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = bar
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBlack
	text.TextSize = 16
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Parent = bar

	local function renderBar()
		local progress = player:GetAttribute(PlayerAttributes.BankProgress)
		local blocked = player:GetAttribute(PlayerAttributes.BankBlocked)
		local inside = player:GetAttribute(PlayerAttributes.InSafehouse) ~= nil
		bar.Visible = inside and type(progress) == "number"
		if not bar.Visible then
			return
		end
		local seconds = SpreeConfig.BankSeconds
		local done = math.clamp((progress :: number) / seconds, 0, 1)
		fill.Size = UDim2.fromScale(done, 1)
		if blocked == "Seen" then
			text.Text = "POLICE CAN SEE YOU. LOSE THEM!"
			text.TextColor3 = RED
		elseif blocked ~= nil then
			text.Text = "CAN'T BANK RIGHT NOW"
			text.TextColor3 = RED
		else
			text.Text = `BANKING… {math.max(0, math.ceil(seconds - (progress :: number)))}s`
			text.TextColor3 = Color3.new(1, 1, 1)
		end
	end
	for _, name in { PlayerAttributes.BankProgress, PlayerAttributes.BankBlocked, PlayerAttributes.InSafehouse } do
		player:GetAttributeChangedSignal(name):Connect(renderBar)
	end
	renderBar()

	local city = Workspace:WaitForChild("City", 30)
	local folder = city and city:WaitForChild("Safehouses", 30)
	if not folder then
		return
	end
	local signs: { Sign } = {}
	local function add(safehouse: Instance)
		local marker = safehouse:WaitForChild("Marker", 30)
		if marker and marker:IsA("BasePart") then
			local name = safehouse:GetAttribute("DisplayName")
			table.insert(signs, makeSign(marker, if type(name) == "string" then name else safehouse.Name))
		end
	end
	for _, safehouse in folder:GetChildren() do
		task.spawn(add, safehouse)
	end
	folder.ChildAdded:Connect(add)

	while true do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local spree = hasSpree()
		for _, sign in signs do
			local distance = if root and root:IsA("BasePart") then (root.Position - sign.Anchor.Position).Magnitude else math.huge
			local visible = distance < math.huge
				and ((spree and distance >= OnboardingConfig.MarkerHideDistance) or OnboardingRules.markerVisible(distance, OnboardingConfig))
			sign.Gui.Enabled = visible
			if visible then
				sign.Top.Text = `SAFEHOUSE · {OnboardingRules.formatDistance(distance)}`
				sign.Top.TextColor3 = if spree then GOLD else Color3.new(1, 1, 1)
				sign.Bottom.Text = if spree then "Bank your spree here" else sign.Name
			end
		end
		task.wait(UPDATE_SECONDS)
	end
end

return SafehouseMarkerController
