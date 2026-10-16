--!strict
-- Pure validation of server-observed character samples (audit F1, D-004). Same shape as
-- VehicleValidationRules: it only sees positions/velocities the server reads from the
-- replicated HumanoidRootPart, never anything the client claims. Vertical motion is ignored
-- (falls, jumps). Unit-tested in ServerStorage.Tests.CharacterValidation.spec.
local CharacterValidationRules = {}

export type Sample = { Time: number, Position: Vector3, Velocity: Vector3 }
export type State = { Last: Sample?, OverspeedTime: number, GraceUntil: number }
export type Observation = { Kind: string, Detail: string }

type Config = {
	MaxSpeed: number,
	SustainSeconds: number,
	DisplacementFactor: number,
	DisplacementSlack: number,
}

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function isFiniteVector(v: any): boolean
	return typeof(v) == "Vector3" and finite(v.X) and finite(v.Y) and finite(v.Z)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function CharacterValidationRules.new(now: number, graceSeconds: number): State
	return { Last = nil, OverspeedTime = 0, GraceUntil = now + graceSeconds }
end

-- Authorized server move (spawn, seat, jail cell): skip judgement for a while and start a
-- fresh baseline afterwards.
function CharacterValidationRules.grant(state: State, now: number, seconds: number)
	state.GraceUntil = math.max(state.GraceUntil, now + seconds)
	state.Last = nil
	state.OverspeedTime = 0
end

function CharacterValidationRules.observe(state: State, sample: Sample, config: Config): { Observation }
	local observations: { Observation } = {}
	if not isFiniteVector(sample.Position) or not isFiniteVector(sample.Velocity) or not finite(sample.Time) then
		table.insert(observations, { Kind = "InvalidState", Detail = "non-finite position or velocity" })
		return observations -- keep the last good baseline
	end
	if sample.Time < state.GraceUntil then
		state.Last = sample
		state.OverspeedTime = 0
		return observations
	end
	local last = state.Last
	local dt = if last then sample.Time - last.Time else 0
	if last and dt > 0 then
		local distance = flat(sample.Position - last.Position).Magnitude
		local allowed = config.MaxSpeed * dt * config.DisplacementFactor + config.DisplacementSlack
		if distance > allowed then
			table.insert(observations, {
				Kind = "Teleport",
				Detail = string.format("moved %.0f studs in %.2f s (allowed %.0f)", distance, dt, allowed),
			})
		end
		local speed = flat(sample.Velocity).Magnitude
		if speed > config.MaxSpeed then
			state.OverspeedTime += dt
			if state.OverspeedTime >= config.SustainSeconds then
				table.insert(observations, {
					Kind = "SustainedOverspeed",
					Detail = string.format("%.0f studs/s for %.1f s (limit %.0f)", speed, state.OverspeedTime, config.MaxSpeed),
				})
				state.OverspeedTime = 0
			end
		else
			state.OverspeedTime = 0
		end
	end
	state.Last = sample
	return observations
end

-- Payout gate (R1.4): was this player observed within the last `window` seconds?
function CharacterValidationRules.isObserved(observedAt: any, now: number, window: number): boolean
	return type(observedAt) == "number" and finite(observedAt) and now - observedAt < window
end

return CharacterValidationRules
