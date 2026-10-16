# HANDOFF REPORT

Append-only; template in `ROADMAP.md` §12. Historical audit packages: `docs/legacy/audits/`.

---

## v2.0 re-baseline — 2026-10-16
Audit (`docs/AUDIT_2026-10-16.md`), architecture v2.0, roadmap and docs written. No Studio changes. Pending batch c4bebb5 (sign enlargement): approve with conditions as a change; frozen under D-006. Current substage: **R0.1 — Decisions** (D-001…D-008 proposed).

---

## CHECKPOINT: R0 Re-baseline (R0.1–R0.5) · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 216 passed, 0 failed · SCRIPT ANALYSIS: n.a. (no code touched)
PLAY TEST: Studio play, 1 client → runner green; console: only Roblox CorePackages UIBlox warnings, 0 game errors
NUMBERS: Studio scripts 104 = src/ 104; per-script length + FNV-1a equal; manifest e4c1fd69 both sides
BACKUP/RESTORE POINT: ServerStorage.Backups["R0 baseline"] (scripts manifest 47bd2716 = live; City 402 instances; Lighting)
  owner .rbxl: NOT confirmed (no "Place file downloaded" in the Studio log, none on disk) → owner item 1
MIRROR COMMIT: docs only (src/ unchanged, already equal to Studio) · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: R1.1
```
Local folder `C:\RobloxProjects\OutlawCityV2` is now a git clone of `moeelzayyat/outlawcityv2` (`core.longpaths true`; `docs/legacy` has paths over 260 chars).

### Owner items (nothing here blocks R1; do them when convenient)
1. **Place backup:** in the Outlaw City Studio window, File → Download a Copy → save as `OutlawCity_R1_before_2026-10-16.rbxl` outside the repo. This is the stage-start backup for R1.
2. **Studio changes are not saved by me.** The restore-point folder `ServerStorage.Backups` and all R1 work live in the open Studio session; `src/` in git is the recovery copy for every script. Save the place the way you normally do (not a publish).
3. **MaxPlayers 8** (D-005): Game Settings → Places → Outlaw City → Max Players = 8. Studio currently reports 60.
4. **Sound IDs** (D-003, S2.6): the audio system is built but silent. No search result was uploaded by the `Roblox` account itself, so tell me which IDs (or which creators, e.g. Roblox's licensed Pro Sound Effects library) count as Roblox-owned. Candidates are listed in `assets/ART_SOURCES.md`; I need a siren, engine loop, tyre squeal, alarm, bank (cash register) and bust sting.
5. **Icon palette** (`ART_BIBLE.md`): sunset orange or night blue; needed by S2.10.
6. **Archive the old repo** `moeelzayyat/outlawcity` on GitHub (Settings → Archive this repository). It is history only.
7. **HUD screenshots** (S2.7): in Studio, Test → Device → iPhone 7, then iPhone 13 Pro Max, Play, and check the top of the screen: stars and cash in the first row, nothing overlapping. I can't drive Device Simulator from here.

---

## CHECKPOINT: R1.1 Loop isolation + lifecycle · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 224 passed, 0 failed (216 + LoopGuard.spec 8)
SCRIPT ANALYSIS: 🟦 not measurable via the Studio MCP; all 11 touched scripts parse (loadstring). See owner item 7.
PLAY TEST (clients: 1): 3 injected faults into each of the 8 loops (Jail, Wanted, Police, Robbery, SafeZone,
  VehicleValidation, Economy.autosave, Economy.claims) → each: failures=3, reported=1, then "recovered", iterations
  continued (e.g. Jail 42→92 in 15 s). Jail: bust via dev tools, 6 faults into the Jail loop → released 0.10 s after due.
  Console: 0 game errors (only Roblox CorePackages UIBlox warnings).
NUMBERS: backoff 1 s from the 2nd consecutive failure; report once per streak.
NOT COVERED: release of a player who leaves in the same tick as their release is a guarded race, not reproduced.
BACKUP/RESTORE POINT: ServerStorage.Backups["R1.1 passed"] (scripts only, no world change)
MIRROR: Studio = src/ 106/106, manifest 79b0d727 · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: R1.2
```
Studio-only addition: `ServerStorage.LoopGuardControl` (BindableFunction, created only when `RunService:IsStudio()`) lets the command bar inject faults and read loop stats; the command bar has its own require cache.
7. **Static analysis (owner choice):** the Studio MCP can't read Script Analysis. Either glance at View → Script Analysis at a checkpoint, or allow me to download `luau-analyze` from the official luau-lang GitHub release so I can count warnings myself. Until then each checkpoint records static as 🟦.

