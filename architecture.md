# OUTLAW CITY
## Master Game Architecture & Production Specification

**Document Version:** 2.0 (supersedes `docs/legacy/ARCHITECTURE.md`, `DESIGN.md`, `ROADMAP.md` as the design authority)
**Status:** Approved design baseline — implementation begins at Stage R1
**Platform:** Roblox (phone, PC; controller supported)
**Language:** Luau (`--!strict`)
**Development Environment:** Claude Code + Roblox Studio MCP on the owner's PC; Studio is the source of truth; `src/` is a hash-checked export
**Architecture:** Server-authoritative, pure-rules + services, event bus, home-grown write-through persistence (kept), 8-player servers
**Production Stages:** Re-baseline → Integrity → Signature → Public Test → Content → Multiplayer → Closed Beta → Launch → Live Ops

---

# 0. WHAT THIS REPLACES AND WHY

The current build is an engineering prototype with excellent foundations (pure rules, 216 tests, a six-remote contract, a write-through economy) and almost no game: two cars, one store, one cop, thirty minutes of content, no differentiator, no players. The audit (`docs/AUDIT_2026-10-16.md`) found three HIGH integrity gaps and a process that spent its last four days on street signs.

| Area | Current | v2.0 |
|---|---|---|
| Signature | none (a small Jailbreak) | **Crime Spree**: press-your-luck unbanked cash, safehouse banking, police escalation (§2.2) |
| Police | one unit, no re-target | 1→3 units by stars, re-target each tick, roadblock at 3★; decay frozen when no unit is chasing (§8) |
| Integrity | character position client-authoritative; spawn teleports; loops unguarded | character sampler, server-validated holdouts, spawn restrictions, loop isolation (§7, §9) |
| Content | 1 crime, 1 store, 2 cars | 3 crime types, 2 safehouses, 4–6 cars, paint, reputation unlocks (§10–§12) |
| Sessions | open-ended | 3–5-minute sprees with a number as the goal; Biggest Spree leaderboard (§13) |
| Servers | default 50 | **8** (§4.4) |
| Testing | solo Studio only | Studio multi-client (2–8) is standard; service-level tests with fakes (§16) |
| Audio | none | siren (Roblox-owned asset), engine, alarm, payout (§14) |
| HUD | fixed pixels | `UIScale` root, two rows, cash in row 1 (§15) |
| Process | per-task auditor packages | checkpoint protocol; review at gates (§18) |
| World polish | N4 signs etc. | frozen until data says players get lost |

Kept unchanged: the `init/start` service shape, the pure-rules pattern, the remote contract, the economy/ledger/session code (with fixes), `VehiclePhysics`, the road graph, the city blueprint, the owner's monetization policy.

---

# 1. PROJECT MISSION

Outlaw City is a mobile-first, server-authoritative open-world crime game for Roblox. Everyone spawns a civilian. You commit crimes to build a **spree** — cash you haven't banked yet — while the police escalate with your stars. Bank it at a safehouse, or lose it when they bust you.

## 1.1 Pillars
1. **Every crime is a bet.** The spree multiplier makes the next crime worth more and the bust cost higher. The decision to bank or push is the game.
2. **The chase is fair and readable.** Police escalate visibly with stars; losing them is a skill (line of sight, speed, roads), not a trick.
3. **Short and repeatable.** A spree is 3–5 minutes on a phone; "one more" is one tap.

## 1.2 Viral thesis
- **Click:** icon = a muscle car mid-drift, three cruisers behind, "$12,400" floating over it. Title with the number: **"Crime Spree 🚔 Outlaw City"**.
- **Stay:** car in one tap (exists); first crime inside 60 s; first bank or bust inside 4 minutes.
- **Return:** Biggest Spree board (daily/weekly/all-time), reputation unlocks, paint, daily objective (no streak).
- **Bring friends:** 8-player servers; a friend's bust or bank is announced; co-op sprees (shared multiplier, split bank) in S5.
- **Clip:** the 3★ roadblock escape at the highway turnaround with $20,000 unbanked.
- **Pay fairly:** paints, liveries, horns, sirens-for-your-car cosmetics, supporter pack. Never power, never faster cars for Robux.

