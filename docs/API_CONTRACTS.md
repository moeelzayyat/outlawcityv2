# API CONTRACTS

Rules: a remote exists only with a row here, a type guard, a limiter, and an entry in `Shared/Net/Remotes.luau` (asserted by `Remotes.spec`). `F` RemoteFunction · `E` RemoteEvent. Prompt-driven actions (robbery, bank, dealership desk) use server `ProximityPrompt.Triggered`, not remotes.

## Existing (validated today)
| Remote | Type | Client sends | Server validates | v2.0 change |
|---|---|---|---|---|
| `RequestSpawnVehicle` | F | `vehicleId` | type/len, known, `PlayerSpawnable`, ownership, not jailed, alive, 3 s limiter, free pad | **+ refuse while wanted / in crime / unbanked > 0; spawn ≤ 30 studs; pad clearance includes characters** |
| `RequestExitVehicle` | E | — | 0.5 s limiter; in a DriverSeat under `Workspace.Vehicles` | — |
| `RequestSetCombatStatus` | F | `target` | limiter, string ≤ 16, names, jail, wanted lock, 30 s cooldown | hidden in HUD until S5 |
| `RequestPurchaseVehicle` | F | `vehicleId` | type/len, server price, in-flight guard before yield, 1 s limiter, alive, not jailed, desk ≤ 20 studs, GUID tx | distance also checked against the server-side last-good sample |
| `OnWantedNotice`, `OnRobberyNotice` | E (S→C) | — | server never listens | `OnSpreeNotice` added |
| `DevRemotes.RequestDevCommand` | F | `(name, value)` | `IsStudio` ×2, `DevCommandRules` | + 1 s limiter |

## New (S2+)
| Remote | Type | Payload | Guard | Rate |
|---|---|---|---|---|
| `RequestCustomize` | F | `{vehicleId, paintId, txId}` | owned car, paint in catalog, cash, GUID tx | 1 / 2 |
| `RequestObjectiveClaim` | F | `{objectiveId, claimId}` | complete, unclaimed | 2 / 3 |
| `RequestSettings` | E | `{key, value}` | whitelist | 5 / 10 |
| `OnSpreeNotice` | E (S→C) | `{kind, amount?, multiplier?, stars?}` | — | — |
| `OnLeaderboard` | E (S→C) | `{board, rows}` | — | 60 s |

## Attributes (server-set on Player; clients read only)
`Status`, `SpawnProtectedUntil`, `WantedLevel`, `WantedHeat`, `WantedEvading`, `CriminalReputation`, `CombatStatus`, `InSafeZone`, `Jailed`, `Cash`, `OwnedVehicles`, `RobberyPhase` → `CrimePhase`, **`SpreeUnbanked`, `SpreeMultiplier`, `SpreeCrimes`, `ObservedAt`**.
