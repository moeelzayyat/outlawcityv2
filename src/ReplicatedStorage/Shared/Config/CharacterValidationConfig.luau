--!strict
-- Tuning for server-side observation of player characters on foot (R1.3, D-004, STATS.md).
-- Observations are logged and gate payouts for ObservationWindow seconds; nobody is moved,
-- reset or kicked. Read-only.
local CharacterValidationConfig = table.freeze({
	SampleInterval = 0.2, -- seconds between server samples of each character (5 Hz)
	MaxSpeed = 24, -- horizontal studs/s; default WalkSpeed is 16
	SustainSeconds = 1.0, -- over MaxSpeed this long (continuously) before it counts
	-- Position jump: horizontal displacement beyond MaxSpeed * dt * DisplacementFactor + slack.
	DisplacementFactor = 1.5,
	DisplacementSlack = 6,
	SpawnGraceSeconds = 2, -- a new character settles (spawn, jail cell) before it is judged
	SeatGraceSeconds = 2, -- after leaving a seat (exit teleport, vehicle momentum)
	MoveGraceSeconds = 2, -- after an authorized server move (authorizeMove)
	ObservationWindow = 10, -- payouts are refused this long after an observation (R1.4)
	SummaryInterval = 30,
})

return CharacterValidationConfig
