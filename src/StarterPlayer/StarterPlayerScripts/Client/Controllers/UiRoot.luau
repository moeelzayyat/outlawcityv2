--!strict
-- HUD scaling root (S2.7, architecture: UiRoot + UIScale). mount(gui) adds a transparent "Root"
-- frame with a UIScale to a ScreenGui; HUD elements parent to it and keep their design-pixel
-- slots (HudLayout). The frame is sized 1/scale of the screen, so scaled children still centre
-- and anchor correctly. The scale follows the ScreenGui's safe-area size (HudRules.scaleFor).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Config.HudLayout)
local HudRules = require(ReplicatedStorage.Shared.Rules.HudRules)

local UiRoot = {}

function UiRoot.scaleOf(gui: ScreenGui): number
	local size = gui.AbsoluteSize
	return HudRules.scaleFor(size.X, size.Y, HudLayout.DesignWidth, HudLayout.DesignHeight, HudLayout.MinScale)
end

-- Places a GuiObject in a centre-anchored HudLayout slot.
function UiRoot.place(object: GuiObject, slot: HudLayout.Slot)
	object.AnchorPoint = Vector2.new(0, 0)
	object.Position = UDim2.new(0.5, slot.X, 0, slot.Y)
	object.Size = UDim2.fromOffset(slot.W, slot.H)
end

function UiRoot.mount(gui: ScreenGui): Frame
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Active = false
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function update()
		local s = UiRoot.scaleOf(gui)
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
	root.Parent = gui
	return root
end

return UiRoot