## CHECKPOINT: R1.2 Persistence fixes · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 237 passed, 0 failed (+ ProfileStore.spec 5, ProfileSession.spec 2, ProfileMigration.spec 6;
  EconomyRules.spec v3 cases moved to v4, "newer schema" case now v5)
SCRIPT ANALYSIS: 🟦 not measurable via MCP; 107/107 scripts parse
PLAY TEST (clients: 1): join → "[Economy] Lighthouse8282: loaded (Migrated) cash=11400" (Studio store v3 → v4);
  store robbery → escape → "reward 2000 … -> 13400 (stored)"; 14 s later the Studio DataStore shows
  ledger {"Rewards":[]}, profile Version=4, PaidRewards=[robbery:c12762d1…], Stats all 0. Console: 0 game errors.
NUMBERS: ledger settle delay 10 s; profile write count for a robbery payout unchanged (1); ledger writes 2 (record, settle) spaced ≥ 10 s.
NOT COVERED live: leave-during-load (F6) needs a slow load + leave; covered by ProfileStore.spec release cases.
OBSERVED: the escape was achieved by teleporting the character away from the cruiser — the F1 hole, closed in R1.3/R1.4.
BACKUP/RESTORE POINT: ServerStorage.Backups["R1.2 passed"]
MIRROR: Studio = src/ 107/107, manifest dc583350 · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: R1.3
```
Schema note for the owner: once any v4 server saves a profile, an older v3 build refuses that record untouched (by design). The Studio test store is already v4.

## CHECKPOINT: R1.3 Character sampler · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 244 passed, 0 failed (+ CharacterValidation.spec 7: 3 min generated play → 0; 100-stud hop → Teleport;
  NaN/inf → InvalidState; sustained overspeed vs burst; grace; vertical fall; payout window)
SCRIPT ANALYSIS: 🟦 not measurable via MCP; 111/111 scripts parse
PLAY TEST (clients: 1): 20 s MoveTo walk with jumps, Coupe spawn (server seats at a pad) + exit, bust → cell → release:
  ObservedAt stayed nil; summary "samples=266 observations=0". Client PivotTo +100 studs → 2 observations
  ("moved 64 studs in 0.22 s", "moved 36 studs in 0.22 s"), ObservedAt set. Console: 0 game errors.
NUMBERS: CharacterValidation loop avg 0.014–0.015 ms, max 0.025 ms (1 player).
KNOWN LIMITS: a character flung by a car or standing on a moving vehicle can be observed (payouts gated 10 s, nothing else).
BACKUP/RESTORE POINT: ServerStorage.Backups["R1.3 passed"]
MIRROR: Studio = src/ 111/111, manifest daa605df · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: R1.4
```

## CHECKPOINT: R1.4 Payout gating · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 251 passed, 0 failed (+ RobberyRules.spec 3 Observed cases; + AreaCheck.spec 4 incl. root inside / body outside → not inside)
SCRIPT ANALYSIS: 🟦 not measurable via MCP; 113/113 scripts parse
PLAY TEST (clients: 1):
  1. teleport into the store → TryRobStore → false, "Observed"
  2. wait 11 s, rob, hold 16.5 s standing still → "holdout complete; escaping" (AreaCheck passes a real character)
  3. teleport away (the R1.2 exploit) → "[Robbery] … failed: Observed" within 0.5 s, cash unchanged 13400
  4. rob again, getaway in the Coupe at 90 studs/s (limit 166) → "escaped; paid 2000" → 15400; VehicleValidation samples=85 observations=0
  Console: 0 game errors.
