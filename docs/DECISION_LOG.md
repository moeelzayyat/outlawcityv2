# DECISION LOG

Append-only. Checkpoint approvals: `## CP — <ID> passed · <date> · auto-approved (unattended) | approved by owner · published by owner: yes/no`.

## D-001 — Signature: Crime Spree
2026-10-16 · R0 · **Accepted**
Context: the game has no element that is only its own; the loop is exhausted in one session (audit §3).
Decision: unbanked cash with a rising multiplier (+0.5/crime, cap 4.0), banked only at a safehouse after 5 s without police sight, lost on bust; police escalate with stars; **escaping no longer pays — banking pays**; reputation earned at bank. Biggest Spree leaderboards.
Alternatives: more city/content without a loop change (rejected: incumbents win that race); co-op heists first (rejected: needs PvP/multiplayer before any player data); shelve (the honest fallback if S3 fails).
Consequences: `RobberyService` becomes a `CrimeConfig` entry; the 4B "escape pays" rule is superseded.
Approved by: owner (2026-10-16, accepted all eight recommendations; unattended mode)

## D-002 — Police units scale with stars (1→3), re-target each tick
2026-10-16 · R1/S2 · **Accepted**
Context: one unit never re-targets; the second wanted player escapes free (audit F2, verified `PoliceService.luau:243-259`).
Decision: `UnitsByStars = {1, 2, 3}` per player, server cap 6, re-target each tick, heat frozen for un-chased wanted players; roadblock at 3★. Budget measured in S2.5 (≤ 50 raycasts/frame, ≤ 2 ms).
Approved by: owner (2026-10-16, accepted all eight recommendations; unattended mode)

## D-003 — Siren on with a Roblox-owned asset
2026-10-16 · S2 · **Accepted**
Decision: the owner picks the asset ID (Roblox audio library); distance-attenuated; `AudioConfig`.
Approved by: owner (2026-10-16, accepted all eight recommendations; unattended mode)

## D-004 — Integrity layer
2026-10-16 · R1 · **Accepted**
Decision: a character sampler mirrors `VehicleValidationRules`; observations are logged; **payout-bearing actions (crime start/holdout/bank) are refused for players observed in the last 10 s**; holdouts validated by server bounds; vehicle spawn refused while wanted / in a crime / with unbanked cash. Vehicles stay monitor-only; nobody is kicked or corrected.
Approved by: owner (2026-10-16, accepted all eight recommendations; unattended mode)

## D-005 — MaxPlayers 8
2026-10-16 · R0 · **Accepted**
Decision: Game Settings MaxPlayers = 8 (owner action); private servers on. The design (safehouses, crime cooldowns, police cap 6) is tuned for 8.
Approved by: owner (2026-10-16, accepted all eight recommendations; unattended mode)

## D-006 — World polish frozen
2026-10-16 · R0 · **Accepted**
Decision: N4 Stages B–D, sign enlargement (c4bebb5: approve-with-conditions as a change, not executed), connector signs, further markings and district decoration are frozen until S3 data shows players get lost. The 4 existing signs and 50 stop lines stay.
Approved by: owner (2026-10-16, accepted all eight recommendations; unattended mode)

## D-007 — Checkpoint protocol replaces per-task auditor packages; Studio multi-client testing replaces "solo only"
2026-10-16 · R0 · **Accepted**
Context: 27 packages / 498 files for a two-car prototype; the "solo only" policy predates the use of Studio's Test → Clients and Servers.
Decision: 8-step checkpoint; independent review at S3, B1, L1 only; 2–8-client Studio runs are standard evidence (not real-network evidence). Historical packages move to `docs/legacy/`.
Approved by: owner (2026-10-16, accepted all eight recommendations; unattended mode)

## D-008 — Unattended mode
2026-10-16 · R0 · **Accepted**
Decision: as `CLAUDE.md` §Unattended mode; publish substages and gates wait for the owner; everything else auto-approves and logs.
Approved by: owner (2026-10-16, accepted all eight recommendations; unattended mode)

## D-009 — Portfolio order (owner's call)
2026-10-16 · **Recorded recommendation, not a decision**
Recommendation: Lighthouse Keepers (unique, built, 4 weeks to public test) → DEADZONE (proven genre, clean plan) → Outlaw City (crowded genre, least content). Outlaw City can be parked at any checkpoint without loss; nothing in this plan depends on running it now.

