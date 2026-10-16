# Outlaw City — Production Roadmap

**Companion to:** `architecture.md` v2.0 · **Audit:** `docs/AUDIT_2026-10-16.md`
**Toolchain:** Roblox Studio + Studio MCP; `src/` export per checkpoint; TestRunner at every play; Studio multi-client tests.
**Estimates:** ~5 days/week; to public test (S3) **~6 weeks**; to launch (L1) **~14–18 weeks**. Checkpoints are fixed; durations are guesses.

---

## 0. How to use this document

Status: `⬜` not started · `🟨` in progress · `🟦` checkpoint pending (publish or owner item) · `✅` passed · `🟥` blocked.

### Checkpoint protocol — every substage, all 8
1. **Tests:** Studio play starts the runner; `[Tests] N passed, 0 failed` pasted.
2. **Static:** zero Script Analysis warnings in touched modules.
3. **Play test:** steps run; `get_console_output` zero errors; `screen_capture` for UI. Multi-client runs via Studio Test → Clients where the substage says so.
4. **Numbers:** every metric named is measured and written down.
5. **Backup:** owner `.rbxl` confirmed in the Studio log ("Place file downloaded") at stage starts; restore point `<ID> passed`.
6. **Mirror:** `src/` export, hash-checked, committed with the substage ID.
7. **Handoff record** appended to `docs/HANDOFF_REPORT.md` (§14 template).
8. **Approval line** in `docs/DECISION_LOG.md` (auto-approved in unattended mode except publish substages and gates).

### Studio safety (every substage, first action)
`list_roblox_studios` → PlaceId **132163592957463** → never act on another instance (Lighthouse Keepers, DEADZONE, test places).

---

## 1. Master tracker

| Stage | Name | Substages | Weeks | Gate | Status |
|---|---|---|---|---|---|
| R0 | Re-baseline | 5 | 0.5 | Decisions | ✅ |
| R1 | Integrity | 8 | 1.5 | Numeric | ✅ (static 🟦; R1.7 dashboard 🟦) |
| S2 | Signature: Crime Spree | 10 | 3 | Numeric + owner publish | 🟨 |
| S3 | **Public test** | 6 | 2–3 live | **GO/NO-GO** | ⬜ |
| S4 | Content and progression | 8 | 3–4 | Standard | ⬜ |
| S5 | Multiplayer and co-op | 6 | 2–3 | Numeric | ⬜ |
| B1 | **Closed beta** | 5 | 2 | **GO/NO-GO** | ⬜ |
| L1 | Launch | 6 | 2 | Checklist | ⬜ |
| LO | Live ops | — | — | Cadence | ⬜ |

---

## 2. Stage R0 — Re-baseline (3 days)

| ID | Substage | Deliverables | Passes when | Verify | Status |
|---|---|---|---|---|---|
| R0.1 | Decisions | D-001 Crime Spree · D-002 police 1→3 by stars · D-003 siren on (Roblox-owned asset) · D-004 integrity layer (character sampler gates payouts; vehicles stay monitor-only) · D-005 MaxPlayers 8 · D-006 freeze N4/world polish · D-007 checkpoint protocol · D-008 unattended mode | All logged Accepted or Declined | Owner | ✅ |
| R0.2 | Repository | New repo with this docs set at root; `src/`, `tests/` as today; old `docs/` under `docs/legacy/`; old repo archived | Tree matches `architecture.md` §4.3 | Repo | ✅ |
| R0.3 | Studio baseline | Production window verified; export all 98 scripts; hash-check against `src/`; restore point `R0 baseline`; owner `.rbxl` | Hashes equal; restore point exists | Studio | ✅ (104 scripts; owner `.rbxl` 🟦) |
| R0.4 | Owner items | MaxPlayers 8 in Game Settings; siren asset ID chosen from Roblox audio; title/icon direction (`ART_BIBLE.md`) | Written in the handoff record | Owner | ✅ (items 🟦 with owner) |
| R0.5 | Pending batch closure | c4bebb5 recorded as approved-with-conditions and frozen (D-006) | Line in `DECISION_LOG.md` | — | ✅ |

---

## 3. Stage R1 — Integrity (1.5 weeks)