NUMBERS: observation → robbery failure ≤ 0.5 s; CharacterValidation avg 0.015–0.017 ms/loop.
NOT PLAY-TESTED: the AlreadyPaid toast (needs an ambiguous write at payout); code path is one notify call.
BACKUP/RESTORE POINT: ServerStorage.Backups["R1.4 passed"]
MIRROR: Studio = src/ 113/113, manifest 57d1f952 · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: R1.5
```

## CHECKPOINT: R1.5 Spawn restrictions · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 258 passed, 0 failed (+ VehicleSpawn.spec 6; + CharacterValidation.spec "leaving a seat allows exit momentum but not a teleport")
SCRIPT ANALYSIS: 🟦 not measurable via MCP; 115/115 scripts parse
PLAY TEST (clients: 1):
  V at 2★ → false, "Wanted"
  V from the plaza (stood at 20,0; nearest pad ~47 studs) → car 9.8 studs away, seated
  V standing on pad PlazaSE (own character blocks it) → car 9.8 studs from the pad, not on it
  V 12 studs beside free pad PlazaNE → car 0.2 studs from the pad centre
  exit car → no observation; exit then client teleport +300 → "moved 300 studs in 0.20 s (allowed 60)"
  Console: 0 game errors.
NOT COVERED: "another player on the pad" needs 2 clients; covered by the same code path (all characters are blockers) and VehicleSpawn.spec.
BACKUP/RESTORE POINT: ServerStorage.Backups["R1.5 passed"]
MIRROR: Studio = src/ 115/115, manifest 4a84eec9 · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: R1.6
```

## CHECKPOINT: R1.6 Dispatch re-target + decay freeze · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 261 passed, 0 failed (+ PoliceDispatch.spec 3: keep target, re-target to most-wanted free player, heat held rules)
SCRIPT ANALYSIS: 🟦 not measurable via MCP; 116/116 scripts parse
PLAY TEST (clients: 1): 2★ at (-300,-300) → dispatched → sighted → BUSTED → despawn; console 0 game errors
MULTI-CLIENT (clients: 2, Studio local server, NOT real network): StudioTestService:ExecuteMultiplayerTestAsync(2, "R1.6-Dispatch")
  → "PASS B heat held at 70.0 for 21.8 s while the unit chased A; unit re-targeted to B after 22.0 s" (38.4 s session)
  A: 2× RammingPolice via WantedService.reportCrime (the ram detector itself not exercised); B: StoreRobbery crime.
NUMBERS: B unassigned 21.8 s (> 8 s decay delay) with heat 70.0 → 70.0; re-target latency ≤ 1 tick (0.25 s).
BACKUP/RESTORE POINT: ServerStorage.Backups["R1.6 passed"]
MIRROR: Studio = src/ 116/116, manifest acc6b457 · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: R1.7
```
New tool: `ServerStorage.Tests.Scenarios` (Studio-only multi-client scenarios; see TEST_PLAN). Studio 2–8-client runs are now scriptable and unattended.

## CHECKPOINT: R1.7 Event bus + analytics · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 269 passed, 0 failed (+ EventBus.spec 5, FunnelRules.spec 3)
SCRIPT ANALYSIS: 🟦 not measurable via MCP; 121/121 scripts parse
PLAY TEST (clients: 1): "[Analytics] Joined" → Coupe → "[Analytics] FirstCar" → robbery → "[Analytics] FirstCrime"
  (each with Roblox's "AnalyticsService: LogOnboardingFunnelStepEvent event fired."); holdout → getaway in the parked
  Coupe at 90 studs/s → Escaped via the bus → "escaped; paid 2000" (15400 → 17400). Console: 0 game errors.
MULTI-CLIENT (clients: 2, Studio): R1.6-Dispatch re-run → PASS (B heat held 70.0 for 22.0 s; re-target after 22.2 s) — PoliceSight over the bus
NOT VERIFIED: dashboard (Studio sends nothing) 🟦; "Left" (Studio stop shuts the server via BindToClose, no PlayerRemoving);
  "FirstBust" (dev SimulateBust jails directly, not via PoliceService.bust).
BACKUP/RESTORE POINT: ServerStorage.Backups["R1.7 passed"]
MIRROR: Studio = src/ 121/121, manifest 474df26c · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: R1.8
```

