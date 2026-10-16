--!strict
-- Biggest Spree boards and the daily objective (S2.9). A TOP button (HudLayout.BoardButton)
-- opens a panel with Daily / Weekly / All-time tabs (rows pushed by OnLeaderboard) and today's
-- objective (Objective* attributes). Display only: the server records and pays everything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local LeaderboardConfig = require(Shared.Config.LeaderboardConfig)
local UiKit = require(script.Parent.UiKit)
local UiRoot = require(script.Parent.UiRoot)
local HudLayout = require(Shared.Config.HudLayout)

local LeaderboardController = {}

local player = Players.LocalPlayer
local TITLES = { Daily = "TODAY", Weekly = "THIS WEEK", AllTime = "ALL TIME" }
local GOLD = Color3.fromRGB(255, 205, 70)
local GREEN = Color3.fromRGB(120, 255, 140)

local function money(amount: number): string
	local text = tostring(math.floor(amount))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. formatted:gsub("^,", "")
end

function LeaderboardController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LeaderboardHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")
	local root = UiRoot.mount(gui)

	local slot = HudLayout.BoardButton
	local open = UiKit.button(root, "BoardButton", "TOP", UDim2.fromOffset(slot.W, slot.H), UDim2.fromOffset(slot.X, slot.Y), Color3.fromRGB(60, 60, 80))

	local panel = Instance.new("Frame")
	panel.Name = "Board"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(320, 300)
	panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = root
	UiKit.corner(panel, 14)
	local title = UiKit.text(panel, "Title", "BIGGEST SPREE", UDim2.new(1, -60, 0, 30), UDim2.fromOffset(12, 8), 20, GOLD)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local close = UiKit.button(panel, "Close", "X", UDim2.fromOffset(44, 44), UDim2.new(1, -50, 0, 4), Color3.fromRGB(70, 70, 80))

	local rows: { [string]: { any } } = {}
	local current = "Daily"
	local tabs: { [string]: TextButton } = {}
	for index, board in LeaderboardConfig.Boards do
		tabs[board] = UiKit.button(panel, board, TITLES[board] or board, UDim2.fromOffset(96, 30), UDim2.fromOffset(12 + (index - 1) * 100, 44), Color3.fromRGB(50, 50, 64))
	end
	local lines: { TextLabel } = {}
	for i = 1, LeaderboardConfig.Rows do
		local line = UiKit.text(panel, `Row{i}`, "", UDim2.new(1, -24, 0, 17), UDim2.fromOffset(12, 80 + (i - 1) * 17), 14)
		line.TextXAlignment = Enum.TextXAlignment.Left
		lines[i] = line
	end
	local objective = UiKit.text(panel, "Objective", "", UDim2.new(1, -24, 0, 36), UDim2.new(0, 12, 1, -42), 14)
	objective.TextXAlignment = Enum.TextXAlignment.Left
	objective.TextWrapped = true

	local function render()
		for board, tab in tabs do
			tab.BackgroundColor3 = if board == current then Color3.fromRGB(230, 160, 30) else Color3.fromRGB(50, 50, 64)
		end
		local list = rows[current] or {}
		for i, line in lines do
			local row = list[i]
			line.Text = if type(row) == "table" and type(row.Amount) == "number" then `{row.Rank}. {tostring(row.Name)}   {money(row.Amount)}` elseif i == 1 then "No sprees banked yet. Be the first!" else ""
			line.TextColor3 = if type(row) == "table" and row.UserId == player.UserId then GREEN else Color3.new(1, 1, 1)
		end
		local text = player:GetAttribute(PlayerAttributes.ObjectiveText)
		local progress = player:GetAttribute(PlayerAttributes.ObjectiveProgress)
		local target = player:GetAttribute(PlayerAttributes.ObjectiveTarget)
		local reward = player:GetAttribute(PlayerAttributes.ObjectiveReward)
		if type(text) ~= "string" then
			objective.Text = ""
		elseif player:GetAttribute(PlayerAttributes.ObjectiveDone) == true then
			objective.Text = `Today: {text}  DONE`
			objective.TextColor3 = GREEN
		else
			objective.Text = `Today: {text}  {tonumber(progress) or 0}/{tonumber(target) or 0}  ({money(tonumber(reward) or 0)})`
			objective.TextColor3 = GOLD
		end
	end
	for board, tab in tabs do
		tab.Activated:Connect(function()
			current = board
			render()
		end)
	end
	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		render()
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	Remotes.getEvent("OnLeaderboard").OnClientEvent:Connect(function(board: any, list: any)
		if type(board) == "string" and type(list) == "table" then
			rows[board] = list
			if panel.Visible then
				render()
			end
		end
	end)
	for _, name in { PlayerAttributes.ObjectiveText, PlayerAttributes.ObjectiveProgress, PlayerAttributes.ObjectiveDone } do
		player:GetAttributeChangedSignal(name):Connect(function()
			open.Text = if player:GetAttribute(PlayerAttributes.ObjectiveDone) == true then "TOP ✓" else "TOP"
			if panel.Visible then
				render()
			end
		end)
	end
end

return LeaderboardController
