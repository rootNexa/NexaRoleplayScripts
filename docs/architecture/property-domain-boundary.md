# Property Domain Boundary

`nexa_properties` owns property identity, definitions, instances, ownership, sales, leases, rent, residents, storage links, garage links, furniture persistence metadata, admin actions, creator lifecycle and audit.

`nexa_propertykeys` owns key grants, key revocation, permission checks and door access history.

`nexa_property_interiors` owns interior definitions, instances, routing buckets, entry tokens, exit tokens, occupants and furniture bounds.

`nexa_property_security` owns lock state, alarm status, security events and burglary attempt lifecycle.

External domains:

- `nexa_economy` performs all money movement.
- `nexa_inventory` owns storage inventory mutation.
- `nexa_garages` owns vehicle storage/retrieval.
- `nexa_characters` resolves character identity.
- `nexa_permissions` gates admin and creator actions.

Clients may request actions, but they never authoritatively set owner, lease, key, bucket, storage, garage, door, alarm or persisted furniture state.
