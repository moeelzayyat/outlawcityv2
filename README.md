# Outlaw City

Mobile-first open-world crime game for Roblox. Build a **Crime Spree** — unbanked cash that grows with every crime while the police escalate — and bank it at a safehouse before they bust you.

**Studio place:** 132163592957463 (unpublished) · **Owner publishes.**
**Repository:** https://github.com/moeelzayyat/outlawcityv2 · **Local:** `C:\RobloxProjects\OutlawCityv2` · old repo `moeelzayyat/outlawcity` = history (`docs/legacy/`).

| File | Purpose |
|---|---|
| `architecture.md` | Master architecture v2.0. The authority. |
| `CLAUDE.md` | Operating contract and the owner's hard rules. Read first. |
| `docs/AUDIT_2026-10-16.md` | Technical + player-psychology audit with file:line findings; verdict on the pending sign batch. |
| `docs/ROADMAP.md` | R0 → public test (~6 weeks) → launch (~14–18 weeks). |
| `docs/CURRENT_PHASE.md` · `DECISION_LOG.md` · `SYSTEM_REGISTRY.md` · `API_CONTRACTS.md` · `EVENTS.md` · `STATS.md` · `TEST_PLAN.md` · `PERFORMANCE_BUDGETS.md` · `LIVEOPS_PLAYBOOK.md` · `ART_BIBLE.md` · `HANDOFF_REPORT.md` | Working docs. |
| `docs/legacy/` | Everything from `moeelzayyat/outlawcity/docs` before v2.0 (DESIGN, ARCHITECTURE, PROGRESS, 27 audit packages). Read-only. |
| `src/` | Hash-checked export of the Studio tree, per checkpoint. |
| `assets/ART_SOURCES.md` | Every asset and audio ID (Roblox-owned only). |

## Setup
1. Create the new repository; put its URL in `CLAUDE.md` rule 8. Copy `src/` and `tests/` from the old repo; copy the old `docs/` to `docs/legacy/`.
2. Open Outlaw City in its own Studio window. Keep only that window open at first Studio contact.
3. New Claude Code project; paste `CLAUDE.md` into Project instructions; first message: *"Read CLAUDE.md and docs/CURRENT_PHASE.md, then begin R0.1."*

## Tests
The runner executes at every Studio play: `[Tests] N passed, 0 failed`. Multi-client runs: Studio Test → Clients and Servers.
