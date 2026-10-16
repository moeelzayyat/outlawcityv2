# CURRENT PHASE

**Mode:** UNATTENDED (D-008) — run substages back to back; stop only at publish substages (write the package, continue elsewhere) and GO/NO-GO gates.
**Stage:** R1 — Integrity
**Substage:** R1.7 — Event bus + analytics
**Status:** 🟨 In progress · **Last checkpoint passed:** R1.6 (2026-10-16)

## R1.7 — Event bus + analytics
`Shared/Util/EventBus` (typed, server-side; events per architecture §5 and `docs/EVENTS.md`); the two hidden wires (`WantedService.setPoliceSightProvider`, the `Escaped` Signal subscription) replaced by bus events/queries; `AnalyticsService` funnel `Joined, FirstCar, FirstCrime, FirstBank, FirstBust, SpreeEnded, Again, Left` (FirstBank/SpreeEnded/Again fire from S2). LoopGuard reports through Analytics. Passes: funnel events visible in the Analytics dashboard after a play test — Studio sessions don't reach the dashboard, so that item needs a published build (🟦, owner).

## R1 stage notes
- Restore points: `ServerStorage.Backups["R0 baseline"]`, `["R1.1 passed"]`, `["R1.2 passed"]`, `["R1.3 passed"]`, `["R1.4 passed"]`, `["R1.5 passed"]`, `["R1.6 passed"]`; owner `.rbxl` pending (handoff owner item 1).
- Hash checks skip `ServerStorage.Backups`; manifest format `<path>|<len>|<fnv1a>` sorted.
- New specs: create the ModuleScript with `Instance.new` + `.Source` (the MCP path syntax turns `X.spec` into a folder `X` with child `spec`); edit specs by literal replace via `execute_luau`.
- Studio command bar has its own require cache: reach live service state through Studio-only bridges (`ServerStorage.LoopGuardControl`) or dev remotes.
- Multi-client: `ExecuteMultiplayerTestAsync(n, name)` + `ServerStorage.Tests.Scenarios` (TEST_PLAN).
- R1 exit: TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded; 0 warnings.
