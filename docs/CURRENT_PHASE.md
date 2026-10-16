# CURRENT PHASE

**Mode:** UNATTENDED (D-008) — run substages back to back; stop only at publish substages (write the package, continue elsewhere) and GO/NO-GO gates.
**Stage:** S2 — Signature: Crime Spree
**Substage:** S2.4 — Safehouses
**Status:** 🟨 In progress · **Last checkpoint passed:** S2.3 (2026-10-16)

## S2.4 — Safehouses
`SafehouseConfig` + `SafehouseService` (architecture §2.2, §10): two zones (an old garage in Old Town, a warehouse by the highway); standing in a zone with no police sight for 5 s banks the spree through `SpreeService.bank` → `EconomyService.bankSpree` (one idempotent grant per `spree:<id>`); the spree ends and stars decay to 0 over 10 s; observed or jailed players can't bank. Client `SafehouseMarker` shows both zones and the bank progress. World additions are named by this substage (D-006). The `BankSpree` dev command stays Studio-only. Passes: spec bank once, duplicate claim refused; play test bank from both.

## S2 stage notes
- Owner `.rbxl` for the S2 stage start: handoff owner item 1 (same instruction, name `OutlawCity_S2_before_<date>.rbxl`).
- S2 exit numbers: first crime ≤ 60 s; first result ≤ 4 min; 3★ budget; 8-client Studio soak 30 min, 0 errors.

## Carried notes (from R1)
- Restore points: `ServerStorage.Backups["R0 baseline"]`, `["R1.1 passed"]`, `["R1.2 passed"]`, `["R1.3 passed"]`, `["R1.4 passed"]`, `["R1.5 passed"]`, `["R1.6 passed"]`, `["R1.7 passed"]`, `["R1.8 passed"]`, `["S2.3 passed"]` (intermediate points pruned, D-015); owner `.rbxl` pending (handoff owner item 1).
- Hash checks skip `ServerStorage.Backups`; manifest format `<path>|<len>|<fnv1a>` sorted.
- New specs: create the ModuleScript with `Instance.new` + `.Source` (the MCP path syntax turns `X.spec` into a folder `X` with child `spec`); edit specs by literal replace via `execute_luau`.
- Studio command bar has its own require cache: reach live service state through Studio-only bridges (`ServerStorage.LoopGuardControl`) or dev remotes.
- Multi-client: `ExecuteMultiplayerTestAsync(n, name)` + `ServerStorage.Tests.Scenarios` (TEST_PLAN).
- R1 exit: TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded; 0 warnings.
