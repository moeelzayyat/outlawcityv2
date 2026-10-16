# CURRENT PHASE

**Mode:** UNATTENDED (D-008) — run substages back to back; stop only at publish substages (write the package, continue elsewhere) and GO/NO-GO gates.
**Stage:** S2 — Signature: Crime Spree
**Substage:** S2.5 — Police escalation
**Status:** 🟨 In progress · **Last checkpoint passed:** S2.4 (2026-10-16)

## S2.5 — Police escalation
`UnitsByStars {1,2,3}` (D-002), server cap 6, re-target, roadblock at 3★ (architecture §2.2, §11; STATS §Police). PoliceService grows from one unit to a unit pool: each wanted player gets units by stars, the server never exceeds 6, units re-target when their player is busted, banks or escapes, and at 3★ a roadblock spawns 250 studs ahead for 30 s. Siren stays off unless the owner supplies an asset (owner item). Passes: 3★ → 3 units + roadblock; budget ≤ 50 raycasts/frame; ≤ 2 ms (Profiler).

## S2 stage notes
- Owner `.rbxl` for the S2 stage start: handoff owner item 1 (same instruction, name `OutlawCity_S2_before_<date>.rbxl`).
- S2 exit numbers: first crime ≤ 60 s; first result ≤ 4 min; 3★ budget; 8-client Studio soak 30 min, 0 errors.

## Carried notes (from R1)
- Restore points: `ServerStorage.Backups["R0 baseline"]`, `["R1.1 passed"]`, `["R1.2 passed"]`, `["R1.3 passed"]`, `["R1.4 passed"]`, `["R1.5 passed"]`, `["R1.6 passed"]`, `["R1.7 passed"]`, `["R1.8 passed"]`, `["S2.4 passed"]` (intermediate points pruned, D-015); owner `.rbxl` pending (handoff owner item 1).
- Hash checks skip `ServerStorage.Backups`; manifest format `<path>|<len>|<fnv1a>` sorted.
- New specs: create the ModuleScript with `Instance.new` + `.Source` (the MCP path syntax turns `X.spec` into a folder `X` with child `spec`); edit specs by literal replace via `execute_luau`.
- Studio command bar has its own require cache: reach live service state through Studio-only bridges (`ServerStorage.LoopGuardControl`) or dev remotes.
- Multi-client: `ExecuteMultiplayerTestAsync(n, name)` + `ServerStorage.Tests.Scenarios` (TEST_PLAN).
- R1 exit: TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded; 0 warnings.
