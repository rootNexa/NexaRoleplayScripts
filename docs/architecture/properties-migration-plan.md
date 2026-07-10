# Properties Migration Plan

The new foundation is introduced under `[nexa-gameplay]` and does not mutate the old `[nexa-housing]` resources. Migration is additive first, destructive only after runtime acceptance.

Order:

1. Document legacy housing and furniture adapters.
2. Add `nexa_properties` for types, definitions, instances, ownership, sales, leases, residents, storage, wardrobes, garages, furniture metadata, admin and creator foundations.
3. Add `nexa_propertykeys` for keys, access history and door-level access checks.
4. Add `nexa_property_interiors` for interior definitions, instances, routing buckets, entry/exit tokens and occupants.
5. Add `nexa_property_security` for locks, alarm state and burglary attempts.
6. Add static validators and runtime harness.
7. Run all repository validators.

Removal criteria for legacy resources:

- no `ox_lib` dependency remains in active server config
- new callbacks and exports cover required gameplay flows
- FXServer runtime tests pass for enter/exit, keys, leases, rent, storage and security
- player data migration strategy is approved
