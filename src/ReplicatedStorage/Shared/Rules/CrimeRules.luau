--!strict
-- Pure crime-definition rules (S2.3). Holdouts themselves run on RobberyRules (same state
-- machine, per-crime numbers); this module validates the catalogue at boot and decides the
-- alarm. Unit-tested in ServerStorage.Tests.CrimeRules.spec.
local CrimeRules = {}

local function positive(n: any): boolean
	return type(n) == "number" and n == n and n > 0 and n ~= math.huge
end

local function nonNegative(n: any): boolean
	return type(n) == "number" and n == n and n >= 0 and n ~= math.huge
end

-- Checks every crime definition. Returns a list of problems (empty when valid).
function CrimeRules.validate(crimes: { [string]: any }, wantedCrimes: { [string]: any }): { string }
	local problems = {}
	local function bad(id: string, why: string)
		table.insert(problems, `{id}: {why}`)
	end
	for id, c in crimes do
		if type(id) ~= "string" or #id == 0 then
			bad(tostring(id), "id must be a non-empty string")
			continue
		end
		if type(c.Name) ~= "string" or #c.Name == 0 then
			bad(id, "Name")
		end
		if not positive(c.Reward) or c.Reward % 1 ~= 0 then
			bad(id, "Reward must be a whole positive number")
		end
		if c.Holdout and not positive(c.HoldSeconds) then
			bad(id, "HoldSeconds must be positive for a holdout")
		end
		if not nonNegative(c.AlarmChance) or c.AlarmChance > 1 then
			bad(id, "AlarmChance must be within 0..1")
		end
		if not positive(c.CooldownSeconds) then
			bad(id, "CooldownSeconds must be positive")
		end
		if c.FailedCooldownSeconds ~= nil and not positive(c.FailedCooldownSeconds) then
			bad(id, "FailedCooldownSeconds must be positive or nil")
		end
		if not positive(c.PromptDistance) or not nonNegative(c.DistanceSlack) then
			bad(id, "prompt distances")
		end
		if wantedCrimes[c.WantedCrime] == nil then
			bad(id, `unknown WantedCrime {tostring(c.WantedCrime)}`)
		end
		if c.Holdout and wantedCrimes[c.InProgressCrime] == nil then
			bad(id, `unknown InProgressCrime {tostring(c.InProgressCrime)}`)
		end
	end
	return problems
end

-- Does the alarm trip? `roll` is a uniform number in [0, 1) from the caller's Random.
function CrimeRules.alarmTrips(chance: number, roll: number): boolean
	return roll < chance
end

return CrimeRules