## CHECKPOINT: R1.8 Combat button hidden + R1 exit · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 270 passed, 0 failed (+1: toggle stays hidden)
SCRIPT ANALYSIS: 🟦 · 121/121 scripts parse
PLAY TEST (clients: 1): PlayerGui = CashHud, DealershipGui, DevPanel, Freecam, GarageGui, JailHud, Marker_DealerSign,
  Marker_StoreSign, OnboardingTip, OutlawHud, RobberyHud, SafeZoneHud, WantedHud — no CombatStatus. Screenshot 🟦 (MCP screen_capture timed out twice in play mode).
R1 EXIT: tests 270 ≥ 240 ✅ · 2-client dispatch recorded ✅ · warnings 🟦
BACKUP/RESTORE POINT: ServerStorage.Backups["R1.8 passed"] (Backups now ~1.7k instances; prune/remove before publish — S2.10 package)
MIRROR: Studio = src/ 121/121, manifest de531378 · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: S2.1
```

## CHECKPOINT: S2.1 SpreeRules · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 289 passed, 0 failed (+ SpreeRules.spec 19) · SCRIPT ANALYSIS: 🟦 · 124/124 parse
PLAY TEST (clients: 1): runner only (pure rules; no runtime change)
BACKUP/RESTORE POINT: ServerStorage.Backups["S2.1 passed"]; pruned R1.1–R1.7 (D-015) — kept R0 baseline, R1.8 passed, S2.1 passed
MIRROR: Studio = src/ 124/124, manifest 293950ef · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: S2.2
```

## CHECKPOINT: S2.2 SpreeService + HUD · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 294 passed, 0 failed (+ SpreeBank.spec 5) · SCRIPT ANALYSIS: 🟦 · 127/127 parse
PLAY TEST (clients: 1):
  robbery 1 → "holdout complete; +2000 to the spree" → counter "$2,000 UNBANKED x1.5"
  BankSpree (dev) → "bank spree 2000 (tx spree:6f18…) -> 19400 (stored)"; card "BANKED $2,000 · 1 crimes ★★ 6s · Best spree: $2,000 +2 rep";
    attributes BestSpree 2000, Reputation 2; analytics FirstBank + SpreeEnded 2000
  robbery 2 → analytics "Again"; +2000 unbanked → stood on the road → police BUSTED in 4.1 s → "spree lost (Busted), -2000";
    card "BUSTED -$2,000 · Your banked cash is safe"; cash stayed 19400; "bust (tx bust:73b6…) stored"; analytics FirstBust
  Console: 0 game errors.
