# CURRENT PHASE

**Mode:** UNATTENDED (D-008) — run substages back to back; stop only at publish substages (write the package, continue elsewhere) and GO/NO-GO gates.
**Stage:** R1 — Integrity
**Substage:** R1.5 — Spawn restrictions
**Status:** 🟨 In progress · **Last checkpoint passed:** R1.4 (2026-10-16)

## R1.5 — Spawn restrictions
`RequestSpawnVehicle` refused while `WantedLevel > 0` (`Wanted`), in a crime (`RobberyPhase` live → `InCrime`), or with unbanked cash > 0 (spree, S2; hook only); spawn only on a pad within 30 studs of the player (F3) — no teleport to a far pad; pad clearance includes characters (F14). Passes: spec + play test — V at 2★ → `Wanted`; V with a player on the pad → next pad. API_CONTRACTS row updated in the same change.

## R1 stage notes
- Restore points: `ServerStorage.Backups["R0 baseline"]`, `["R1.1 passed"]`, `["R1.2 passed"]`, `["R1.3 passed"]`, `["R1.4 passed"]`; owner `.rbxl` pending (handoff owner item 1).
- Hash checks skip `ServerStorage.Backups`; manifest format `<path>|<len>|<fnv1a>` sorted.
- New specs: create the ModuleScript with `Instance.new` + `.Source` (the MCP path syntax turns `X.spec` into a folder `X` with child `spec`); edit specs by literal replace via `execute_luau`.
- Studio command bar has its own require cache: reach live service state through Studio-only bridges (`ServerStorage.LoopGuardControl`) or dev remotes.
- R1 exit: TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded; 0 warnings.
