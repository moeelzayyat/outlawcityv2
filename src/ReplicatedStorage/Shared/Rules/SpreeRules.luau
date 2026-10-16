--!strict
-- Pure Crime Spree rules (S2.1, D-001, architecture §2.2). A spree is cash the player hasn't
-- banked yet: it starts with the first crime, each crime adds base × multiplier and raises the
-- multiplier, banking at a safehouse turns it into cash, a bust loses it. Escaping keeps it.
-- No clocks, no Instances: callers pass time and facts. Unit-tested in SpreeRules.spec.
local SpreeRules = {}

export type Spree = {
	Id: string?,
	Active: boolean,
	Unbanked: number,
	Multiplier: number,
	Crimes: number,
	PeakStars: number,
	StartedAt: number,
	BankProgress: number, -- seconds spent continuously meeting the bank conditions
}
export type BankFacts = { InSafehouse: boolean, Seen: boolean, Observed: boolean, Jailed: boolean }
export type BankResult = {
	SpreeId: string,
	Amount: number,
	PeakStars: number,
	Crimes: number,
	Duration: number,
	Reputation: number,
}

type Config = {
	MultiplierStart: number,
	MultiplierStep: number,
	MultiplierCap: number,
	ReputationCap: number,
	MaxUnbanked: number,
}

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function SpreeRules.new(config: Config): Spree
	return {
		Id = nil,
		Active = false,
		Unbanked = 0,
		Multiplier = config.MultiplierStart,
		Crimes = 0,
		PeakStars = 0,
		StartedAt = 0,
		BankProgress = 0,
	}
end

local function reset(spree: Spree, config: Config)
	spree.Id = nil
	spree.Active = false
	spree.Unbanked = 0
	spree.Multiplier = config.MultiplierStart
	spree.Crimes = 0
	spree.PeakStars = 0
	spree.StartedAt = 0
	spree.BankProgress = 0
end

-- A completed crime. Starts a spree if none is active (with `spreeId`), adds base × multiplier
-- (rounded down, capped at MaxUnbanked), then raises the multiplier. Returns (ok, err?, added).
function SpreeRules.addCrime(spree: Spree, spreeId: string, baseCash: any, stars: any, now: number, config: Config): (boolean, string?, number)
	if not finite(baseCash) or baseCash <= 0 or baseCash % 1 ~= 0 then
		return false, "InvalidAmount", 0
	end
	if not finite(stars) or stars < 0 then
		return false, "InvalidStars", 0
	end
	if not spree.Active then
		if type(spreeId) ~= "string" or #spreeId == 0 then
			return false, "InvalidSpreeId", 0
		end
		reset(spree, config)
		spree.Id = spreeId
		spree.Active = true
		spree.StartedAt = now
	end
	local added = math.floor(baseCash * spree.Multiplier)
	local before = spree.Unbanked
	spree.Unbanked = math.min(config.MaxUnbanked, before + added)
	spree.Crimes += 1
	spree.Multiplier = math.min(config.MultiplierCap, spree.Multiplier + config.MultiplierStep)
	spree.PeakStars = math.max(spree.PeakStars, stars)
	spree.BankProgress = 0
	return true, nil, spree.Unbanked - before
end

-- Stars rose during the spree (police escalation): remembered for reputation and the board.
function SpreeRules.noteStars(spree: Spree, stars: any)
	if spree.Active and finite(stars) and stars > spree.PeakStars then
		spree.PeakStars = stars
	end
end

function SpreeRules.canBank(spree: Spree): boolean
	return spree.Active and spree.Unbanked > 0
end

-- Advances banking by dt while every condition holds; any break resets it. Returns true once the
-- player has met the conditions continuously for bankSeconds.
function SpreeRules.stepBank(spree: Spree, dt: any, facts: BankFacts, bankSeconds: number): boolean
	local holds = SpreeRules.canBank(spree)
		and finite(dt)
		and dt > 0
		and facts.InSafehouse
		and not facts.Seen
		and not facts.Observed
		and not facts.Jailed
	if not holds then
		spree.BankProgress = 0
		return false
	end
	spree.BankProgress += dt
	return spree.BankProgress >= bankSeconds
end

function SpreeRules.reputationFor(peakStars: number, crimes: number, cap: number): number
	if not finite(peakStars) or not finite(crimes) then
		return 0
	end
	return math.clamp(math.floor(peakStars) * math.floor(crimes), 0, cap)
end

-- Banks the spree: returns what to pay (one grant per SpreeId) and ends it. nil if nothing to bank.
function SpreeRules.bank(spree: Spree, now: number, config: Config): BankResult?
	if not SpreeRules.canBank(spree) then
		return nil
	end
	local result: BankResult = {
		SpreeId = spree.Id :: string,
		Amount = spree.Unbanked,
		PeakStars = spree.PeakStars,
		Crimes = spree.Crimes,
		Duration = math.max(0, now - spree.StartedAt),
		Reputation = SpreeRules.reputationFor(spree.PeakStars, spree.Crimes, config.ReputationCap),
	}
	reset(spree, config)
	return result
end

-- Busted: the unbanked cash is lost (banked cash is never touched). Returns (spreeId?, lost).
function SpreeRules.bust(spree: Spree, config: Config): (string?, number)
	if not spree.Active then
		return nil, 0
	end
	local id, lost = spree.Id, spree.Unbanked
	reset(spree, config)
	return id, lost
end

-- Escaped the police: the spree stays alive at its multiplier; only banking progress restarts.
function SpreeRules.onEscaped(spree: Spree): boolean
	spree.BankProgress = 0
	return spree.Active
end

return SpreeRules