## 1.3 Non-negotiable requirements (owner's rules, kept)
- Never publish, enable monetization, buy assets or change the public experience without the owner; the owner publishes.
- Place 132163592957463 is the only Studio window Claude touches; other games on the PC are never touched; verify PlaceId before every action.
- No third-party scripts or assets; Roblox-owned audio only.
- Money, arrests, purchases and crimes are server-authoritative.
- Back up before each stage (owner's `.rbxl` + Studio restore point); exact rollback demonstrated for world changes.
- The three fixed settings (one unit, siren off, monitor-only anti-cheat) are **lifted by this document only with the owner's acceptance of D-002, D-003, D-004** — until then they stand.

---

# 2. GAMEPLAY VISION

## 2.1 Core loop
```text
SPAWN (plaza safe zone) → one tap: car
  ↓
CRIME (store / ATM / gas station / car theft) → +stars, +unbanked cash × multiplier
  ↓                                             ↓
  push: another crime (multiplier +0.5, stars up, more cruisers)
  ↓
BANK: reach a safehouse with 0 police sight for 5 s → unbanked → cash (saved)   |   BUST: unbanked lost, 12 s jail, stars 0
  ↓
SPREE RESULT: amount, peak stars, duration, best-ever → Biggest Spree board → "Again"
```

## 2.2 Signature — Crime Spree
- **Unbanked cash** starts at 0 when the first crime of a spree lands. Each crime adds `base × multiplier`; multiplier starts at 1.0 and rises +0.5 per crime (cap 4.0).
- **Stars** rise per crime as today (`WantedRules`); police units = stars (1→3); at 3★ a roadblock spawns on the player's predicted road.
- **Banking:** enter a safehouse zone (2 on the map) with no police sight for 5 s; unbanked becomes cash (one idempotent grant per spree); spree ends; stars decay to 0 over 10 s.
- **Bust:** unbanked lost (shown big), jail 12 s, stars 0, reputation unchanged. Losing never touches banked cash.
- **Escape** (heat decays to 0 away from a safehouse) keeps the spree alive at the current multiplier with 0 stars — the player can push again or go bank. This replaces today's "escape pays" rule: **escaping no longer pays; banking pays.**
- **Reputation:** +peak stars × crimes at bank; unlocks cosmetics and car slots; persisted.
- Numbers are tunables in `SpreeConfig`; the first public test decides them.

## 2.3 Crimes (S2)
| Crime | Where | Hold | Base cash | Stars | Risk |
|---|---|---|---|---|---|
| Store robbery | 24/7 MART (exists) + 1 more | 15 s inside | $2,000 | 2 | police at hold end |
| ATM smash | 4 ATMs on the grid | 6 s hold | $800 | 1 | silent alarm 50% |
| Gas station | 1 at the highway connector | 12 s | $1,500 | 2 | explosion stuns nearby cars |
| Car theft | NPC parked cars (6) | enter | $500 on bank | 1 | car becomes the getaway car |

All server-validated (§7). Cooldowns per location, shorter than today (store 120 s).

## 2.4 Controls
As built (keyboard, gamepad, touch; chase camera). Additions: horn, handbrake on touch (exists), "Bank" and "Again" prompts.

---

# 3. FIRST SESSION DESIGN

| Time | What happens | Measured |
|---|---|---|
| 0:02 | Spawn, tip "Steal. Push your luck. Bank it.", markers to the nearest ATM and store | control |
| 0:05 | One tap: Coupe, seated | first car |
| 0:40 | ATM smash (6 s) → "+$800 UNBANKED ×1.0", 1★, one cruiser | first crime ≤ 60 s |
| 1:30 | Second crime or drive to the safehouse marker | decision |
| 2:30–4:00 | Bank ($800–$3,600) or bust | first result ≤ 4 min |
| 4:00 | Result card: spree, best, board rank, **Again** | second spree |

Rules: no reading required (markers, icons, the money counter); the Combat button is hidden (F5) until damage exists; the first spree can't be busted before the first crime completes (police dispatch delay 10 s for 0-run players).

---

# 4. TECHNICAL ARCHITECTURE

## 4.1 Core principles
Server authority · pure rules modules tested without Instances · services with `init/start` and error isolation · one remote contract · event bus for cross-system reactions · write-through persistence with idempotent grants · measured budgets · telemetry from R1 · checkpoints with numbers.

## 4.2 Toolchain (Studio-native)
Roblox Studio + Studio MCP (edit, run, test); `src/` export after each checkpoint (hash-checked, as today); `ServerStorage/Tests/TestRunner` (exists; runs at every play); Studio **Test → Clients and Servers** for 2–8-player runs; owner `.rbxl` + restore points. No Rojo sync, no CI.

## 4.3 Layout (as built, with additions)
```text
ReplicatedStorage/Shared/   Types · Config/* (+SpreeConfig, CrimeConfig, SafehouseConfig, AudioConfig) · Rules/* (+SpreeRules, CrimeRules, CharacterValidationRules)
                            · Vehicle/VehiclePhysics · Net/Remotes · Util/{Signal,EventBus}
ServerScriptService/Server/ Main · Services/* (+SpreeService, CrimeService, SafehouseService, CharacterValidationService, LeaderboardService, AnalyticsService, AudioService)
                            · Police/* (+Roadblock) · Data/* (kept) · World/* · Dev/*
StarterPlayer/.../Client/   Main · Controllers/* (+SpreeHudController, SafehouseMarker, AudioController) · UiRoot (UIScale)
ServerStorage/Tests/        TestRunner · *.spec (+service specs with fakes)
docs/ · assets/ · src/ (export)
```

## 4.4 Server model
**One place, MaxPlayers 8** (D-005). One shared city per server; police units are per wanted player (max 3 per player, 6 per server); safehouses shared. Private servers available.

---

# 5. SERVICES, LIFECYCLE, EVENT BUS

Keep the 14 services and their `init/start` shape; add six. `Main` wraps every `init` and every loop iteration in `pcall` and reports through `AnalyticsService` (F7). Module-scope connections move into `start()` (F15).

**Event bus** (`Shared/Util/EventBus`, typed, server-side): `CrimeCommitted`, `SpreeStarted`, `SpreeBanked`, `SpreeLost`, `StarsChanged`, `PoliceDispatched`, `Busted`, `Jailed`, `Released`, `PurchaseMade`, `PlayerLeft`. Spree HUD, Leaderboard, Analytics, Objectives consume; the two hidden wires (`setPoliceSightProvider`, `Escaped` subscription) become bus events.

---

# 6. STATE

Profile v4: `Cash`, `OwnedVehicles`, `RecentTransactions`, `PaidRewards` (as v3) + `Reputation`, `BestSpree`, `Customization{vehicleId → paint}`, `Stats{Sprees, Banked, Busts, PlayDays}`, `Objectives`, `Settings`. Migration v3→v4 adds defaults; fixture in tests. Session state: spree (unbanked, multiplier, crimes, peak stars), stars/heat, jail, combat status, active crime.

---

# 7. AUTHORITY AND INTEGRITY

- **Character sampler** (`CharacterValidationService`, 5 Hz, same shape as vehicle validation): on-foot speed and displacement caps; non-finite rejection; observations logged; **crime holdouts and banking are refused when the player has an active character observation** in the last 10 s (F1). Vehicle validation stays monitor-only for cars (owner rule) but the same observation flag gates payouts (D-004).
- **Holdouts** validated server-side with `GetPartBoundsInBox` on the crime `Area` every tick, not the replicated root alone.
- **Spawn restrictions:** no vehicle spawn while `WantedLevel > 0`, in a spree with unbanked > 0, or in a crime (F3); spawn within 30 studs when allowed; pad clearance includes characters (F14).
- **Police sight** requires the cruiser to be within range **and** a raycast from the cruiser; no sight is possible from a unit that doesn't exist (F2).
- Remotes: existing six + `RequestBank` (prompt-driven, no remote needed), `RequestCustomize`, `RequestObjectiveClaim`, `RequestSettings`; all with contract rows, guards, limiters (`docs/API_CONTRACTS.md`).

---

# 8. POLICE

`PoliceConfig.MaxUnits` becomes per-player `UnitsByStars = {1, 2, 3}` (D-002), server cap 6. Dispatch re-targets each tick: a unit follows its assigned player; a wanted player with no unit gets the next free one; while no unit is available their heat is frozen (counts as seen). Roadblock at 3★: two parked cruisers on the predicted road segment 250 studs ahead, despawn when passed or after 30 s. Siren on (D-003, Roblox-owned asset) with distance attenuation. Perf budget: 6 units × 7 raycasts/frame = 42/frame — measured in S2.

---

# 9. VOYAGE-STYLE ISOLATION

Every service loop is `pcall`-per-iteration with a 1-s backoff on repeated failure; `JailService.release` checks `player.Parent`. `EconomyService` lock leak fixed (F6); `ProfileStore.load` returns `Corrupt` for non-table or `{Lock}`-only records (F9); ledger removes batched (F10).

---

# 10. CRIMES AND SAFEHOUSES

`CrimeConfig` defines each crime (area, hold, base, stars, cooldown, alarm chance); `CrimeService` replaces `RobberyService` as a generic holdout engine (store robbery becomes one definition). `SafehouseService`: two zones (an old garage in Old Town, a warehouse by the highway), bank on 5 s without sight, idempotent grant `spree:<spreeId>`.

---

# 11. VEHICLES AND DEALERSHIP

4–6 cars across price tiers ($0 Coupe, $15,000 Muscle, $40,000 Sport, $90,000 Super; a van for S5 heists). Paint customization (Pearls-free: cash) with server-stored colours; NPC parked cars for theft (6, respawn 120 s). Dealership flow as built.

---

# 12. ECONOMY

Cash from banked sprees only; prices as approved; sinks: cars, paint, safehouse upgrades (bank from 5 s → 3 s, max 2 levels). Reputation unlocks: paint sets, car slots, a second safehouse marker.

---

# 13. PROGRESSION AND RETURN

Biggest Spree (daily/weekly/all-time `OrderedDataStore`), reputation tiers, daily objective (no streak), stats on the result card, cosmetics. Nothing is lost by not logging in.

---

# 14. AUDIO (Roblox-owned assets only)

Siren (owner approves the asset ID), engine loop by speed, tyre squeal on drift, alarm on crime start, cash-register on bank, "busted" sting. `AudioConfig` lists every ID; `assets/ART_SOURCES.md` records them.

---

# 15. UI

One root `ScreenGui` with `UIScale` by viewport height (F12); row 1: cash + unbanked spree counter + stars; row 2: contextual (crime timer, bank prompt, jail). Combat button hidden until S5. Device: touch layout verified in the Device Simulator and on the owner's phone before S3.

---

# 16. TESTING

Keep the runner and 216 specs. Add: `SpreeRules`, `CrimeRules`, `CharacterValidationRules`, `PoliceDispatchRules` multi-player cases, profile v3→v4 migration, `ProfileStore.load` corrupt cases, service tests with fake `Players`/`World` (Vehicle spawn restrictions, Jail loop survives an error, Economy lock release on early leave). **Studio multi-client runs (2, 4, 8)** replace "MULTIPLAYER UNVERIFIED" for everything that does not need real network latency; the remaining items are tested at S3 live.

---

# 17. PERFORMANCE BUDGETS

| Metric | Target |
|---|---|
| Server game work per frame, 8 players, 6 units, 2 roadblocks | ≤ 2 ms avg |
| Police raycasts per frame | ≤ 50 |
| Client FPS phone (Device Simulator + owner's phone) | ≥ 30 in a 3★ chase |
| Join → seated in car (new account) | ≤ 10 s |
| First crime (new account, unassisted) | ≤ 60 s median |
| Save failures | 0 unresolved |

---

# 18. OPERATING CONTRACT

`CLAUDE.md`. Checkpoint protocol at every substage; independent review at gates only (S3, B1, L1). Unattended mode per D-008 if accepted.

---

# 19. MIGRATION FROM THE CURRENT CODE

Nothing is rewritten. R1 fixes integrity in place; S2 adds Spree/Crime/Safehouse/Police-escalation as new services beside the existing ones (RobberyService becomes a CrimeConfig entry); the HUD gets a `UIScale` root; tests grow. N4 and other world polish are frozen (D-006).

---

# 20. GROWTH

| Signal | Driven by |
|---|---|
| Playthrough | icon with the number; title with "Crime Spree" |
| Bounce | one-tap car; first crime ≤ 60 s; protected first spree |
| Play days | leaderboards, reputation, daily objective, paints, Friday updates |
| Co-play | 8-player servers, friend announcements, co-op sprees (S5) |
| Spend | paints, liveries, horns, supporter pack |

Title A: `Crime Spree 🚔 Outlaw City` · B: `Outlaw City: Crime Spree` · C: `Outlaw City 🚔 Rob, Run, Bank`.

**Current approved stage: R1 — Integrity (after R0).**
