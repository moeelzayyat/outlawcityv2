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
