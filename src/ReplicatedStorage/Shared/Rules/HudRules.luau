--!strict
-- Pure HUD layout rules (S2.7): the UIScale for a screen and rectangle overlap. Numbers only.
-- Unit-tested in HudLayout.spec.
local HudRules = {}

export type Rect = { X: number, Y: number, W: number, H: number }

-- The HUD scale for a safe-area size: shrink (never grow) so the stack fits, not below minScale.
function HudRules.scaleFor(width: number, height: number, designWidth: number, designHeight: number, minScale: number): number
	if type(width) ~= "number" or type(height) ~= "number" or width ~= width or height ~= height or width <= 0 or height <= 0 then
		return 1
	end
	return math.clamp(math.min(width / designWidth, height / designHeight, 1), minScale, 1)
end

-- Do two rectangles share any area (touching edges don't count)?
function HudRules.overlaps(a: Rect, b: Rect): boolean
	return a.X < b.X + b.W and b.X < a.X + a.W and a.Y < b.Y + b.H and b.Y < a.Y + a.H
end

-- A centre-anchored slot as a screen rectangle (design pixels) on a screen `width` design px wide.
function HudRules.place(slot: Rect, width: number): Rect
	return { X = width / 2 + slot.X, Y = slot.Y, W = slot.W, H = slot.H }
end

return HudRules
