# CURRENT PHASE

**Mode:** UNATTENDED (D-008) — run substages back to back; stop only at publish substages (write the package, continue elsewhere) and GO/NO-GO gates.
**Stage:** R1 — Integrity
**Substage:** R1.4 — Payout gating
**Status:** 🟨 In progress · **Last checkpoint passed:** R1.3 (2026-10-16)

## R1.4 — Payout gating
Robbery start / holdout / escape payout refused while `CharacterValidationService.isObserved(player)` (observed in the last 10 s) → `Rejected:Observed`; holdout validated server-side with `GetPartBoundsInBox` on the store `Area` every tick (not the replicated root alone); `AlreadyPaid` shows the "+$2,000" toast (F13). Passes: spec — observed player → `Rejected:Observed`; holdout outside the area box fails `LeftArea` even if the root claims inside. TestRunner + play test.

## R1 stage notes
- Restore points: `ServerStorage.Backups["R0 baseline"]`, `["R1.1 passed"]`, `["R1.2 passed"]`, `["R1.3 passed"]`; owner `.rbxl` pending (handoff owner item 1).
- Hash checks skip `ServerStorage.Backups`; manifest format `<path>|<len>|<fnv1a>` sorted.
- New specs: create the ModuleScript with `Instance.new` + `.Source` (the MCP path syntax turns `X.spec` into a folder `X` with child `spec`); edit specs by literal replace via `execute_luau`.
- Studio command bar has its own require cache: reach live service state through Studio-only bridges (`ServerStorage.LoopGuardControl`) or dev remotes.
- R1 exit: TestRunner ≥ 240, 0 failed; 2-client dispatch test recorded; 0 warnings.
