# TEST PLAN

## Runners
- Unit/pure: `ServerStorage/Tests/TestRunner` at every Studio play (`[Tests] N passed, 0 failed`). Keep the 216.
- Service tests: new specs with fake `Players`/`World`/store (pattern in `ProfileSession.spec`).
- Multi-client: Studio Test → Clients and Servers (2, 4, 8). Standard evidence for dispatch, cars, pads, spree, safehouses, jail. Not real-network evidence. **Scripted (R1.6):** `StudioTestService:ExecuteMultiplayerTestAsync(n, "<name>")` from the command bar starts n clients; Main runs `ServerStorage.Tests.Scenarios.run(name)` on the test server, which drives the live services and returns `PASS/FAIL/ERROR …` through `EndTest`. Run it in a `task.spawn` and poll `_G` (the call yields until the session ends). Scenarios: `R1.6-Dispatch` (2 clients), `S2.3-Crimes` (1 client: ATM, failed ATM, gas station, car theft into the spree), `S2.4-Safehouses` (1 client: bank at both, sight blocks, star cool-down, repeat claims refused), `S2.5-Escalation` (3 clients: units by stars, cap, roadblock, re-target, budget), `S2.8-FirstSpree` (1 client: 10 s first-spree dispatch delay), `S2.9-Boards` (1 client: objective paid once, boards updated), `S2-Soak` (8 clients, 30 min: errors, loop failures, police budget, memory). `R1.6-Dispatch` was updated in S2.5 for the unit pool (B gets its own unit; heat never decays before).
- Play tests: `start_stop_play` + console + screenshots; Device Simulator iPhone 7 and 13 Pro Max; owner's real phone at S2.7/S3.5.
- Security: spam at 50× rate; spoofed positions (teleport character to the register / away from police); NaN/inf; dev remote outside Studio.
- Performance: 8 clients, 6 units, 2 roadblocks; FPS on the Device Simulator; memory over 2 h.

## Coverage by stage
### R1
Loop isolation (injected error per loop); `JailService.release` with a left player; lock release on leave-during-load; `Corrupt` for non-table / `{Lock}`-only; ledger batching; v3→v4 migration fixture; character sampler (normal play 0 observations; hop; NaN); payout gating (observed → refused; bounds-validated holdout); spawn restrictions; dispatch re-target with 2 clients; decay freeze when unassigned; EventBus publish/subscribe/isolation; funnel events present.
### S2
SpreeRules ≥ 15 cases; SpreeService state machine; CrimeConfig validation at boot (duplicate IDs, negative values fail); every crime's start/validate/complete/fail; safehouse bank once per spreeId; police escalation budget probe; audio IDs all Roblox-owned (spec reads `AudioConfig`); HUD screenshots at two phone sizes; first-session timings on 5 fresh accounts; leaderboard submit/read/reset; objective once; 8-client 30-min soak.
### S4–S5
Paint purchase idempotent; reputation unlocks; NPC traffic budget; ram damage through `canPlayerHarm` only; co-op split bank idempotent per member; 8-client 2-h soak; `MULTIPLAYER_TESTS.md` items closed one by one with the client count recorded.
### B1/L1
Security suite; 10,000-spree economy sim; admin inspect/grant/rollback; receipts idempotent; codes once.
