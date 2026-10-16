# ART & ASSET SOURCES

Owner rule: no third-party scripts or assets; audio Roblox-owned only. Every ID recorded before it ships.

| Asset | Type | ID | Origin | License | Pinned | Used in | Status |
|---|---|---|---|---|---|---|---|
| City, cars, store, dealership, jail, signs | Parts/models | in place | project-built from `CityLayout`/`VehicleFactory` | owner | — | World | Active |
| Siren | Audio | ______ | Roblox audio library | Roblox | — | `AudioConfig.Sounds.Siren` | Pending owner choice (R0.4, D-003) |
| Engine loop / tyre / alarm / register (bank) / bust | Audio | ______ | Roblox audio library | Roblox | — | `AudioConfig.Sounds.Engine/Tyre/Alarm/Bank/Bust` | Pending owner choice (S2.6) |

### Audio candidates found in S2.6 (NOT approved, NOT in use)
No Creator Store search result was uploaded by the `Roblox` account itself, so none of these can be called Roblox-owned without the owner's ruling. Checked with `MarketplaceService:GetProductInfo` / `GroupService:GetGroupInfoAsync` in Studio on 2026-10-16:

| Use | ID | Name | Creator | Note |
|---|---|---|---|---|
| Engine loop | 80317022777602 | Car-Engine-Loop | group "Roblox Resources" (3529469, verified badge; group owner account CreatorKnowledge) | free |
| Siren | 9117810961 | Police Siren Slow Vehicle Away 2 (SFX) | ProSoundEffects ("Courtesy of Pro Sound Effects", Roblox's licensed SFX library) | free, 11.2 s |

To approve: tell me which IDs (or which creators) count as Roblox-owned for this project. I add each to `AudioConfig.Sounds.<Name>.SoundId` and `AudioConfig.ApprovedIds` and record it here; the game plays nothing until then.
| Icon A / B | Image | — | owner / Studio generation | owner | — | store | Not made |
| Thumbnails 1–3 | Image | — | — | — | — | store | Not made |
