# EVENTS — EventBus catalog (server)

`Shared/Util/EventBus` (R1.7): `publish(name, payload)` / `subscribe(name, handler) → unsubscribe`. Names must be in `EventBus.Events` (a typo errors). Payloads are flat tables of numbers, strings and booleans with a numeric `UserId`, never Instances; handlers get a frozen copy, each in its own thread under `pcall`; a failing handler is reported to `AnalyticsService` (Diagnostics `ServerErrors`). Authoritative publisher only. Tests use `EventBus.new()` (isolated bus).

| Event | Payload | Publisher | Consumers | Since |
|---|---|---|---|---|
| `PlayerJoined` / `PlayerLeft` | `{UserId}` / `{UserId, Phase}` | Main | Analytics | R1.7 ✅ |
| `CrimeStarted` / `CrimeCompleted` / `CrimeFailed` | `{UserId, CrimeId, LocationId, Amount?, Reason?}` | RobberyService (→ CrimeService S2.3) | Analytics (FirstCrime); Spree, Objectives from S2 | R1.7 ✅ |
| `StarsChanged` | `{UserId, Stars, Heat}` | WantedService | HUD, Analytics (S2) | R1.7 ✅ |
| `Escaped` | `{UserId, FromStars}` | WantedService | RobberyService (payout); Spree (keep spree) S2 | R1.7 ✅ (replaced the Signal) |
| `PoliceSight` | `{UserId, Seen}` — `Seen` = police hold this player's heat: a unit sees them, or they are wanted with no unit assigned (R1.6) | PoliceService (on change) | WantedService (replaced `setPoliceSightProvider`) | R1.7 ✅ |
| `PoliceDispatched` / `PoliceRecalled` | `{UserId, Units}` | PoliceService (dispatch, re-target / pursuit end) | HUD, Analytics (S2) | R1.7 ✅ |
| `Busted` | `{UserId, Stars, Unbanked}` | PoliceService (after a successful jail) | Analytics (FirstBust); Spree (lose) S2 | R1.7 ✅ |
| `Jailed` / `Released` | `{UserId, Seconds?}` | JailService | HUD, Analytics (S2) | R1.7 ✅ |
| `SpreeStarted` / `SpreeUpdated` | `{UserId, SpreeId, Unbanked, Multiplier, Crimes}` | SpreeService | HUD, Analytics | S2.2 |
| `SpreeBanked` | `{UserId, SpreeId, Amount, PeakStars, Duration}` | SpreeService | Economy (grant), Leaderboard, Objectives, Analytics (FirstBank, subscribed) | S2.4 |
| `SpreeLost` | `{UserId, SpreeId, Amount}` | SpreeService | HUD, Analytics | S2.2 |
| `CashChanged` | `{UserId, Delta, Reason, TxId}` | EconomyService (every stored change with Delta ≠ 0) | HUD, Analytics (S2) | R1.7 ✅ |
| `PurchaseMade` | `{UserId, ItemId, Price}` | EconomyService | Analytics (S2) | R1.7 ✅ |
| `VehicleSpawned` | `{UserId, VehicleId}` | VehicleService | Analytics (FirstCar) | R1.7 ✅ |
| `CharacterObserved` | `{UserId, Kind}` (`Kind` = Teleport / SustainedOverspeed / InvalidState, or `Vehicle<Kind>` from vehicle validation) | CharacterValidationService, VehicleValidationService | Analytics (S2) | R1.7 ✅ |

## Funnel (Roblox AnalyticsService, via our `AnalyticsService`)
Onboarding funnel steps (once per player): 1 `Joined` · 2 `FirstCar` · 3 `FirstCrime` · 4 `FirstBank` (S2). Custom events: `FirstBust` (once per session), `Left` (value = session seconds), `SpreeEnded{result}` and `Again` (S2). Studio shows "LogOnboardingFunnelStepEvent event fired" but sends nothing to the dashboard.