| ID | Substage | Deliverables | Passes when | Verify | Status |
|---|---|---|---|---|---|
| R1.1 | Loop isolation + lifecycle | `pcall` per iteration in the six loops with backoff; `JailService.release` guards `player.Parent`; module-scope connections moved into `start()` | Injected error in each loop → loop continues, error reported once; jail still releases | Tests with fakes, play test | ✅ |
| R1.2 | Persistence fixes | Lock released on leave-during-load (F6); `Corrupt` for non-table / `{Lock}`-only (F9); ledger removes batched (F10); profile v4 schema + migration + fixture | `ProfileStore.spec` +4; `ProfileSession.spec` +2; migration fixture; no double-apply in the traced paths | TestRunner | ✅ |
| R1.3 | Character sampler | `CharacterValidationRules` + `CharacterValidationService` (5 Hz, on-foot speed/displacement caps, non-finite); observations logged; `ObservedAt` attribute | Spec: 3 min of generated normal play → 0 observations; 100-stud hop → observation; NaN rejected | TestRunner | ✅ |
| R1.4 | Payout gating | Robbery start/holdout/escape refused when observed in the last 10 s; holdout validated with `GetPartBoundsInBox`; `AlreadyPaid` shows the toast (F13) | Spec: observed player → `Rejected:Observed`; holdout outside the area box fails `LeftArea` even if the root claims inside | TestRunner, play test | ✅ |
| R1.5 | Spawn restrictions | No spawn while wanted / in a crime / unbanked > 0; spawn within 30 studs; pad clearance includes characters | Spec + play test: V at 2★ → `Wanted`; V with a player on the pad → next pad | TestRunner, play test | ✅ |
| R1.6 | Dispatch re-target + decay freeze | Unit follows its player; a wanted player with no unit freezes decay; 2-client Studio test | 2 clients: A rams, B robs → B's heat does not decay until a unit sees or is assigned | Studio 2 clients | ✅ |
| R1.7 | Event bus + analytics | `EventBus`; the two hidden wires replaced; `AnalyticsService` funnel (`Joined`, `FirstCar`, `FirstCrime`, `FirstBank`, `FirstBust`, `SpreeEnded`, `Again`, `Left`) | Funnel events visible in the Analytics dashboard after a play test | Analytics | 🟦 (Studio ✅; dashboard check needs the first owner publish) |
| R1.8 | Combat button hidden | Hidden until damage exists (flag) | Not present in HUD; spec unchanged | Play test | ✅ |

**R1 exit:** TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded; 0 warnings. → S2.1.

---

## 4. Stage S2 — Signature: Crime Spree (3 weeks)

| ID | Substage | Deliverables | Passes when | Verify | Status |
|---|---|---|---|---|---|
| S2.1 | SpreeRules | Pure: unbanked, multiplier (+0.5/crime, cap 4), bank conditions, loss on bust, escape keeps the spree, reputation at bank | Spec ≥ 15 cases incl. caps and NaN | TestRunner | ✅ |
| S2.2 | SpreeService + HUD | Server spree state; `SpreeHudController` (unbanked counter, multiplier, stars in row 1); result card with Again | Play test: ATM → counter → bank → cash; bust → loss shown | Play test | ✅ |
| S2.3 | CrimeConfig + CrimeService | Generic holdout engine; store robbery migrated as a definition; ATM ×4, gas station ×1, car theft ×6 NPC cars | Each crime: start/validate/complete/fail paths in spec; `RobberyRules.spec` still green via the definition | TestRunner, play test | ✅ |
| S2.4 | Safehouses | Two zones; 5 s no-sight bank; idempotent grant `spree:<id>`; markers | Spec: bank once; duplicate claim refused; play test bank from both | TestRunner, play test | ✅ |
| S2.5 | Police escalation | `UnitsByStars {1,2,3}`, server cap 6, re-target, roadblock at 3★ | 3★ → 3 units + roadblock; budget ≤ 50 raycasts/frame; ≤ 2 ms | Profiler | ✅ |
| S2.6 | Audio | Siren (owner asset), engine loop, tyre, alarm, bank, bust; `AudioConfig`; `ART_SOURCES.md` | All IDs Roblox-owned and listed; distance attenuation | Play test | ⬜ |
| S2.7 | HUD UIScale | Root `ScreenGui` + `UIScale`; two rows; Device Simulator iPhone 7 + 13 Pro Max | No overlap at either size; cash in row 1 | Screenshots | ⬜ |
| S2.8 | First session | Protected first spree (10 s dispatch delay for 0-run); markers to nearest ATM/store/safehouse; tip text | 5 fresh accounts: first crime ≤ 60 s, first result ≤ 4 min median | Console timestamps | ⬜ |
| S2.9 | Leaderboards + objectives | Biggest Spree daily/weekly/all-time; one daily objective, no streak | Submit/read; reset on schedule; objective once | TestRunner, play test | ⬜ |
| S2.10 | Store assets + publish (owner) | Title A/B/C; icon; 3 thumbnails; description; owner publishes (private first, then public at S3) | Assets uploaded; published | Owner | ⬜ |

