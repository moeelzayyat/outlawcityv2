# CURRENT PHASE

**Mode:** UNATTENDED (D-008) — run substages back to back; stop only at publish substages (write the package, continue elsewhere) and GO/NO-GO gates.
**Stage:** R1 — Integrity
**Substage:** R1.3 — Character sampler
**Status:** 🟨 In progress · **Last checkpoint passed:** R1.2 (2026-10-16)

## R1.3 — Character sampler
`CharacterValidationRules` (pure, `Shared/Rules/`) + `CharacterValidationService` (5 Hz, on-foot speed/displacement caps, non-finite rejection, same shape as `VehicleValidationRules`); observations logged; `ObservedAt` player attribute. Numbers in `STATS.md` §Character sampler. Passes: spec — 3 min of generated normal play → 0 observations; a 100-stud hop → observation; NaN rejected. Never kicks or corrects (D-004).

## R1 stage notes
- Restore points: `ServerStorage.Backups["R0 baseline"]`, `["R1.1 passed"]`, `["R1.2 passed"]`; owner `.rbxl` pending (handoff owner item 1).
- Hash checks skip `ServerStorage.Backups`; manifest format `<path>|<len>|<fnv1a>` sorted.
- New specs: create the ModuleScript with `Instance.new` + `.Source` (the MCP path syntax turns `X.spec` into a folder `X` with child `spec`); edit specs by literal replace via `execute_luau`.
- Studio command bar has its own require cache: reach live service state through Studio-only bridges (`ServerStorage.LoopGuardControl`) or dev remotes.
- R1 exit: TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded; 0 warnings.
