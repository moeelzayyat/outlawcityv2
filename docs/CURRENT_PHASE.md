# CURRENT PHASE

**Mode:** UNATTENDED (D-008) — run substages back to back; stop only at publish substages (write the package, continue elsewhere) and GO/NO-GO gates.
**Stage:** R1 — Integrity
**Substage:** R1.8 — Combat button hidden
**Status:** 🟨 In progress · **Last checkpoint passed:** R1.7 (2026-10-16; 🟦 dashboard check after the first owner publish)

## R1.8 — Combat button hidden
Hide the Combat/Peaceful toggle until damage exists (audit F5): a flag (`CombatConfig`), off until S5.1. Passes: not present in the HUD (screenshot); `CombatRules.spec` unchanged. Then the R1 exit check: TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded (done, R1.6); 0 warnings (🟦 until analysis is measurable).

## R1 stage notes
- Restore points: `ServerStorage.Backups["R0 baseline"]`, `["R1.1 passed"]`, `["R1.2 passed"]`, `["R1.3 passed"]`, `["R1.4 passed"]`, `["R1.5 passed"]`, `["R1.6 passed"]`, `["R1.7 passed"]`; owner `.rbxl` pending (handoff owner item 1).
- Hash checks skip `ServerStorage.Backups`; manifest format `<path>|<len>|<fnv1a>` sorted.
- New specs: create the ModuleScript with `Instance.new` + `.Source` (the MCP path syntax turns `X.spec` into a folder `X` with child `spec`); edit specs by literal replace via `execute_luau`.
- Studio command bar has its own require cache: reach live service state through Studio-only bridges (`ServerStorage.LoopGuardControl`) or dev remotes.
- Multi-client: `ExecuteMultiplayerTestAsync(n, name)` + `ServerStorage.Tests.Scenarios` (TEST_PLAN).
- R1 exit: TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded; 0 warnings.