KNOWN: stars don't reset after a bank yet (S2.4 adds the 10 s decay on bank); result card positions untested on phones (S2.7).
BACKUP/RESTORE POINT: ServerStorage.Backups["S2.2 passed"] (S2.1 pruned)
MIRROR: Studio = src/ 127/127, manifest c263a0d2 · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: S2.3
```

## CHECKPOINT: S2.3 CrimeConfig + CrimeService · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 304 passed, 0 failed (+ CrimeRules.spec, CrimeSites.spec; RobberyRules.spec green via the store definition) · SCRIPT ANALYSIS: 🟦 · 132/132 parse
PLAY TEST (clients: 1, scripted ExecuteMultiplayerTestAsync(1, "S2.3-Crimes")):
  sites ATM1–4, Gas1, Store1; parked spots Parked1–6 filled at boot
  ATM1 holdout completes → spree +1 crime; ATM2 left its area mid-holdout → failed, spree unchanged;
  Gas1 holdout completes → spree +1; Parked3 stolen → spree +1, the car becomes the thief's getaway car; second steal of the empty spot refused
  verdict: "PASS 3 crimes completed (spree 3 crimes, 4050 unbanked), failed ATM paid nothing, empty spot refused"
  (4050 = 800×1.0 + 1500×1.5 + 500×2.0, matching SpreeConfig)
  Console (solo play): runner line, 0 game errors; sampler summaries 0 observations.
WORLD: ATMs, gas station and parked cars are built at server start; the saved place has no new geometry, so rollback = restore point.
KNOWN: crime HUD texts and the silent-alarm toast not screenshot-checked on phones (S2.7); prompts exercised through the server API, not by pressing E.
BACKUP/RESTORE POINT: ServerStorage.Backups["S2.3 passed"] (S2.2 pruned)
MIRROR: Studio = src/ 132/132, manifest e0fc2ef4 · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: S2.4
```

## CHECKPOINT: S2.4 Safehouses · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 312 passed, 0 failed (+ Safehouse.spec 8) · SCRIPT ANALYSIS: 🟦 · 136/136 parse
PLAY TEST (clients: 1, scripted ExecuteMultiplayerTestAsync(1, "S2.4-Safehouses"), dispatch held):
  boot: City.Safehouses.Garage and .Warehouse built (7 instances each)
  Garage: ATM spree → stood inside → banked after 4.75 s (poll granularity 0.25 s), cash + exactly the unbanked amount
  Warehouse: ATM spree + 1★ + police sight on → after 4 s BankBlocked=Seen, BankProgress=0, spree still active;
    sight off → banked after 5.00 s; stars 0 after 10.62 s (includes the save before the cool-down starts); 0 Escaped events
  repeat: SpreeService.bank → NothingToBank; EconomyService.bankSpree same spree id → DuplicateTransaction; cash unchanged
  verdict: "PASS garage banked after 4.75 s, warehouse blocked in sight then banked after 5.00 s, stars 0 after 10.62 s, 0 escapes, repeat claims refused"
WORLD: both safehouses are built at server start; the saved place has no new geometry, so rollback = restore point.
KNOWN: markers and the bank bar not screenshot-checked (screen_capture times out in play; phone sizes in S2.7); a real police unit blocking a bank is covered by the sight override, not a live chase.
BACKUP/RESTORE POINT: ServerStorage.Backups["S2.4 passed"] (S2.3 pruned)
MIRROR: Studio = src/ 136/136, manifest 89c2ccf3 · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: S2.5
```

## CHECKPOINT: S2.5 Police escalation · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 315 passed, 0 failed (PoliceDispatch.spec: units 1-2-3, allocate under the cap, held players, roadblock spot) · SCRIPT ANALYSIS: 🟦 · 136/136 parse
PLAY TEST (scripted, Studio multi-client; not real network):
  S2.5-Escalation (clients: 3): stars 3/2/1 → units 3/2/1 (server at the cap of 6) + roadblock ahead of the 3★ player;
    A cleared + C raised to 3★ → units 0/2/3 using A's recalled units, never above 6; A's roadblock removed
    verdict: "PASS 3/2/1 units + roadblock at 3 stars; A's units re-targeted to C (0/2/3), never above 6; 48 raycasts/frame max, 0.306 ms avg, 1.225 ms max per frame"
  R1.6-Dispatch (clients: 2, updated): "PASS B heat held at 70.0; B got its own unit after 0.25 s while A kept 2"
  regression: S2.4-Safehouses PASS (scenario now re-holds dispatch after each ATM; stars 0 after 10.93 s incl. the save), S2.3-Crimes PASS
NUMBERS: police budget ≤ 50 raycasts/frame → 48 max (6 units × 4 wheel + 3 whisker rays + sight checks); ≤ 2 ms → 0.306 ms avg, 1.225 ms max per frame (Studio server, 3 clients)
KNOWN: 48/50 rays is close to the budget (risk register row added); roadblocks only on grid roads (none on the highway or connectors); the siren stays off until the owner gives an asset (S2.6).
BACKUP/RESTORE POINT: ServerStorage.Backups["S2.5 passed"] (S2.4 pruned)
MIRROR: Studio = src/ 136/136, manifest 10d98ac0 · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: S2.6
```

