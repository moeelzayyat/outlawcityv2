# CURRENT PHASE

**Mode:** UNATTENDED (D-008) — run substages back to back; stop only at publish substages (write the package, continue elsewhere) and GO/NO-GO gates.
**Stage:** R1 — Integrity
**Substage:** R1.6 — Dispatch re-target + decay freeze
**Status:** 🟨 In progress · **Last checkpoint passed:** R1.5 (2026-10-16)

## R1.6 — Dispatch re-target + decay freeze
The unit follows its assigned player and re-targets each tick to the highest-stars wanted player when its target is cleared/left; a wanted player with no unit has heat frozen (counts as seen) — audit F2, D-002 (multi-unit `UnitsByStars` comes in S2.5). Passes: 2 Studio clients: A rams, B robs → B's heat does not decay until a unit sees or is assigned.

## R1 stage notes
- Restore points: `ServerStorage.Backups["R0 baseline"]`, `["R1.1 passed"]`, `["R1.2 passed"]`, `["R1.3 passed"]`, `["R1.4 passed"]`, `["R1.5 passed"]`; owner `.rbxl` pending (handoff owner item 1).
- Hash checks skip `ServerStorage.Backups`; manifest format `<path>|<len>|<fnv1a>` sorted.
- New specs: create the ModuleScript with `Instance.new` + `.Source` (the MCP path syntax turns `X.spec` into a folder `X` with child `spec`); edit specs by literal replace via `execute_luau`.
- Studio command bar has its own require cache: reach live service state through Studio-only bridges (`ServerStorage.LoopGuardControl`) or dev remotes.
- R1 exit: TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded; 0 warnings.