**S2 exit numbers:** first crime ≤ 60 s; first result ≤ 4 min; 3★ budget; 8-client Studio soak 30 min, 0 errors. → S3.

---

## 5. Stage S3 — PUBLIC TEST (2–3 weeks) — GO/NO-GO

| ID | Substage | Deliverables | Passes when |
|---|---|---|---|
| S3.1 | List publicly + diagnostic ads; icon/title A/B via flags | Playthrough per variant after 48 h |
| S3.2 | 5 outside sessions incl. 2 phones, one unassisted | Observer sheets; funnel |
| S3.3 | Two weekly iterations (balance: bust rate, multiplier, police) | Shipped; logged |
| S3.4 | Signal read: bounce, D1, co-play, qualified sessions; spree completion, bank rate, bust rate | Written review |
| S3.5 | Real-phone check by the owner | Recorded |
| S3.6 | Go/no-go | Logged |

**GO:** ≥ 50% of new players start a second spree · bust rate 30–60% · first result ≤ 4 min median · bounce down week 2 vs 1. **NO-GO:** second-spree rate < 30% after two passes → back to S2 (loop). **Shelve review:** < 20% after three passes.

---

## 6. Stage S4 — Content and progression (3–4 weeks)
S4.1 Sport + Super cars · S4.2 paint customization (server-stored) · S4.3 reputation tiers + unlocks · S4.4 safehouse upgrades · S4.5 second store + 2 ATMs + district flavour · S4.6 NPC traffic (light, server-stepped, ≤ 10) · S4.7 jail SpawnLocation fix (F11) · S4.8 publish (owner). Exit: content ≥ 2 hours; budgets hold.

## 7. Stage S5 — Multiplayer and co-op (2–3 weeks)
S5.1 Ram damage through `canPlayerHarm` (Combat opt-in returns) · S5.2 co-op spree (shared multiplier, split bank) · S5.3 friend announcements · S5.4 8-client soak 2 h · S5.5 `MULTIPLAYER_TESTS.md` closed item by item · S5.6 publish (owner). Exit: memory < 50 MB/h; 0 save failures.

## 8. Stage B1 — Closed beta (2 weeks) — GO/NO-GO
B1.1 cosmetics pipeline (paints, liveries, horns; products created, not enabled) · B1.2 age rating · B1.3 security suite (spam, spoof, character teleport) · B1.4 30–100 testers · B1.5 go/no-go. **GO:** 0 blocking bugs; D1 and co-play baseline; second-spree ≥ 50%.

## 9. Stage L1 — Launch (2 weeks)
L1.1 economy balance (10,000-spree sim) · L1.2 data audit + admin tools · L1.3 monetization enabled (owner) · L1.4 codes · L1.5 store final + trailer · L1.6 checklist, restore point, **owner publishes**.

## 10. Stage LO — Live ops
Weekly Friday update (crime, car, paint set, event spree with ×2 multiplier); monthly district or mode; quarterly re-baseline. Biweekly floor.

---

## 11. Risk register
| Risk | Signal | Response |
|---|---|---|
| Spree isn't fun | S3 second-spree < 30% | Tune multiplier/bank time; if still < 30%, shelve review |
| Police too hard/easy | bust rate outside 30–60% | `PoliceConfig` tuning per star; dispatch delay |
| Phone FPS in 3★ chase | < 30 FPS | cap units at 2 on touch-majority servers |
| Police raycast budget at the 6-unit cap | S2.5 measured 48 of 50 per frame (6 units × 7 rays + sight checks) | count sight checks per tick, not per frame, or drop the centre whisker when a unit is in direct chase |
| Portfolio bandwidth | three games | run OC third; park at any stage without loss |
| Wrong Studio window | any | stop, re-identify, log |

## 12. Checkpoint record template
```text
CHECKPOINT: <ID> <name> · DATE · STUDIO: placeId 132163592957463 verified
TESTS: [Tests] N passed, 0 failed · SCRIPT ANALYSIS: 0 warnings
PLAY TEST: <steps> (clients: n) → result, console errors 0
NUMBERS: ...
BACKUP/RESTORE POINT · MIRROR COMMIT · APPROVAL (auto/owner) · PUBLISHED BY OWNER: yes/no/n.a.
NEXT: <ID>
```

**Mode:** unattended (D-008) · **Current substage:** S2.6 · **Last checkpoint passed:** S2.5
