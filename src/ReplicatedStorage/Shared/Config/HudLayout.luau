--!strict
-- HUD layout (S2.7): every HUD element's slot in design pixels, top-centre anchored (X is the
-- left edge's offset from the screen centre). Row 1 is status (safe-zone badge, stars, cash);
-- row 2 the buttons; below them one stacked slot per centred panel, so nothing that can show at
-- the same time overlaps. UiRoot scales the whole HUD by HudRules.scaleFor so the stack fits short
-- phone screens. Checked by HudLayout.spec at iPhone 7 and iPhone 13 Pro Max landscape.
export type Slot = { X: number, Y: number, W: number, H: number }

local HudLayout = {}

HudLayout.Slots = table.freeze({
	-- Row 1: status.
	SafeZoneBadge = table.freeze({ X = -164, Y = 8, W = 108, H = 26 }) :: Slot,
	Stars = table.freeze({ X = -51, Y = 4, W = 102, H = 34 }) :: Slot, -- 3 stars x 34
	Cash = table.freeze({ X = 56, Y = 8, W = 108, H = 26 }) :: Slot,
	-- Row 2: buttons (the Combat button is hidden, R1.8, but keeps its slot).
	CombatButton = table.freeze({ X = -164, Y = 42, W = 160, H = 44 }) :: Slot,
	SpawnButton = table.freeze({ X = 4, Y = 42, W = 160, H = 44 }) :: Slot,
	-- Centred stack.
	Counter = table.freeze({ X = -150, Y = 92, W = 300, H = 36 }) :: Slot, -- spree counter
	Banner = table.freeze({ X = -160, Y = 132, W = 320, H = 30 }) :: Slot, -- BUSTED! / EVADING
	Pop = table.freeze({ X = -150, Y = 166, W = 300, H = 26 }) :: Slot, -- +$X UNBANKED
	BankBar = table.freeze({ X = -150, Y = 196, W = 300, H = 26 }) :: Slot,
	Panel = table.freeze({ X = -150, Y = 226, W = 300, H = 76 }) :: Slot, -- robbery objective / jail
	Toast = table.freeze({ X = -170, Y = 306, W = 340, H = 36 }) :: Slot,
})

-- Left column (not centred): X is from the left screen edge.
HudLayout.Tip = table.freeze({ X = 12, Y = 92, W = 160, H = 96 }) :: Slot
HudLayout.BoardButton = table.freeze({ X = 12, Y = 42, W = 90, H = 40 }) :: Slot -- leaderboards (S2.9)

HudLayout.DesignHeight = 346 -- bottom of the stack (Toast) + 4
HudLayout.DesignWidth = 560 -- narrowest screen the stack fits unscaled
HudLayout.MinScale = 0.75

return table.freeze(HudLayout)
