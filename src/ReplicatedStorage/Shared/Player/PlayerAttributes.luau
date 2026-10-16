--!strict
-- Names of the read-only gameplay attributes the server publishes on each Player.
-- Only the server writes them (client-set attributes never replicate); clients read them for UI.
local PlayerAttributes = table.freeze({
	Status = "Status", -- Types.PlayerStatus
	SpawnProtectedUntil = "SpawnProtectedUntil", -- server time (Workspace:GetServerTimeNow())
	WantedLevel = "WantedLevel", -- stars, 0..#WantedConfig.StarThresholds
	WantedHeat = "WantedHeat", -- heat, 0..WantedConfig.MaxHeat (1 decimal)
	WantedEvading = "WantedEvading", -- true while heat is decaying
	CriminalReputation = "CriminalReputation", -- earned by escapes (session only until persistence)
	CombatStatus = "CombatStatus", -- Types.CombatStatus
	CombatCooldownUntil = "CombatCooldownUntil", -- server time before which Peaceful is refused (0 = none)
	InSafeZone = "InSafeZone", -- set by SafeZoneService (4 Hz); absent means false
	Jailed = "Jailed", -- true while serving a jail sentence (JailService)
	JailReleaseAt = "JailReleaseAt", -- server time the sentence ends (0 when not jailed)
	Cash = "Cash", -- server-authoritative balance (EconomyService); absent until data has loaded
	CashStatus = "CashStatus", -- "Loading" | "Loaded" | "Unavailable"
	OwnedVehicles = "OwnedVehicles", -- comma-separated vehicle ids from the profile (display only)
	RobberyPhase = "RobberyPhase", -- "Holding" | "Escaping" | "PayoutPending" while a robbery is live or unpaid (else nil)
	RobberyHoldEndsAt = "RobberyHoldEndsAt", -- server time the holdout completes
	RobberyReward = "RobberyReward", -- the live crime's base cash (display only)
	CrimeName = "CrimeName", -- the live holdout crime's name, e.g. "ATM smash" (CrimeService, S2.3)
	ObservedAt = "ObservedAt", -- server time of the last character observation (CharacterValidationService); absent if none
	SpreeUnbanked = "SpreeUnbanked", -- unbanked spree cash (SpreeService); 0 when no spree is active
	SpreeMultiplier = "SpreeMultiplier", -- the multiplier the next crime pays (SpreeService)
	SpreeCrimes = "SpreeCrimes", -- crimes in the current spree (SpreeService)
	Reputation = "Reputation", -- persisted reputation, earned at bank (EconomyService, profile v4)
	BestSpree = "BestSpree", -- largest banked spree (EconomyService, profile v4)
	InSafehouse = "InSafehouse", -- id of the safehouse the player stands in (SafehouseService, S2.4); absent outside
	BankProgress = "BankProgress", -- seconds of bank progress (1 decimal) while inside one with an unbanked spree
	ObjectiveText = "ObjectiveText", -- today's objective (ObjectiveService, S2.9)
	ObjectiveProgress = "ObjectiveProgress",
	ObjectiveTarget = "ObjectiveTarget",
	ObjectiveReward = "ObjectiveReward",
	ObjectiveDone = "ObjectiveDone", -- true once today's reward is paid
	BankBlocked = "BankBlocked", -- "Seen" | "Observed" | "Jailed" while inside with a spree but unable to bank
})

return PlayerAttributes
