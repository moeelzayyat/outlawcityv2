--!strict
-- Peaceful / Combat status tuning. Read-only at runtime.
local CombatConfig = {}

-- Seconds after entering Combat (or after the last combat activity) before the player may
-- switch back to Peaceful.
CombatConfig.CombatCooldown = 30
-- Minimum seconds between combat-status requests from one player (anti-spam).
CombatConfig.RequestInterval = 1
-- The Peaceful/Combat toggle is hidden until damage exists (audit F5, R1.8); S5.1 turns it on.
CombatConfig.ToggleVisible = false

return table.freeze(CombatConfig)
