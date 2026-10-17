# PERFORMANCE BUDGETS

Measured cells only. Baselines from `docs/legacy/PROGRESS.md` (solo Studio).

| Metric | Target | Baseline | R1 | S2.5 | S2 soak | S5 | B1 |
|---|---|---|---|---|---|---|---|
| Server game work / frame (8 players, 6 units, 2 roadblocks) | ≤ 2 ms | police 0.09–0.12 ms avg, 0.44 max (1 unit) | | | | | |
| Police raycasts / frame | ≤ 100 (D-019; was 50 for 6 units) | 7 (1 unit) | | | | | |
| Validation loops (vehicle + character) | ≤ 0.2 ms | vehicle 0.034 ms avg | | | | | |
| Client FPS PC (3★ chase) | 60 | 60 (Studio front) | | | | | |
| Client FPS Device Simulator (3★ chase) | ≥ 30 | ~60 idle (sim) | | | | | |
| Client FPS owner's phone | ≥ 30 | not tested | | | | | |
| Join → seated (new account) | ≤ 10 s | FirstCar 26.5–31.8 s (owner session, includes the tip) | | | | | |
| First crime (new account, unassisted) | ≤ 60 s | FirstRobbery 76.9–83.0 s | | | | | |
| First result (bank or bust) | ≤ 4 min | n/a | | | | | |
| Memory growth (2 h, 8 clients) | < 50 MB/h | inconclusive (long Studio sessions) | | | | | |
| DataStore writes per player per minute | ≤ 3 | ~1 per cash change + heartbeat/60 s | | | | | |
| Save failures unresolved | 0 | 0 observed | | | | | |

Probes: police step timer (exists), validation loop timer (exists), a `RaycastProbe` counting raycasts per frame, `MemoryProbe` every 60 s, funnel timestamps.
