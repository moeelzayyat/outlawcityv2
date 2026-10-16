-- HUD layout (S2.7): no two HUD slots overlap, cash sits in row 1, and the scaled stack fits the
-- safe area of iPhone 7 and iPhone 13 Pro Max in landscape. Safe areas assume a 36 px top bar
-- inset; Device Simulator screenshots are the real check (Device Simulator ≠ a real phone).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HudLayout = require(ReplicatedStorage.Shared.Config.HudLayout)
local HudRules = require(ReplicatedStorage.Shared.Rules.HudRules)
local Assert = require(script.Parent.Assert)

local PHONES = {
	{ Name = "iPhone 7", W = 667, H = 375 - 36 },
	{ Name = "iPhone 13 Pro Max", W = 926, H = 428 - 36 },
}

local function scaleFor(phone): number
	return HudRules.scaleFor(phone.W, phone.H, HudLayout.DesignWidth, HudLayout.DesignHeight, HudLayout.MinScale)
end

return {
	["no two HUD slots overlap, at either phone size, tip included"] = function()
		for _, phone in PHONES do
			local width = phone.W / scaleFor(phone) -- design pixels across the screen
			local rects = {}
			for name, slot in HudLayout.Slots do
				table.insert(rects, { Name = name, Rect = HudRules.place(slot, width) })
			end
			table.insert(rects, { Name = "Tip", Rect = HudLayout.Tip })
			table.insert(rects, { Name = "BoardButton", Rect = HudLayout.BoardButton })
			for i = 1, #rects do
				for j = i + 1, #rects do
					Assert.truthy(not HudRules.overlaps(rects[i].Rect, rects[j].Rect), `{phone.Name}: {rects[i].Name} overlaps {rects[j].Name}`)
				end
			end
			for _, r in rects do
				Assert.truthy(r.Rect.X >= 0 and r.Rect.X + r.Rect.W <= width, `{phone.Name}: {r.Name} inside the screen width`)
			end
		end
	end,
	["cash, stars and the safe-zone badge share row 1"] = function()
		local s = HudLayout.Slots
		for _, name in { "Cash", "Stars", "SafeZoneBadge" } do
			Assert.truthy(s[name].Y < s.CombatButton.Y and s[name].Y + s[name].H <= s.CombatButton.Y, `{name} in row 1`)
		end
	end,
	["the scaled stack fits the safe area of both phones"] = function()
		for _, phone in PHONES do
			local scale = scaleFor(phone)
			Assert.truthy(HudLayout.DesignHeight * scale <= phone.H + 0.5, `{phone.Name}: {HudLayout.DesignHeight * scale} px > {phone.H}`)
			Assert.truthy(scale >= 0.9, `{phone.Name}: scale {scale} keeps text readable`)
		end
		local bottom = 0
		for _, slot in HudLayout.Slots do
			bottom = math.max(bottom, slot.Y + slot.H)
		end
		Assert.truthy(bottom <= HudLayout.DesignHeight, "DesignHeight covers every slot")
	end,
	["scale shrinks only, never below the floor; bad sizes leave it at 1"] = function()
		Assert.equal(HudRules.scaleFor(1920, 1080, 560, 346, 0.75), 1)
		Assert.near(HudRules.scaleFor(800, 311.4, 560, 346, 0.75), 0.9, 1e-9)
		Assert.equal(HudRules.scaleFor(300, 100, 560, 346, 0.75), 0.75)
		Assert.equal(HudRules.scaleFor(0 / 0, 400, 560, 346, 0.75), 1)
		Assert.equal(HudRules.overlaps({ X = 0, Y = 0, W = 10, H = 10 }, { X = 10, Y = 0, W = 5, H = 5 }), false, "touching edges")
		Assert.equal(HudRules.overlaps({ X = 0, Y = 0, W = 10, H = 10 }, { X = 9, Y = 9, W = 5, H = 5 }), true)
	end,
}
