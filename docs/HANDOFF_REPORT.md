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
