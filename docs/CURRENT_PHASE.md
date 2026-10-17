# CURRENT PHASE

**Mode:** UNATTENDED (D-008) — run substages back to back; stop only at publish substages (write the package, continue elsewhere) and GO/NO-GO gates.
**Stage:** P1 — Polish (D-022), then S3 — Public test (GO/NO-GO at S3.6)
**Substage:** P1.4 — Owner publish of the polished build (P1.1–P1.3 ✅)
**Status:** 🟦 READY FOR OWNER TO PUBLISH · **Last checkpoint passed:** P1.3 (2026-10-17)

## P1 — Polish
City dressing, crime sites and safehouses, cars and police livery: all built in code at server start, no outside assets. The owner publishes the polished build (and may keep the game Private until then). S3.1 resumes after that.

## S3.1 — List publicly
Public and playable. Open owner fixes: maturity label (shows Ages 16+), server size 8, title/description, icon and thumbnails. No ads in week 1 (D-018). Next: S3.2 outside sessions and the first weekly signal read once real sessions exist. S3.6 is a gate: stop there.

## S2 stage notes
- Owner `.rbxl` for the S2 stage start: handoff owner item 1 (same instruction, name `OutlawCity_S2_before_<date>.rbxl`).
- S2 exit numbers: first crime ≤ 60 s; first result ≤ 4 min; 3★ budget; 8-client Studio soak 30 min, 0 errors.

## Carried notes (from R1)
- Restore points: `ServerStorage.Backups["R0 baseline"]`, `["R1.1 passed"]`, `["R1.2 passed"]`, `["R1.3 passed"]`, `["R1.4 passed"]`, `["R1.5 passed"]`, `["R1.6 passed"]`, `["R1.7 passed"]`, `["R1.8 passed"]`, `["S2.9 passed"]`, `["S2 exit"]` (intermediate points pruned, D-015); owner `.rbxl` pending (handoff owner item 1).
- Hash checks skip `ServerStorage.Backups`; manifest format `<path>|<len>|<fnv1a>` sorted.
- New specs: create the ModuleScript with `Instance.new` + `.Source` (the MCP path syntax turns `X.spec` into a folder `X` with child `spec`); edit specs by literal replace via `execute_luau`.
- Studio command bar has its own require cache: reach live service state through Studio-only bridges (`ServerStorage.LoopGuardControl`) or dev remotes.
- Multi-client: `ExecuteMultiplayerTestAsync(n, name)` + `ServerStorage.Tests.Scenarios` (TEST_PLAN).
- R1 exit: TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded; 0 warnings.
