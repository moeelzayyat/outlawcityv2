# CURRENT PHASE

**Mode:** UNATTENDED (D-008) — run substages back to back; stop only at publish substages (write the package, continue elsewhere) and GO/NO-GO gates.
**Stage:** S2 — Signature: Crime Spree
**Substage:** S2.2 — SpreeService + HUD
**Status:** 🟨 In progress · **Last checkpoint passed:** S2.1 (2026-10-16)

## S2.2 — SpreeService + HUD
Server spree state per player (`SpreeService`, `SpreeRules`): crimes add to the spree (robbery completion for now; CrimeService in S2.3), bust loses it, escape keeps it; banking via safehouses arrives in S2.4 (S2.2 banks through a Studio dev command only). `SpreeHudController`: unbanked counter, multiplier, stars in row 1; result card with "Again". Escaping no longer pays — banking pays (D-001): the robbery escape payout is replaced by adding the robbery to the spree. Attributes `SpreeUnbanked`, `SpreeMultiplier`, `SpreeCrimes`; `OnSpreeNotice` remote (contract row first). Passes: play test ATM/robbery → counter → bank → cash; bust → loss shown.

## S2 stage notes
- Owner `.rbxl` for the S2 stage start: handoff owner item 1 (same instruction, name `OutlawCity_S2_before_<date>.rbxl`).
- S2 exit numbers: first crime ≤ 60 s; first result ≤ 4 min; 3★ budget; 8-client Studio soak 30 min, 0 errors.

## Carried notes (from R1)
- Restore points: `ServerStorage.Backups["R0 baseline"]`, `["R1.1 passed"]`, `["R1.2 passed"]`, `["R1.3 passed"]`, `["R1.4 passed"]`, `["R1.5 passed"]`, `["R1.6 passed"]`, `["R1.7 passed"]`, `["R1.8 passed"]`, `["S2.1 passed"]` (intermediate R1.x pruned, D-015); owner `.rbxl` pending (handoff owner item 1).
- Hash checks skip `ServerStorage.Backups`; manifest format `<path>|<len>|<fnv1a>` sorted.
- New specs: create the ModuleScript with `Instance.new` + `.Source` (the MCP path syntax turns `X.spec` into a folder `X` with child `spec`); edit specs by literal replace via `execute_luau`.
- Studio command bar has its own require cache: reach live service state through Studio-only bridges (`ServerStorage.LoopGuardControl`) or dev remotes.
- Multi-client: `ExecuteMultiplayerTestAsync(n, name)` + `ServerStorage.Tests.Scenarios` (TEST_PLAN).
- R1 exit: TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded; 0 warnings.
