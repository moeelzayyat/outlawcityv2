# CURRENT PHASE

**Mode:** UNATTENDED (D-008) — run substages back to back; stop only at publish substages (write the package, continue elsewhere) and GO/NO-GO gates.
**Stage:** S2 — Signature: Crime Spree
**Substage:** S2.8 — First session
**Status:** 🟨 In progress · **Last checkpoint passed:** S2.5 (2026-10-16); S2.6 🟦 sound IDs (owner item 4); S2.7 🟦 Device Simulator screenshots (owner item 7)

## S2.8 — First session
Protected first spree: players with 0 completed sprees get `SpreeConfig.FirstSpreeDispatchDelay` (10 s) before police dispatch; markers to the nearest ATM / store / safehouse; tip text for the spree loop. Pass: 5 fresh accounts, first crime ≤ 60 s, first result ≤ 4 min median (console timestamps). Studio can't make 5 fresh Roblox accounts: measure with fresh profiles (WriteLegacyProfile / new DataStore keys) and mark real accounts 🟦.

## S2 stage notes
- Owner `.rbxl` for the S2 stage start: handoff owner item 1 (same instruction, name `OutlawCity_S2_before_<date>.rbxl`).
- S2 exit numbers: first crime ≤ 60 s; first result ≤ 4 min; 3★ budget; 8-client Studio soak 30 min, 0 errors.

## Carried notes (from R1)
- Restore points: `ServerStorage.Backups["R0 baseline"]`, `["R1.1 passed"]`, `["R1.2 passed"]`, `["R1.3 passed"]`, `["R1.4 passed"]`, `["R1.5 passed"]`, `["R1.6 passed"]`, `["R1.7 passed"]`, `["R1.8 passed"]`, `["S2.5 passed"]`, `["S2.7 built"]` (intermediate points pruned, D-015); owner `.rbxl` pending (handoff owner item 1).
- Hash checks skip `ServerStorage.Backups`; manifest format `<path>|<len>|<fnv1a>` sorted.
- New specs: create the ModuleScript with `Instance.new` + `.Source` (the MCP path syntax turns `X.spec` into a folder `X` with child `spec`); edit specs by literal replace via `execute_luau`.
- Studio command bar has its own require cache: reach live service state through Studio-only bridges (`ServerStorage.LoopGuardControl`) or dev remotes.
- Multi-client: `ExecuteMultiplayerTestAsync(n, name)` + `ServerStorage.Tests.Scenarios` (TEST_PLAN).
- R1 exit: TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded; 0 warnings.
