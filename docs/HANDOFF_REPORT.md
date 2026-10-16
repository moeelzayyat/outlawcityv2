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
4. **Siren asset ID** (D-003): pick a siren from the Roblox-owned audio library (creator "Roblox") and send me the ID; needed by S2.6.
5. **Icon palette** (`ART_BIBLE.md`): sunset orange or night blue; needed by S2.10.
6. **Archive the old repo** `moeelzayyat/outlawcity` on GitHub (Settings → Archive this repository). It is history only.

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
