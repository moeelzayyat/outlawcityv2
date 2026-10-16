# LIVE-OPS PLAYBOOK (from S2.10 publish onward)

| Cadence | Content | Checkpoint |
|---|---|---|
| Daily (first 30 days after public listing) | Error triage, balance hotfix (bust rate, multiplier) | Top error < 24 h |
| Weekly (Friday) | One of: new crime location, car, paint set, event spree (×2 multiplier weekend), QoL | Shipped; changelog; restore point; mirror; **owner publishes** |
| Monthly | District, mode (co-op heist), cosmetic drop | Signal review |
| Quarterly | Economy, data, performance re-baseline | Docs |

Release procedure: content in `CrimeConfig`/`VehicleConfig`/`AudioConfig` where possible → runner green, 0 warnings → play test PC + Device Simulator → migration fixture if schema changed → backup + restore point → mirror → "ready to publish" to the owner → owner publishes (Shut down all servers for schema changes) → watch 30 min → changelog.

Signal review thresholds: second-spree rate < 50% → loop review · bust rate outside 30–60% → police tuning · bank rate < 40% → safehouse placement/bank time · first crime > 60 s → markers/tip · D1 falling 2 weeks → content/objective review · spree inflow vs sinks > 20% for 2 weeks → prices.

Support: lost cash → ledger + `RecentTransactions` inspection → grant with a GUID tx → logged. No RemoveAsync. Rollback: restore point + owner republish; profile rollback via snapshot store (L1.2).
