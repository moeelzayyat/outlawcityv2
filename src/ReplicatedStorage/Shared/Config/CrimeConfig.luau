--!strict
-- Crime definitions (S2.3, architecture §2.3 / §10, STATS.md §Crimes). Holdout crimes run on the
-- RobberyRules engine with their own numbers; CityLayout places their sites. Reward is the base
-- cash a completed crime adds to the spree (× multiplier). AlarmChance is the chance the crime
-- raises stars at all (a silent ATM half the time). Read-only; the public test tunes it.
local CrimeConfig = {}

export type Crime = {
	Name: string,
	Verb: string, -- prompt action text
	Holdout: boolean, -- false: completes on the spot (car theft)
	HoldSeconds: number,
	Reward: number,
	WantedCrime: string, -- WantedConfig crime reported when the alarm trips
	InProgressCrime: string, -- re-reported each second while holding (no heat, no decay)
	AlarmChance: number,
	CooldownSeconds: number, -- per site, from the start
	FailedCooldownSeconds: number?, -- shorter, after a failed attempt
	PromptDistance: number,
	DistanceSlack: number,
	MaxEscapeSeconds: number, -- engine field; sprees end the session at holdout end
	PoliceDispatchAtHoldEnd: boolean,
}

CrimeConfig.Crimes = table.freeze({
	StoreRobbery = table.freeze({
		Name = "Store robbery",
		Verb = "Rob store",
		Holdout = true,
		HoldSeconds = 15,
		Reward = 2000,
		WantedCrime = "StoreRobbery",
		InProgressCrime = "RobberyInProgress",
		AlarmChance = 1,
		CooldownSeconds = 120,
		FailedCooldownSeconds = 60,
		PromptDistance = 10,
		DistanceSlack = 4,
		MaxEscapeSeconds = 300,
		PoliceDispatchAtHoldEnd = true,
	}),
	AtmSmash = table.freeze({
		Name = "ATM smash",
		Verb = "Smash ATM",
		Holdout = true,
		HoldSeconds = 6,
		Reward = 800,
		WantedCrime = "AtmSmash",
		InProgressCrime = "RobberyInProgress",
		AlarmChance = 0.5,
		CooldownSeconds = 90,
		FailedCooldownSeconds = 45,
		PromptDistance = 6,
		DistanceSlack = 4,
		MaxEscapeSeconds = 300,
		PoliceDispatchAtHoldEnd = true,
	}),
	GasStation = table.freeze({
		Name = "Gas station robbery",
		Verb = "Rob till",
		Holdout = true,
		HoldSeconds = 12,
		Reward = 1500,
		WantedCrime = "GasStationRobbery",
		InProgressCrime = "RobberyInProgress",
		AlarmChance = 1,
		CooldownSeconds = 150,
		FailedCooldownSeconds = 75,
		PromptDistance = 8,
		DistanceSlack = 4,
		MaxEscapeSeconds = 300,
		PoliceDispatchAtHoldEnd = true,
	}),
	CarTheft = table.freeze({
		Name = "Car theft",
		Verb = "Steal car",
		Holdout = false,
		HoldSeconds = 0,
		Reward = 500,
		WantedCrime = "CarTheft",
		InProgressCrime = "RobberyInProgress",
		AlarmChance = 0.3,
		CooldownSeconds = 120, -- the parked car respawns this long after it was taken
		FailedCooldownSeconds = nil,
		PromptDistance = 10,
		DistanceSlack = 4,
		MaxEscapeSeconds = 300,
		PoliceDispatchAtHoldEnd = false,
	}),
}) :: { [string]: Crime }

CrimeConfig.TickInterval = 0.25
CrimeConfig.StealHoldSeconds = 1.5 -- prompt hold on a parked car (client prompt only)

return table.freeze(CrimeConfig)
