# API CONTRACTS

Rules: a remote exists only with a row here, a type guard, a limiter, and an entry in `Shared/Net/Remotes.luau` (asserted by `Remotes.spec`). `F` RemoteFunction · `E` RemoteEvent. Prompt-driven actions (robbery, bank, dealership desk) use server `ProximityPrompt.Triggered`, not remotes.

## Existing (validated today)
| Remote | Type | Client sends | Server validates | v2.0 change |
|---|---|---|---|---|
| `RequestSpawnVehicle` | F | `vehicleId` | type/len, known, `PlayerSpawnable`, ownership, not jailed, alive, 3 s limiter, free spot | ✅ R1.5: refused while wanted (`Wanted`) / robbery Holding·Escaping (`InCrime`) / `SpreeUnbanked` > 0 (`Unbanked`); car on a free pad ≤ 30 studs, else a clear spot beside the player ≤ 30 studs; characters block spots |
| `RequestExitVehicle` | E | — | 0.5 s limiter; in a DriverSeat under `Workspace.Vehicles` | — |
| `RequestSetCombatStatus` | F | `target` | limiter, string ≤ 16, names, jail, wanted lock, 30 s cooldown | hidden in HUD until S5 |
| `RequestPurchaseVehicle` | F | `vehicleId` | type/len, server price, in-flight guard before yield, 1 s limiter, alive, not jailed, desk ≤ 20 studs, GUID tx | distance also checked against the server-side last-good sample |
| `OnWantedNotice`, `OnRobberyNotice` | E (S→C) | — | server never listens | `OnSpreeNotice` added · R1.4: robbery `Rejected`/`Failed` reason may be `Observed`; `Paid` is also sent for `AlreadyPaid` (F13) · S2.2: `Escape` replaced by `Completed {Id, Reward}` (cash goes to the spree) · S2.3: every robbery notice also carries `CrimeId` and `Name`; `Started` carries `Alarm` (false = silent); car theft sends `Completed {Reward, CrimeId, Name, Alarm}` |
| `DevRemotes.RequestDevCommand` | F | `(name, value)` | `IsStudio` ×2, `DevCommandRules` | + 1 s limiter |

## New (S2+)
| Remote | Type | Payload | Guard | Rate |
|---|---|---|---|---|
| `RequestCustomize` | F | `{vehicleId, paintId, txId}` | owned car, paint in catalog, cash, GUID tx | 1 / 2 |
| `RequestObjectiveClaim` | F | `{objectiveId, claimId}` | complete, unclaimed | 2 / 3 — not built: the objective pays automatically (D-016) |
| `RequestSettings` | E | `{key, value}` | whitelist | 5 / 10 |
| `OnSpreeNotice` | E (S→C) | ✅ S2.2: `(kind, payload)` — `Added {Amount, Unbanked, Multiplier, Crimes}` · `Banked {Amount, PeakStars, Crimes, Duration, Reputation, Pending}` · `Lost {Amount, Reason}` · `BankFailed {Amount}` | server never listens | — |
| `OnLeaderboard` | E (S→C) | ✅ S2.9: `(board, rows)`: board `Daily`/`Weekly`/`AllTime`, rows `{Rank, UserId, Name, Amount}` | server never listens | 60 s, and once on join |

## Attributes (server-set on Player; clients read only)
`Status`, `SpawnProtectedUntil`, `WantedLevel`, `WantedHeat`, `WantedEvading`, `CriminalReputation`, `CombatStatus`, `InSafeZone`, `Jailed`, `Cash`, `OwnedVehicles`, `RobberyPhase` → `CrimePhase`, **`SpreeUnbanked`, `SpreeMultiplier`, `SpreeCrimes`, `ObservedAt`**, `Reputation`, `BestSpree` (S2.2, profile v4), `InSafehouse`, `BankProgress`, `BankBlocked` (S2.4, SafehouseService), `ObjectiveText`, `ObjectiveProgress`, `ObjectiveTarget`, `ObjectiveReward`, `ObjectiveDone` (S2.9, ObjectiveService).
