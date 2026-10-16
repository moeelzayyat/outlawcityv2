# EVENTS — EventBus catalog (server)

`Shared/Util/EventBus` (R1.7): `publish(name, payload)` / `subscribe(name, handler) → unsubscribe`. Names must be in `EventBus.Events` (a typo errors). Payloads are flat tables of numbers, strings and booleans with a numeric `UserId`, never Instances; handlers get a frozen copy, each in its own thread under `pcall`; a failing handler is reported to `AnalyticsService` (Diagnostics `ServerErrors`). Authoritative publisher only. Tests use `EventBus.new()` (isolated bus).

| Event | Payload | Publisher | Consumers | Since |
|---|---|---|---|---|
| `PlayerJoined` / `PlayerLeft` | `{UserId}` / `{UserId, Phase}` | Main | Analytics | R1.7 ✅ |
| `CrimeStarted` / `CrimeCompleted` / `CrimeFailed` | `{UserId, CrimeId, LocationId, Amount?, Stars?, Reason?, Silent?}` (`Silent` on `CrimeStarted`) | CrimeService, ParkedCarService (S2.3); `CrimeCompleted` at holdout end or on the steal | Analytics (FirstCrime); SpreeService (adds the crime); Objectives S2.9 | R1.7 ✅ · S2.2 |
| `StarsChanged` | `{UserId, Stars, Heat}` | WantedService | HUD, Analytics (S2) | R1.7 ✅ |
| `Escaped` | `{UserId, FromStars}` | WantedService | SpreeService (keeps the spree; escaping no longer pays, S2.2) | R1.7 ✅ (replaced the Signal) |
| `PoliceSight` | `{UserId, Seen}` — `Seen` = police hold this player's heat: a unit sees them, or they are wanted with no unit assigned (R1.6) | PoliceService (on change) | WantedService (replaced `setPoliceSightProvider`) | R1.7 ✅ |
| `PoliceDispatched` / `PoliceRecalled` | `{UserId, Units}` — `Units` = units now on the player | PoliceService (when a player's unit count rises / falls, S2.5) | HUD, Analytics (S2) | R1.7 ✅ · S2.5 |
| `ObjectiveCompleted` | `{UserId, ObjectiveId, Reward}` | ObjectiveService (after the reward is paid) | Analytics (S3) | S2.9 ✅ |
| `RoadblockPlaced` | `{UserId, X, Z, Seconds}` | PoliceService (3★ roadblock, S2.5) | HUD (S2.7), Analytics | S2.5 ✅ |
| `Busted` | `{UserId, Stars, Unbanked}` | PoliceService (after a successful jail) | Analytics (FirstBust); SpreeService (loses the spree, counts the bust) | R1.7 ✅ · S2.2 |
| `Jailed` / `Released` | `{UserId, Seconds?}` | JailService | HUD, Analytics (S2) | R1.7 ✅ |
| `SpreeStarted` / `SpreeUpdated` | `{UserId, SpreeId, Unbanked, Multiplier, Crimes}` | SpreeService | Analytics (Again) | S2.2 ✅ |
| `SpreeBanked` | `{UserId, SpreeId, Amount, PeakStars, Duration, Crimes}` | SpreeService (after `EconomyService.bankSpree` stored or recorded it; called by SafehouseService, S2.4) | Analytics (FirstBank, SpreeEnded); Leaderboard, Objectives S2.9 | S2.2 ✅ |
| `SpreeLost` | `{UserId, SpreeId, Amount, Reason}` (`Busted` / `Left`) | SpreeService | Analytics (SpreeEnded) | S2.2 ✅ |
| `CashChanged` | `{UserId, Delta, Reason, TxId}` | EconomyService (every stored change with Delta ≠ 0) | HUD, Analytics (S2) | R1.7 ✅ |
| `PurchaseMade` | `{UserId, ItemId, Price}` | EconomyService | Analytics (S2) | R1.7 ✅ |
| `VehicleSpawned` | `{UserId, VehicleId}` | VehicleService | Analytics (FirstCar) | R1.7 ✅ |
| `CharacterObserved` | `{UserId, Kind}` (`Kind` = Teleport / SustainedOverspeed / InvalidState, or `Vehicle<Kind>` from vehicle validation) | CharacterValidationService, VehicleValidationService | Analytics (S2) | R1.7 ✅ |

## Funnel (Roblox AnalyticsService, via our `AnalyticsService`)
Onboarding funnel steps (once per player): 1 `Joined` · 2 `FirstCar` · 3 `FirstCrime` · 4 `FirstBank` (S2). Custom events: `FirstBust` (once per session), `Left` (value = session seconds), `SpreeEnded{result}` and `Again` (S2). Studio shows "LogOnboardingFunnelStepEvent event fired" but sends nothing to the dashboard.
