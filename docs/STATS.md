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
| `MaxUnbanked` | 1,000,000 | — | one economy transaction (`EconomyConfig.MaxTransaction`) |

Rounding: each crime adds `floor(base × multiplier)`; the multiplier rises after the crime (first crime ×1.0). `SpreeRules`/`SpreeConfig` (S2.1).

## Crimes (`CrimeConfig`, S2.3)
| Crime | Hold | Base | Stars | Cooldown | Alarm |
|---|---|---|---|---|---|
| Store | 15 s | 2,000 | 2 | 120 s | always |
| ATM | 6 s | 800 | 1 | 90 s | 50% |
| Gas station | 12 s | 1,500 | 2 | 150 s | always |
| Car theft | enter | 500 (at bank) | 1 | 120 s respawn | 30% |

As built (S2.3): stars come from the WantedConfig heat of the reported crime (`AtmSmash` 25, `GasStationRobbery` 70, `CarTheft` 25, `StoreRobbery` as before). Failed-attempt cooldowns: store 60 s, ATM 45 s, gas 75 s. Prompt ranges: store 10, ATM 6, gas 8 studs. Car theft is a 1.5 s hold prompt that completes on the spot; the spot refills 120 s after it empties, once clear. A silent ATM (50%) adds cash with no stars.

## Safehouses (`SafehouseConfig`, S2.4)
Two zones: Old Town Garage (-350, -200), Highway Warehouse (-200, -420), both open to the east. Bank: inside a zone, no police unit seeing you, not observed, not jailed, for `SpreeConfig.BankSeconds` (5 s) continuously; leaving or being seen restarts it. Zone exit margin 2 studs; check 4 Hz. After a bank, stars fall to 0 over `StarCooldownSeconds` 10 s (no escape reward; a new crime cancels the cool-down).

## Boards and daily objective (S2.9, D-016)
Biggest Spree: best banked spree per player; daily (00:00 UTC), weekly (Monday 00:00 UTC), all-time; top 10; refreshed every 60 s. Daily objective rotation: Bank 3 sprees → $1,500 · Complete 8 crimes → $1,500 · Bank a $5,000 spree → $2,000; once per UTC day, no streak.

## Wanted (`WantedConfig`, as built)
3 stars; decay delay 8 s; thresholds as approved; heat frozen while any unit sees the player **or no unit is assigned to a wanted player** (R1.6).

## Police (`PoliceConfig`)
`UnitsByStars = {1, 2, 3}` (D-002) · server cap 6 · sight range 130 · chase speed 100 · chase gain 0.25 · bust distance 8 / 2.5 s · roadblock at 3★, 250 studs ahead on the grid road the player travels (moved back out of intersections), 30 s, next one ≥ 15 s after the last ends; barrier 32 studs across a 36-stud road. Allocation: one unit per wanted player before any second unit, highest stars first; a player in a robbery holdout keeps units already on them but gets no new ones. Budget (S2.5): ≤ 50 raycasts/frame, ≤ 2 ms.

## Character sampler (`CharacterValidationRules`, R1.3)
On-foot: max speed 24 studs/s sustained 1 s; displacement per 0.2 s sample ≤ 24×0.2×1.5+6; vertical excluded; non-finite → observation; observation window for gating 10 s. Grace 2 s after spawn, after leaving a seat, and after an authorized server move (`authorizeMove`, jail cell). Seated players are not sampled; after leaving a seat (2 s) the exit step and momentum are allowed but a jump > 60 studs in one sample is still a teleport (`CharacterValidationConfig`).

## Vehicles (as built)
Coupe top 120 · Muscle 138 · Police 128; validation limits ×1.3 + 10 (monitor-only; movement observations stamp the driver's `ObservedAt`, D-012). Spawn: within 30 studs (`GameplayConfig.VehicleSpawnMaxDistance`), pad first, else beside the player (radii 10/16/24, 8 directions).

## Economy
Start $500 · Muscle $15,000 · Sport $40,000 · Super $90,000 · paints $1,000–5,000 · safehouse upgrades $8,000 / $20,000.

## Profile v4 (`EconomyConfig`, R1.2)
`ProfileVersion` 4: + `Reputation`, `BestSpree` (whole ≥ 0), `Customization` (vehicleId → paint id ≤ 32 chars, ≤ `MaxOwnedVehicles` entries), `Stats{Sprees, Banked, Busts, PlayDays}` (whole ≥ 0), `Objectives` (id → progress, ≤ 20), `Settings` (name → boolean | number, ≤ 20). v1–v3 migrate with defaults; a v4 record missing a section or holding a bad number is `Corrupt` (refused untouched). `LedgerSettleDelay` 10 s (paid rewards leave the ledger on the next claim, F10).

## Test requirements
One spec per row above; spree maths at cap and with NaN; bank idempotent per `spreeId`; bust loses only unbanked; escape keeps the spree; first-spree delay only for 0-run.
