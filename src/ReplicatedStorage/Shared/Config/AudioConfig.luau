--!strict
-- Every sound the game plays (S2.6, architecture §14, D-003). Owner rule: audio is Roblox-owned
-- only, and an ID goes here only once it is approved and recorded in assets/ART_SOURCES.md (and
-- listed in ApprovedIds). An empty SoundId means "not chosen yet": the sound is skipped, never
-- replaced by a guess. Positional sounds fade with distance (RollOffMin..RollOffMax studs).
-- Read-only at runtime.
export type Sound = {
	SoundId: string, -- "rbxassetid://<id>" or "" (pending)
	Volume: number,
	Looped: boolean,
	Positional: boolean, -- false: a 2D interface sound for one player
	RollOffMin: number?, -- full volume within this many studs
	RollOffMax: number?, -- silent beyond this
}

local AudioConfig = {}

AudioConfig.Sounds = table.freeze({
	Siren = table.freeze({ SoundId = "rbxassetid://9119165420", Volume = 0.6, Looped = true, Positional = true, RollOffMin = 30, RollOffMax = 400 }) :: Sound,
	Engine = table.freeze({ SoundId = "rbxassetid://80317022777602", Volume = 0.35, Looped = true, Positional = true, RollOffMin = 15, RollOffMax = 200 }) :: Sound,
	Tyre = table.freeze({ SoundId = "rbxassetid://9120399077", Volume = 0.4, Looped = true, Positional = true, RollOffMin = 15, RollOffMax = 200 }) :: Sound,
	Alarm = table.freeze({ SoundId = "rbxassetid://9113084849", Volume = 0.7, Looped = false, Positional = true, RollOffMin = 25, RollOffMax = 350 }) :: Sound,
	Bank = table.freeze({ SoundId = "rbxassetid://9113728042", Volume = 0.8, Looped = false, Positional = false }) :: Sound,
	Bust = table.freeze({ SoundId = "rbxassetid://9117907414", Volume = 0.8, Looped = false, Positional = false }) :: Sound,
})

-- Every ID in Sounds must be listed here, mirroring its approved row in assets/ART_SOURCES.md.
-- Approved by the owner on 2026-10-16 (D-017): free Creator Store sounds from Pro Sound Effects
-- and the verified Roblox Resources group.
AudioConfig.ApprovedIds = table.freeze({
	"rbxassetid://9119165420", -- Siren
	"rbxassetid://80317022777602", -- Engine
	"rbxassetid://9120399077", -- Tyre
	"rbxassetid://9113084849", -- Alarm
	"rbxassetid://9113728042", -- Bank
	"rbxassetid://9117907414", -- Bust
} :: { string })

AudioConfig.EngineTopSpeed = 120 -- studs/s where the engine reaches EnginePitchMax
AudioConfig.EnginePitchMin = 0.8
AudioConfig.EnginePitchMax = 1.6
AudioConfig.TyreSlipSpeed = 12 -- sideways studs/s before the tyres squeal
AudioConfig.TyreSlipFull = 30 -- sideways studs/s at full squeal volume

return table.freeze(AudioConfig)
