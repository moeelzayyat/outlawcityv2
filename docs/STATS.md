# STATS — tunables and rules (all server-side; every value has a spec)

## Spree (`SpreeConfig`, S2.1)
| Tunable | Default | Range | Note |
|---|---|---|---|
| `MultiplierStart` | 1.0 | — | |
| `MultiplierStep` | 0.5 | 0.25–1.0 | per completed crime |
| `MultiplierCap` | 4.0 | 2–6 | |
| `BankSeconds` | 5 | 3–8 | no police sight, inside a safehouse zone |
| `BankSecondsUpgraded` | 4, 3 | — | safehouse upgrade levels |
| `LossOnBust` | 100% | — | banked cash never touched |
| `ReputationAtBank` | peakStars × crimes | cap 50 | |
| `FirstSpreeDispatchDelay` | 10 s | — | 0-run players only |

## Crimes (`CrimeConfig`, S2.3)
| Crime | Hold | Base | Stars | Cooldown | Alarm |
|---|---|---|---|---|---|
| Store | 15 s | 2,000 | 2 | 120 s | always |
| ATM | 6 s | 800 | 1 | 90 s | 50% |
| Gas station | 12 s | 1,500 | 2 | 150 s | always |
| Car theft | enter | 500 (at bank) | 1 | 120 s respawn | 30% |

## Wanted (`WantedConfig`, as built)
3 stars; decay delay 8 s; thresholds as approved; heat frozen while any unit sees the player **or no unit is assigned to a wanted player** (R1.6).

## Police (`PoliceConfig`)
`UnitsByStars = {1, 2, 3}` (D-002) · server cap 6 · sight range 130 · chase speed 100 · chase gain 0.25 · bust distance 8 / 2.5 s · roadblock at 3★, 250 studs ahead, 30 s.

## Character sampler (`CharacterValidationRules`, R1.3)
On-foot: max speed 24 studs/s sustained 1 s; displacement per 0.2 s sample ≤ 24×0.2×1.5+6; vertical excluded; non-finite → observation; observation window for gating 10 s.

## Vehicles (as built)
Coupe top 120 · Muscle 138 · Police 128; validation limits ×1.3 + 10 (monitor-only).

## Economy
Start $500 · Muscle $15,000 · Sport $40,000 · Super $90,000 · paints $1,000–5,000 · safehouse upgrades $8,000 / $20,000.

## Test requirements
One spec per row above; spree maths at cap and with NaN; bank idempotent per `spreeId`; bust loses only unbanked; escape keeps the spree; first-spree delay only for 0-run.
