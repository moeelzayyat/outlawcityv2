--!strict
-- Pure daily-objective rules (S2.9): today's objective, the profile key it saves under, how an
-- event advances it, and pruning old days. Plain tables only. Unit-tested in Objective.spec.
local ObjectiveRules = {}

export type Objective = { Id: string, Text: string, Kind: string, Target: number, Reward: number }
export type Event = { Kind: "Banked" | "Crime", Amount: number? }

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- Today's objective: the list rotates by UTC day index.
function ObjectiveRules.forDay(list: { Objective }, day: number): Objective?
	if #list == 0 or not finite(day) then
		return nil
	end
	return list[math.floor(day) % #list + 1]
end

-- Profile key for an objective's progress on a day ("20377:Bank3").
function ObjectiveRules.key(day: number, id: string): string
	return `{math.floor(day)}:{id}`
end

-- Ledger transaction id for the day's reward: one payment per objective per day, ever.
function ObjectiveRules.txId(day: number, id: string): string
	return `objective:{math.floor(day)}:{id}`
end

-- Progress after an event, capped at the target.
function ObjectiveRules.advance(objective: Objective, progress: number, event: Event): number
	local current = if finite(progress) and progress >= 0 then math.floor(progress) else 0
	local nextValue = current
	if objective.Kind == "Banks" and event.Kind == "Banked" then
		nextValue = current + 1
	elseif objective.Kind == "Crimes" and event.Kind == "Crime" then
		nextValue = current + 1
	elseif objective.Kind == "BankAmount" and event.Kind == "Banked" and finite(event.Amount) then
		nextValue = math.max(current, math.floor(event.Amount :: number))
	end
	return math.min(nextValue, objective.Target)
end

function ObjectiveRules.complete(objective: Objective, progress: number): boolean
	return finite(progress) and progress >= objective.Target
end

-- The saved objectives map with only `day`'s entries kept (older days are dropped).
function ObjectiveRules.prune(saved: { [string]: number }, day: number): { [string]: number }
	local prefix = `{math.floor(day)}:`
	local kept: { [string]: number } = {}
	for key, value in saved do
		if string.sub(key, 1, #prefix) == prefix then
			kept[key] = value
		end
	end
	return kept
end

return ObjectiveRules