## CHECKPOINT: S2.6 Audio (built, 🟦 IDs pending owner) · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 319 passed, 0 failed (+ AudioRules.spec 4) · SCRIPT ANALYSIS: 🟦 · 141/141 parse
PLAY TEST (clients: 1): console "[Audio] waiting for approved Roblox-owned IDs: Alarm, Bank, Bust, Engine, Siren, Tyre (assets/ART_SOURCES.md)"; 0 Siren/Alarm Sound instances created (none approved); 0 game errors.
ATTENUATION: spec-checked (InverseTapered, RollOffMin < RollOffMax ≤ 500 studs); not heard, no ID approved.
OWNER: item 4 (sound IDs). Nothing plays until then; nothing else waits on it.
BACKUP/RESTORE POINT: ServerStorage.Backups["S2.6 built"] (S2.5 passed kept)
MIRROR: Studio = src/ 141/141, manifest 8e6edbf5 · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: S2.7
```

## CHECKPOINT: S2.7 HUD UIScale (built, 🟦 screenshots) · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 323 passed, 0 failed (+ HudLayout.spec 4: no slot overlaps at iPhone 7 / 13 Pro Max landscape, cash in row 1, stack fits at scale ≥ 0.9) · SCRIPT ANALYSIS: 🟦 · 145/145 parse
PLAY TEST (clients: 1, Studio window 2004x499): every HUD ScreenGui has Root + UIScale (scale 1.000 at this size); slots read back at their HudLayout positions
  (Badge 838,8 · Cash 1058,8 · SpawnButton 1006,42 · Counter 852,92 · Banner 842,132 · Pop 852,166 · BankBar 852,196 · Panels 852,226 · Toasts 832,306 · Tip 12,92); 0 game errors
NOT DONE: Device Simulator screenshots at iPhone 7 and iPhone 13 Pro Max. The MCP can't switch the Device Simulator and screen_capture times out in play mode. Spec math assumes a 36 px top inset. Owner check: Test → Device → iPhone 7, Play, look at the top of the screen.
BACKUP/RESTORE POINT: ServerStorage.Backups["S2.7 built"] (S2.6 built pruned; S2.5 passed kept)
MIRROR: Studio = src/ 145/145, manifest 4ace314b · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: S2.8
```

## CHECKPOINT: S2.8 First session (built, 🟦 fresh-account timings) · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 327 passed, 0 failed (+ FirstSession.spec 4) · SCRIPT ANALYSIS: 🟦 · 146/146 parse
PLAY TEST: S2.8-FirstSpree (clients: 1): "PASS first spree: unit after 10.4 s (delay 10 s); later spree: unit after 0.1 s" (profile spree count set in memory, put back)
  solo play: markers "24/7 MART · 80 studs", "ATM · 70 studs | Open: smash it" (nearest only), two SAFEHOUSE signs; tip "Rob an ATM or the store, then bank it at a SAFEHOUSE." fits its card
