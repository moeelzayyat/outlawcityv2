# SYSTEM REGISTRY

Status: `Planned` · `In Development` · `Implemented` (solo-tested) · `Tested` (spec + multi-client where relevant) · `Released`. Items are never removed. Statuses reflect the Studio build at 4207b61.

## Core (as built)
| System | Status | Target | Notes |
|---|---|---|---|
| Typed layout, `init/start` services, remote contract (6) | Implemented | R1.1 | loop isolation |
| Unit runner + 216 specs | Implemented | — | keep |
| City grid + highway + plaza + buildings (blueprint) | Implemented | frozen | D-006 |
| 50 stop lines, 4 street signs | Implemented | frozen | D-006 |
| Vehicle physics (client-owned), chase camera, touch/gamepad/keyboard | Implemented | — | |
| Coupe (starter), Muscle ($15k), Police cruiser | Implemented | S4.1 | +Sport, +Super, +van |
| Spawn pads (6) + civilian spawns (6) + spawn protection | Implemented | R1.5 | restrictions |
| Wanted rules (3★, decay, escape) | Implemented | S2.1 | escape no longer pays |
| Peaceful/Combat status (no damage) | Implemented | R1.8 hide; S5.1 damage | |
| Safe zone (plaza) | Implemented | — | |
| NPC police: one unit, road graph, bust | Implemented | R1.6, S2.5 | re-target, 1→3, roadblock |
| Jail (12 s, 4 slots) | Implemented | S4.7 | SpawnLocation fix |
| Vehicle validation (monitor-only) | Implemented | — | stays monitor-only |
| Cash, persistence (home-grown store), ledger, reconciliation | Implemented | R1.2 | F6/F9/F10, v4 |
| Store robbery (24/7 MART) | Implemented | S2.3 | becomes a CrimeConfig entry |
| Dealership + ownership + garage | Implemented | — | |
| Onboarding (P1–P8), markers, tip | Implemented | S2.8 | |
| Atmosphere lighting + police lights | Implemented | — | |
| Studio-only dev tools | Implemented | — | keep gated; + `ServerStorage.LoopGuardControl` (Studio-only BindableFunction, fault injection/stats, R1.1) |

## v2.0 additions
| System | Status | Target |
|---|---|---|
| Loop isolation, module-scope cleanup (`Server/Util/LoopGuard`: 8 loops, Main init/start pcall) | Tested | R1.1 |
| Character sampler + payout gating | Planned | R1.3–R1.4 |
| Spawn restrictions | Planned | R1.5 |
| Dispatch re-target + decay freeze | Planned | R1.6 |
| EventBus + AnalyticsService funnel | Planned | R1.7 |
| SpreeRules / SpreeService / Spree HUD / result card | Planned | S2.1–S2.2 |
| CrimeConfig + CrimeService (store, ATM ×4, gas station, car theft ×6) | Planned | S2.3 |
| Safehouses ×2 + banking | Planned | S2.4 |
| Police escalation + roadblock | Planned | S2.5 |
| Audio (siren, engine, tyre, alarm, bank, bust) | Planned | S2.6 |
| HUD UIScale root | Planned | S2.7 |
| Protected first spree | Planned | S2.8 |
| Leaderboards + daily objective | Planned | S2.9 |
| Store assets, publish | Planned | S2.10 |
| Cars ×2, paint, reputation tiers, safehouse upgrades, second store, NPC traffic | Planned | S4 |
| Ram damage, co-op sprees, friend announcements | Planned | S5 |
| Cosmetics, rating, security suite, beta | Planned | B1 |
| Economy sim, admin tools, monetization, codes, store final | Planned | L1 |

## Frozen
N4 Stages B–D, sign enlargement, connector signs, new markings, district decoration (D-006).
