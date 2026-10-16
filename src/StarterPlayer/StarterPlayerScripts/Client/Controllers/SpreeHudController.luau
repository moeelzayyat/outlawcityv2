--!strict
-- Crime Spree HUD (S2.2): the unbanked counter (the signature visual, ART_BIBLE: large, red at
-- 3 stars), "+$X UNBANKED" pops, and the result card (BANKED / BUSTED) with an Again button.
-- Display only: the server owns the spree and sends OnSpreeNotice.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)

local UiRoot = require(script.Parent.UiRoot)
local HudLayout = require(game:GetService("ReplicatedStorage").Shared.Config.HudLayout)

local SpreeHudController = {}

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 205, 70)
local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(120, 255, 140)
local PANEL = Color3.fromRGB(20, 20, 26)

local function money(amount: number): string
	local text = tostring(math.floor(amount))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. formatted:gsub("^,", "")
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = font
	l.TextSize = textSize
	l.Parent = parent
	return l
end

function SpreeHudController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpreeHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Unbanked counter: the slot under the top status row (y 96), free whenever a spree exists.
	local counter = Instance.new("Frame")
	counter.Name = "Counter"
	UiRoot.place(counter, HudLayout.Slots.Counter)
	counter.BackgroundColor3 = PANEL
	counter.BackgroundTransparency = 0.2
	counter.Visible = false
	local root = UiRoot.mount(gui)
	counter.Parent = root
	corner(counter, 10)
	local amount = label(counter, "Amount", UDim2.new(0.62, 0, 1, 0), UDim2.fromOffset(8, 0), 26, Enum.Font.GothamBlack)
	amount.TextXAlignment = Enum.TextXAlignment.Left
	local info = label(counter, "Info", UDim2.new(0.38, -8, 1, 0), UDim2.new(0.62, 0, 0, 0), 14, Enum.Font.GothamBold)
	info.TextXAlignment = Enum.TextXAlignment.Right

	local function render()
		local unbanked = player:GetAttribute(PlayerAttributes.SpreeUnbanked)
		local multiplier = player:GetAttribute(PlayerAttributes.SpreeMultiplier)
		local stars = player:GetAttribute(PlayerAttributes.WantedLevel)
		local active = type(unbanked) == "number" and unbanked > 0
		counter.Visible = active
		if not active then
			return
		end
		amount.Text = money(unbanked :: number)
		amount.TextColor3 = if type(stars) == "number" and stars >= 3 then RED else GOLD
		info.Text = string.format("UNBANKED  x%.1f", if type(multiplier) == "number" then multiplier else 1)
	end
	for _, name in { PlayerAttributes.SpreeUnbanked, PlayerAttributes.SpreeMultiplier, PlayerAttributes.WantedLevel } do
		player:GetAttributeChangedSignal(name):Connect(render)
	end
	render()

	-- "+$800 UNBANKED" pop under the counter.
	local pop = label(root, "Pop", UDim2.fromOffset(300, 30), UDim2.new(0.5, -150, 0, 136), 22, Enum.Font.GothamBlack)
	UiRoot.place(pop, HudLayout.Slots.Pop)
	pop.TextColor3 = GREEN
	pop.Visible = false
	local popToken = 0
	local function showPop(text: string, color: Color3)
		popToken += 1
		local token = popToken
		pop.Text = text
		pop.TextColor3 = color
		pop.Visible = true
		task.delay(2.5, function()
			if popToken == token then
				pop.Visible = false
			end
		end)
	end

	-- Result card: centre of the screen, closed by Again.
	local card = Instance.new("Frame")
	card.Name = "ResultCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(320, 200)
	card.BackgroundColor3 = PANEL
	card.BackgroundTransparency = 0.05
	card.Visible = false
	card.Parent = root
	corner(card, 14)
	local heading = label(card, "Heading", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 12), 24, Enum.Font.GothamBlack)
	local big = label(card, "Big", UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 46), 38, Enum.Font.GothamBlack)
	local line1 = label(card, "Line1", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 94), 16, Enum.Font.GothamBold)
	local line2 = label(card, "Line2", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 116), 16, Enum.Font.Gotham)
	local again = Instance.new("TextButton")
	again.Name = "Again"
	again.AnchorPoint = Vector2.new(0.5, 1)
	again.Position = UDim2.new(0.5, 0, 1, -12)
	again.Size = UDim2.fromOffset(180, 44)
	again.BackgroundColor3 = Color3.fromRGB(230, 160, 30)
	again.TextColor3 = Color3.new(0, 0, 0)
	again.Font = Enum.Font.GothamBlack
	again.TextSize = 22
	again.Text = "AGAIN"
	again.Parent = card
	corner(again, 10)
	again.Activated:Connect(function()
		card.Visible = false
	end)

	local function showCard(title: string, titleColor: Color3, value: string, valueColor: Color3, a: string, b: string)
		heading.Text = title
		heading.TextColor3 = titleColor
		big.Text = value
		big.TextColor3 = valueColor
		line1.Text = a
		line2.Text = b
		card.Visible = true
	end

	Remotes.getEvent("OnSpreeNotice").OnClientEvent:Connect(function(kind: string, payload: any)
		payload = if type(payload) == "table" then payload else {}
		if kind == "Added" and type(payload.Amount) == "number" then
			showPop(`+{money(payload.Amount)} UNBANKED`, GREEN)
		elseif kind == "Banked" and type(payload.Amount) == "number" then
			local best = player:GetAttribute(PlayerAttributes.BestSpree)
			local stars = if type(payload.PeakStars) == "number" then string.rep("★", payload.PeakStars) else ""
			showCard(
				"BANKED",
				GREEN,
				money(payload.Amount),
				GOLD,
				`{payload.Crimes or 0} crimes  {stars}  {math.floor(tonumber(payload.Duration) or 0)}s`,
				if payload.Pending then "Saving… it will be added shortly" elseif type(best) == "number" then `Best spree: {money(best)}   +{payload.Reputation or 0} rep` else ""
			)
		elseif kind == "Lost" and type(payload.Amount) == "number" then
			showCard("BUSTED", RED, `-{money(payload.Amount)}`, RED, "Unbanked cash lost", "Your banked cash is safe")
		elseif kind == "BankFailed" then
			showPop("Couldn't bank right now. Try again.", RED)
		end
	end)
end

return SpreeHudController