## D-010 — Persistence stays home-grown
2026-10-16 · R1 · Accepted (design)
Decision: keep the tested `ProfileStore/ProfileSession/RewardLedger` stack with fixes F6/F9/F10; do not migrate to loleris ProfileStore. Revisit only if multi-server tests show lock contention.

## CP — R0.1 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
D-001…D-008 confirmed Accepted (owner, 2026-10-16). No Studio changes.

## CP — R0.2 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
Tree at 9a10c49 matches `architecture.md` §4.3 as built (additions arrive in R1/S2). Note: existing rules live in per-domain folders (`Shared/Robbery/RobberyRules` etc.), not `Shared/Rules/`; new rules modules go in `Shared/Rules/` per §4.3 and existing ones stay put (never move a registry item). Root `tests/` is byte-identical to `src/ServerStorage/Tests/` (26 files). Archiving `moeelzayyat/outlawcity` is an owner action (handoff record).

## CP — R0.3 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
Studio PlaceId 132163592957463 verified. 104 scripts in Studio = 104 in `src/` (the "98" in the roadmap predates the last batches); length + FNV-1a equal for every script, manifest hash `e4c1fd69` on both sides. Restore point `ServerStorage.Backups["R0 baseline"]` (Shared, Server, Tests, Client, Workspace.City, Lighting) matches live, script manifest `47bd2716`. Owner `.rbxl`: no "Place file downloaded" line in the current Studio log and no Outlaw City `.rbxl` on disk → owner item (handoff).

## CP — R0.4 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
Owner items written in `HANDOFF_REPORT.md`: MaxPlayers 8 (Studio currently reports `Players.MaxPlayers = 60`), siren asset ID, icon palette.

## R0.5 — Pending batch c4bebb5
2026-10-16 · R0 · **Recorded**
c4bebb5 (N4 sign enlargement plan) is approved-with-conditions as a change (audit §6: conditions a–d) and **not executed**; frozen under D-006.

## CP — R0.5 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.

## CP — R0 stage exit · 2026-10-16 · auto-approved (unattended)
`[Tests] 216 passed, 0 failed` (Studio play, 1 client, 2026-10-16). Next: R1.1.

