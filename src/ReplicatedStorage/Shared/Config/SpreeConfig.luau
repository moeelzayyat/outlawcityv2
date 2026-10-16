--!strict
-- Crime Spree tuning (D-001, architecture §2.2, STATS.md §Spree). Read-only at runtime. The first
-- public test decides the final numbers.
local SpreeConfig = table.freeze({
	MultiplierStart = 1.0, -- the first crime of a spree pays base × 1.0
	MultiplierStep = 0.5, -- each completed crime raises the multiplier for the next one
	MultiplierCap = 4.0,
	BankSeconds = 5, -- inside a safehouse with no police sight, continuously
	BankSecondsUpgraded = table.freeze({ 4, 3 }), -- safehouse upgrade levels 1 and 2 (S4.4)
	ReputationCap = 50, -- reputation at bank = peak stars × crimes, capped
	MaxUnbanked = 1_000_000, -- never more than one economy transaction (EconomyConfig.MaxTransaction)
	FirstSpreeDispatchDelay = 10, -- seconds; players with 0 completed sprees only (S2.8)
})

return SpreeConfig