NUMBERS (geometry from FirstSession.spec, not player timings): nearest crime 121 studs from the plaza (~8 s on foot); any crime site within ~512 studs of a safehouse (~9 s at Coupe cruise)
NOT DONE: first crime ≤ 60 s / first result ≤ 4 min median over 5 fresh accounts needs real players: carried to the S3 private test.
BACKUP/RESTORE POINT: ServerStorage.Backups["S2.8 built"] (S2.7 built pruned; S2.5 passed kept)
MIRROR: Studio = src/ 146/146, manifest 6828559b · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: S2.9
```

## CHECKPOINT: S2.9 Leaderboards + objectives · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
TESTS: [Tests] 336 passed, 0 failed (+ Leaderboard.spec 5, Objective.spec 4) · SCRIPT ANALYSIS: 🟦 · 155/155 parse
PLAY TEST (clients: 1, scripted ExecuteMultiplayerTestAsync(1, "S2.9-Boards"), dispatch held):
  3 ATM sprees banked at the garage → today's objective "Bank 3 sprees" paid once (+1500, ledger tx objective:<day>:Bank3);
  a 4th bank paid only the spree (no second reward); submissions written to the studio- scopes; refresh → daily board #1 800, all-time ≥ best
  verdict: "PASS objective paid once (1500 after 3 banks), extra bank paid no reward, daily board #1 800"
  solo play: TOP button at (12,42); objective attributes "Bank 3 sprees 0/3"
RESET ON SCHEDULE: spec-checked (daily scope changes at 00:00 UTC, weekly on Monday 00:00 UTC, all-time never); not observed live across a midnight.
NOTE: the multi-client test server's saves did not show in the next solo Play (cash 19400 both times), so cross-session persistence of objective progress is not verified in Studio.
DECISION: D-016 (board shape, objective list and rewards) taken unattended on the architecture's recommendation — flagged for you.
BACKUP/RESTORE POINT: ServerStorage.Backups["S2.9 passed"] (S2.8 built pruned; S2.5 passed kept)
MIRROR: Studio = src/ 155/155, manifest be462bbe · APPROVAL: auto-approved (unattended) · PUBLISHED BY OWNER: n.a.
NEXT: S2.10 (publish substage: package for the owner)
```

## S2.10 — READY FOR OWNER TO PUBLISH · 2026-10-16

I never publish. Everything below is for you to do in the Outlaw City Studio window (place 132163592957463). Nothing in S2 needs the live build except this step; S3 starts after it.

**Build state:** S2.1–S2.9 in Studio and on `main` (commit after 19d3c81). `[Tests] 336 passed, 0 failed` at the last Play. Studio-only tools stay off in live servers (DevTools, LoopGuardControl, test scenarios and milestone logs all check `RunService:IsStudio()`).

**Before you publish**
1. **Download a copy** of the place first (File → Download a Copy), e.g. `OutlawCity_S2_before_publish_2026-10-16.rbxl`, kept outside the repo.
2. **Move `ServerStorage.Backups` out** so the restore points don't ship: in the Explorer, cut `ServerStorage.Backups` and paste it into the downloaded copy, or just delete it from the place you publish (git `src/` holds every checkpoint's scripts; R0 baseline also holds the original world).
3. **MaxPlayers = 8** (D-005): Game Settings → Places → Outlaw City → Max Players 8 (Studio reports 60 today).
4. **Sounds (optional for a private publish):** the game is silent until you approve sound IDs (owner item 4). It plays fine without them.
5. **Check the HUD on a phone size** (owner item 7) if you want to before players see it.

**Store page**
- **Title** (A/B/C, from architecture.md): A `Crime Spree 🚔 Outlaw City` · B `Outlaw City: Crime Spree` · C `Outlaw City 🚔 Rob, Run, Bank`. Start with A; S3.1 tests the others.
- **Description (draft):** "Rob ATMs, gas stations and the 24/7 MART to start a Crime Spree. Every crime raises your multiplier — and your wanted level. Bank your unbanked cash at a safehouse before the police bust you, or lose it all. Climb the daily, weekly and all-time Biggest Spree boards. Buy faster cars at OUTLAW MOTORS. Up to 8 players."
- **Icon:** not made (owner item 5: pick sunset orange or night blue). Brief: muscle car mid-drift, three cruisers with light bars behind, "$12,400" floating above, no other text (ART_BIBLE).
- **Thumbnails (3, 16:9):** 3★ roadblock escape on the highway; the ATM smash with the counter; the safehouse bank moment ("BANKED $9,600"). I can stage these shots in Studio on request; I can't upload them.

