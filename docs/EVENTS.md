# EVENTS — EventBus catalog (server)

`Shared/Util/EventBus`: typed `Publish/Subscribe`; handlers in `pcall`; payloads carry UserIds and numbers, never Instances. Authoritative publisher only; Spree, Leaderboard, Analytics, Objectives, HUD notices consume.

| Event | Payload | Publisher | Consumers | Since |
|---|---|---|---|---|
| `CrimeStarted` / `CrimeCompleted` / `CrimeFailed` | `{UserId, CrimeId, LocationId, Reason?}` | CrimeService | Spree, Police, Analytics, Objectives | S2.3 |
| `StarsChanged` | `{UserId, Stars, Heat}` | WantedService | Police, HUD, Analytics | R1.7 |
| `Escaped` | `{UserId, FromStars}` | WantedService | Spree (keep spree), Analytics | R1.7 (replaces Signal) |
| `PoliceSight` | `{UserId, Seen: boolean}` | PoliceService | WantedService (replaces `setPoliceSightProvider`) | R1.7 |
| `PoliceDispatched` / `PoliceRecalled` | `{UserId, Units}` | PoliceService | HUD, Analytics | R1.7 |
| `Busted` | `{UserId, Stars, Unbanked}` | PoliceService | Jail, Spree (lose), Analytics | R1.7 |
| `Jailed` / `Released` | `{UserId, Seconds?}` | JailService | HUD, Analytics | R1.7 |
| `SpreeStarted` / `SpreeUpdated` | `{UserId, SpreeId, Unbanked, Multiplier, Crimes}` | SpreeService | HUD, Analytics | S2.2 |
| `SpreeBanked` | `{UserId, SpreeId, Amount, PeakStars, Duration}` | SpreeService | Economy (grant), Leaderboard, Objectives, Analytics | S2.4 |
| `SpreeLost` | `{UserId, SpreeId, Amount}` | SpreeService | HUD, Analytics | S2.2 |
| `CashChanged` | `{UserId, Delta, Reason, TxId}` | EconomyService | HUD, Analytics | R1.7 |
| `PurchaseMade` | `{UserId, ItemId, Price}` | Economy/Dealership | Analytics | R1.7 |
| `CharacterObserved` | `{UserId, Kind}` | CharacterValidationService | Crime/Spree gating, Analytics | R1.3 |
| `PlayerLeft` | `{UserId, Phase}` | Main | Analytics | R1.7 |

## Funnel (Roblox AnalyticsService)
`Joined` · `FirstCar` · `FirstCrime` · `FirstBank` · `FirstBust` · `SpreeEnded{result}` · `Again` · `Left`