## CP — R1.1 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
`Server/Util/LoopGuard` isolates all eight service loops (the audit's six + Economy autosave and ledger claims); Main pcalls every `init`/`start`; `JailService.release` checks `player.Parent`; MilestoneLog and PoliceService module-scope connections moved into `start()`. `[Tests] 224 passed, 0 failed`. Static: parse-checked; Script Analysis count not measurable through the MCP (🟦, handoff).

## D-011 — F10 scope: batch ledger removes; keep UpdateAsync reads
2026-10-16 · R1.2 · Accepted (unattended, recommendation)
Context: the audit's F10 fix lists "batch ledger removes into the next claim; GetAsync for reads".
Decision: removes are batched (a reward paid on the spot leaves the ledger on the next claim ≥ `LedgerSettleDelay` 10 s later, with no extra profile write). Reads stay on cancelled `UpdateAsync`: `GetAsync` is cached per server for ~4 s, which would let the reconcile-after-ambiguous-write path read a stale profile. Revisit only if the S3 live data shows write-budget pressure.

## CP — R1.2 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
F6 (lock released on leave-during-load via `ProfileStore.release`), F9 (`Corrupt` for non-table / lock-only records), F10 (batched ledger removes), profile v4 + v3→v4 migration + fixture (`ProfileMigration.spec`). `[Tests] 237 passed, 0 failed`. Live Studio migration: `loaded (Migrated) cash=11400`. Static 🟦 (parse-checked).

## CP — R1.3 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
`CharacterValidationRules` (`Shared/Rules`, first module in the v2.0 Rules folder) + `CharacterValidationConfig` + `CharacterValidationService` (5 Hz, monitor + `ObservedAt`). `[Tests] 244 passed, 0 failed`. Live: 0 observations across walking, car spawn/exit, jail and release; a 100-stud hop observed. Static 🟦 (parse-checked).

## D-012 — Vehicle observations stamp the driver's ObservedAt
2026-10-16 · R1.4 · Accepted (unattended, recommendation)
Context: architecture §7 / D-004: vehicles stay monitor-only "but the same observation flag gates payouts".
Decision: a VehicleValidation movement observation (Teleport, ExtremeTeleport, SustainedOverspeed, InvalidState) stamps the driver's `ObservedAt`; `OwnershipMismatch` (network-owner lag) does not. Cars are still never reset or corrected. Watch item: if honest chases get refused at S3, this stamp is the first suspect (3 lines in `VehicleValidationService.sampleAll`).

## CP — R1.4 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
Robbery start/holdout/escape refused for observed players (`Observed`); holdout uses `Server/Crime/AreaCheck` (bounds query over the character's parts); `AlreadyPaid` shows the toast (F13). `[Tests] 251 passed, 0 failed`. Static 🟦 (parse-checked).

## D-013 — "Spawn within 30 studs" keeps the one-tap car
2026-10-16 · R1.5 · Accepted (unattended, recommendation)
Context: pads exist only at the plaza (~47 studs from the civilian spawns) and the highway ends; a pad-only 30-stud rule would leave most of the map without a car.
Decision: the car goes on the nearest free pad within 30 studs, else on a clear spot beside the player within 30 studs (ground within ±8 studs of their feet, no collidable part in the car box). No far pads, ever. One tap still works anywhere with room.

## D-014 — Seat-exit grace judges big jumps (R1.3 hole found in R1.5)
2026-10-16 · R1.5 · Accepted (unattended, recommendation)
Context: the 2 s grace after leaving a seat skipped all judging, so "exit car → teleport" was free.
Decision: seat exit uses a loose grace — exit step and momentum allowed, but > 60 studs in one sample is a Teleport. Authorized server moves (spawn, jail cell) keep the full grace.

## CP — R1.5 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
`VehicleSpawnRules` + VehicleService placement; characters block spots (F14); HUD texts for Wanted / InCrime / Unbanked; seat-exit fix (D-014). `[Tests] 258 passed, 0 failed`. Static 🟦 (parse-checked).

## CP — R1.6 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
Unit keeps its player while wanted, re-targets (cancelling a pending despawn) to the most-wanted un-held player; wanted players with no unit have heat held (`PoliceDispatchRules.pickTarget/heatHeld`). Scripted 2-client scenario `R1.6-Dispatch`: PASS. `[Tests] 261 passed, 0 failed`. Static 🟦 (parse-checked).

## CP — R1.7 checkpoint · 2026-10-16 · auto-approved (unattended) · 🟦 dashboard item pending the first owner publish
`Shared/Util/EventBus` (catalog, plain payloads, isolated handlers) + `AnalyticsService` (onboarding funnel Joined/FirstCar/FirstCrime/FirstBank, custom FirstBust/Left; server error counter for LoopGuard/Main/bus). Hidden wires replaced: `setPoliceSightProvider` → `PoliceSight` events; `WantedService.Escaped` Signal → `Escaped` event. `[Tests] 269 passed, 0 failed`; R1.6 2-client scenario re-run PASS over the bus. "Funnel events visible in the Analytics dashboard" can't be met from Studio (Studio sends nothing) → 🟦 until the owner's first private publish.

## CP — R1.8 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
`CombatConfig.ToggleVisible = false`; CombatStatusController builds no GUI while off. `[Tests] 270 passed, 0 failed`; PlayerGui has no `CombatStatus`. Screenshot 🟦 (screen_capture times out during play).

## CP — R1 stage exit · 2026-10-16 · auto-approved (unattended)
TestRunner 270 ≥ 240, 0 failed ✅ · 2-client dispatch test recorded (R1.6 PASS ×2) ✅ · 0 Script Analysis warnings 🟦 (not measurable through the MCP; owner item 7). Next: S2.1.

## D-015 — Restore-point retention
2026-10-16 · S2.1 · Accepted (unattended, recommendation)
Context: one script snapshot per substage in `ServerStorage.Backups` grows the place (~1.7k instances after R1) and ships with every publish.
Decision: keep `R0 baseline`, the latest stage exit and the latest substage; every checkpoint's exact scripts stay recoverable from git (`src/`, hash-checked). World/geometry changes keep a dedicated restore point until the next stage exit. Before any owner publish, the whole `Backups` folder can be moved out (S2.10 package says how).

## CP — S2.1 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
`SpreeRules` + `SpreeConfig`; 19 spec cases (caps, rounding, NaN, bank conditions, bust, escape, reputation). `[Tests] 289 passed, 0 failed`. Static 🟦.

## CP — S2.2 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
SpreeService + SpreeHudController; robbery cash goes into the spree at holdout end (escape payout retired, D-001); `EconomyService.bankSpree` (ledger-recorded, tx `spree:<id>`, stats in the same write); `noteBust`; analytics FirstBank / SpreeEnded / Again. `[Tests] 294 passed, 0 failed`. Static 🟦. Banking uses the Studio `BankSpree` dev command until safehouses (S2.4).

## CP — S2.3 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
CrimeConfig + CrimeRules + CrimeService (replaces RobberyService; store migrated as a definition) and ParkedCarService. World additions named by S2.3 (D-006): ATM ×4, gas station ×1, parked cars ×6, all built at server start by WorldService/ParkedCarService (the saved place is unchanged, so the code restore point is the exact rollback). `[Tests] 304 passed, 0 failed`. Static 🟦. Scripted scenario `S2.3-Crimes` (1 client): PASS.

## CP — S2.4 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
SafehouseConfig + SafehouseService + SafehouseMarkerController; `WantedRules.coolDown` (stars fall to 0 over 10 s after a bank, no escape reward; a new crime cancels it); `PoliceService.sees`; `SpreeService.stepBank`. World additions named by S2.4 (D-006): Old Town Garage (-350, -200) and Highway Warehouse (-200, -420), built at server start (saved place unchanged; the code restore point is the exact rollback). `[Tests] 312 passed, 0 failed`. Static 🟦. Scripted scenario `S2.4-Safehouses` (1 client): PASS.

## CP — S2.5 passed · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
PoliceService is now a unit pool (D-002): `UnitsByStars {1,2,3}`, `ServerUnitCap 6`, `PoliceDispatchRules.allocate` (one unit each before seconds, highest stars first; held players keep units but get no new ones), recalled units re-targeted before new ones spawn, roadblock at 3★ (`roadblockSpot`, 250 studs ahead on the grid road, 30 s, 15 s cooldown), budget counters. `[Tests] 315 passed, 0 failed`. Static 🟦. Scenarios: `S2.5-Escalation` (3 clients) PASS, `R1.6-Dispatch` (2 clients, updated for the pool) PASS, `S2.4-Safehouses` and `S2.3-Crimes` re-run PASS. Budget measured: 48 raycasts/frame max, 0.306 ms avg / 1.225 ms max per frame.

## CP — S2.6 built (🟦) · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
AudioConfig + AudioRules + AudioService (siren on every unit, alarm at an alarmed crime site) + AudioController (engine pitch by speed, tyre squeal on slide, bank / bust stings); positional sounds fade with distance (InverseTapered). No sound ID is set: no Creator Store result was uploaded by the `Roblox` account, so the Roblox-owned rule can't be confirmed for any candidate; every sound stays silent until the owner approves IDs (candidates in `assets/ART_SOURCES.md`). `[Tests] 319 passed, 0 failed`. Static 🟦. Pass item "all IDs Roblox-owned and listed" 🟦 owner.

## CP — S2.7 built (🟦) · 2026-10-16 · auto-approved (unattended) · published by owner: n.a.
HudLayout (design-pixel slots) + HudRules (scale, overlap) + UiRoot (Root frame + UIScale per HUD ScreenGui, sized 1/scale so centred elements stay centred). Row 1 = safe-zone badge, stars, cash; row 2 = buttons; one stacked slot each for spree counter, banner, pop, bank bar, robbery/jail panel, toast; onboarding tip moved to a narrower left column. Fixed overlaps found on the way: wanted banner vs spree counter (both y 96), robbery panel vs pop and bank bar, vehicle toast vs pop. Robbery panel no longer switches to the compact layout (UIScale handles short screens; `robberyPanelLayout` kept). `[Tests] 323 passed, 0 failed`. Static 🟦. Device Simulator screenshots 🟦: the Studio MCP can't drive Device Simulator or capture in play mode.