**Publish**
6. File → Publish to Roblox, **private first** (only you). Play once on PC and once on a phone: start a spree at an ATM, bank it at the Old Town Garage, open TOP.
7. Tell me "published" and the version number; I record it here. Making it public is S3.1.

**After publishing:** S3 needs the live game and real players (public test, outside sessions, the real-phone check). S3.6 is a GO/NO-GO gate where I stop and wait for you.

## CHECKPOINT: S2 exit soak · 2026-10-16 · STUDIO: placeId 132163592957463 verified
```text
SOAK (Studio multi-client, clients: 8, scripted ExecuteMultiplayerTestAsync(8, "S2-Soak"); not real network):
  "PASS 30 min, 8 clients: crimes 102, steals 20, bank trips 214, runs 240; server errors 0; failed loop iterations 0; police max 6 units, 48 rays/frame, 0.276 ms avg / 1.549 ms max per frame; worst server frame 423 ms; memory 1683 -> 1753 MB"
S2 EXIT NUMBERS: 8-client 30-min soak with 0 server errors ✅ · 3★ police budget (≤ 50 rays/frame, ≤ 2 ms) ✅ 48 / 0.276 ms avg, 1.549 ms max ·
  first crime ≤ 60 s and first result ≤ 4 min: 🟦 need real players (S3); geometry says ~8 s to the nearest crime from the plaza
NOTES: client-side errors in the 8 test clients aren't visible to the server-side counter; the 423 ms worst server frame is one spike with 9 Studio
  instances on one PC (not investigated further); the memory figure is the test server's total.
BACKUP/RESTORE POINT: ServerStorage.Backups["S2 exit"] (R1.8 passed and S2.5 passed pruned; R0 baseline and S2.9 passed kept)
MIRROR: Studio = src/ 155/155, manifest c78f3dc6
NEXT: owner publishes (S2.10 package above). S3 needs the live game and real players; S3.6 is a GO/NO-GO gate. I'm stopped here.
```

## Publish prep done for the owner · 2026-10-16
- ✅ `ServerStorage.Backups` removed from the place (git keeps every checkpoint).
- ✅ HUD at phone sizes, checked in the engine: iPhone 7 safe area 667×317 (scale 0.916) and iPhone 13 Pro Max 926×370 (scale 1.0), 13 HUD elements, 0 overlaps, none off screen. Real top bar inset is 58 px; spec updated.
- ✅ D-016 reviewed and kept.
- ⏸ Sounds: candidates load in this place; wiring waits for the owner's yes (they are from Roblox's licensed library, not uploaded by the Roblox account): Siren 9119165420 "Siren Yelp 1 (SFX)" · Engine 80317022777602 "Car-Engine-Loop" (verified group Roblox Resources) · Tyre 9120399077 "Vehicle Skids Long Heavy Tire Squeal 3 (SFX)" · Alarm 9113084849 "Alarm Bell On Carpet Constant Ring 1 (SFX)" · Bank 9113728042 "Cash Register 1 (SFX)" · Bust 9117907414 "Prison Door 2 (SFX)". All ProSoundEffects except the engine.
- ❌ Not possible from here (Studio menus, no script API): MaxPlayers 8 (Game Settings → Places), File → Download a Copy, File → Publish to Roblox.

## Owner published · 2026-10-16
- Published privately by the owner; backup copy `10162026-backup1.rbxl` saved.
- Sounds approved (D-017) and wired after that publish, so they ship with the **next** publish (File → Publish to Roblox again). Tested in Studio: siren, alarm, bank sting, engine, tyre.
- **MaxPlayers 8, still open.** Studio: Home → Game Settings → Places → hover "Outlaw City" → the `⋯` button → Edit → Max Players = 8 → Save. Or the Creator Hub: create.roblox.com → Creations → Outlaw City → Places → Outlaw City → Server Size / Max Players = 8.
- Still open: icon and 3 thumbnails (owner item 5), archive the old repo (owner item 6).
