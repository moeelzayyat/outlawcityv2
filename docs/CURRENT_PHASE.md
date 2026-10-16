# CURRENT PHASE

**Mode:** UNATTENDED (D-008) — run substages back to back; stop only at publish substages (write the package, continue elsewhere) and GO/NO-GO gates.
**Stage:** R1 — Integrity
**Substage:** R1.2 — Persistence fixes
**Status:** 🟨 In progress · **Last checkpoint passed:** R1.1 (2026-10-16)

## R1.2 — Persistence fixes
Lock released on leave-during-load (F6, `EconomyService`); `ProfileStore.load` returns `Corrupt` for a non-table or `{Lock}`-only record (F9); ledger removes batched into the next claim (F10); profile v4 schema (`Reputation`, `BestSpree`, `Customization`, `Stats{Sprees, Banked, Busts, PlayDays}`, `Objectives`, `Settings`) + v3→v4 migration + fixture (architecture §6). Passes: `ProfileStore.spec` +4; `ProfileSession.spec` +2; migration fixture; no double-apply in the traced paths.

## R1 stage notes
- Restore points: `ServerStorage.Backups["R0 baseline"]`, `["R1.1 passed"]`; owner `.rbxl` pending (handoff owner item 1).
- Hash checks skip `ServerStorage.Backups`; manifest format `<path>|<len>|<fnv1a>` sorted (scratch `hashcheck.py` ↔ Studio snippet in the R1.1 session).
- New specs: create the ModuleScript with `Instance.new` + `.Source` (the MCP path syntax turns `X.spec` into a folder `X` with child `spec`).
- R1 exit: TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded; 0 warnings.
