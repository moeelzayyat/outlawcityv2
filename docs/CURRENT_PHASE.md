# CURRENT PHASE

**Mode:** UNATTENDED (D-008) — run substages back to back; stop only at publish substages (write the package, continue elsewhere) and GO/NO-GO gates.
**Stage:** S2 — Signature: Crime Spree
**Substage:** S2.3 — CrimeConfig + CrimeService
**Status:** 🟨 In progress · **Last checkpoint passed:** S2.2 (2026-10-16)

## S2.3 — CrimeConfig + CrimeService
Generic holdout engine replacing RobberyService (architecture §10): `CrimeConfig` defines each crime (area, hold, base cash, stars, cooldown, alarm chance); store robbery migrated as a definition (RobberyRules.spec stays green via the definition); ATM ×4 (6 s, $800, 1★, 90 s, silent alarm 50%), gas station ×1 (12 s, $1,500, 2★, 150 s), car theft ×6 NPC parked cars ($500 at bank, 1★, respawn 120 s). World additions are named by this substage (D-006 allows it): ATM props, a gas station, parked NPC cars — each with an exact rollback. Passes: each crime's start/validate/complete/fail paths in spec; play test.

## S2 stage notes
- Owner `.rbxl` for the S2 stage start: handoff owner item 1 (same instruction, name `OutlawCity_S2_before_<date>.rbxl`).
- S2 exit numbers: first crime ≤ 60 s; first result ≤ 4 min; 3★ budget; 8-client Studio soak 30 min, 0 errors.

## Carried notes (from R1)
- Restore points: `ServerStorage.Backups["R0 baseline"]`, `["R1.1 passed"]`, `["R1.2 passed"]`, `["R1.3 passed"]`, `["R1.4 passed"]`, `["R1.5 passed"]`, `["R1.6 passed"]`, `["R1.7 passed"]`, `["R1.8 passed"]`, `["S2.2 passed"]` (intermediate points pruned, D-015); owner `.rbxl` pending (handoff owner item 1).
- Hash checks skip `ServerStorage.Backups`; manifest format `<path>|<len>|<fnv1a>` sorted.
- New specs: create the ModuleScript with `Instance.new` + `.Source` (the MCP path syntax turns `X.spec` into a folder `X` with child `spec`); edit specs by literal replace via `execute_luau`.
- Studio command bar has its own require cache: reach live service state through Studio-only bridges (`ServerStorage.LoopGuardControl`) or dev remotes.
- Multi-client: `ExecuteMultiplayerTestAsync(n, name)` + `ServerStorage.Tests.Scenarios` (TEST_PLAN).
- R1 exit: TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded; 0 warnings.
