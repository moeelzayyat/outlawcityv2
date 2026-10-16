--!strict
-- Pure funnel bookkeeping for AnalyticsService (R1.7, docs/EVENTS.md). "First…" milestones are
-- logged once per player per server session; Joined → FirstCar → FirstCrime → FirstBank are the
-- onboarding funnel steps; everything else is a repeatable custom event.
-- Unit-tested in ServerStorage.Tests.FunnelRules.spec.
local FunnelRules = {}

FunnelRules.Steps = table.freeze({ Joined = 1, FirstCar = 2, FirstCrime = 3, FirstBank = 4 })
FunnelRules.Once = table.freeze({ Joined = true, FirstCar = true, FirstCrime = true, FirstBank = true, FirstBust = true })

export type State = { Seen: { [string]: boolean } }

function FunnelRules.new(): State
	return { Seen = {} }
end

-- Returns (log it?, onboarding step or nil for a custom event).
function FunnelRules.mark(state: State, name: string): (boolean, number?)
	if FunnelRules.Once[name] then
		if state.Seen[name] then
			return false, nil
		end
		state.Seen[name] = true
	end
	return true, FunnelRules.Steps[name]
end

return FunnelRules
