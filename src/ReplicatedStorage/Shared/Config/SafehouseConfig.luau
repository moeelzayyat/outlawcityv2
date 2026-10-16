--!strict
-- Safehouse tuning (S2.4, architecture §2.2 / §10, STATS.md §Safehouses). The bank time itself is
-- SpreeConfig.BankSeconds (upgrades in S4.4). Read-only at runtime.
local SafehouseConfig = table.freeze({
	TickInterval = 0.25, -- seconds between zone and bank checks for every player
	ExitMargin = 2, -- studs beyond a zone's edge before a player counts as having left
	StarCooldownSeconds = 10, -- after a bank, stars fall to 0 over this long
})

return SafehouseConfig
