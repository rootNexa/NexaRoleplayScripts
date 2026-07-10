# Properties Current State

Existing housing code lives under `[nexa-housing]/nexa_housing` and `[nexa-housing]/nexa_furniture`. These resources are legacy-facing adapters: their manifests still depend on `ox_lib`, and `nexa_housing` also references `ox_inventory`. Server callbacks are registered through `lib.callback.register` and then delegated to old `nexa_api` property exports such as `property.list`, `property.purchase`, `property.rent`, `property.grantAccess`, and furniture calls.

No complete server-authoritative property domain exists in the current foundation stack. The old resources validate basic IDs and rate limits, but they do not own the full model for definitions, instances, ownership history, leases, residents, keys, interiors, buckets, doors, storage, wardrobes, garages, furniture, alarms, burglary attempts, creator changes, or audit.

Static risks found:

- legacy dependency on `ox_lib`
- legacy dependency marker for `ox_inventory`
- callbacks expose client-origin property IDs and furniture transforms to old APIs
- no append-only Core DB migration for the complete property model
- no property-specific runtime harness
- no dedicated property key/interior/security resources

The old resources must remain unstaged during this chapter unless a later migration explicitly retires them.
