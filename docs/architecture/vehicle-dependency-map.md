# Vehicle Dependency Map

- `nexa_vehicles -> nexa-core, nexa_identity, nexa_characters, nexa_playerstate, nexa_permissions, nexa_economy, nexa_organizations`
- `nexa_vehiclekeys -> nexa_vehicles, nexa_characters, nexa_permissions`
- `nexa_garages -> nexa_vehicles, nexa_characters, nexa_organizations, nexa_playerstate`
- `nexa_impound -> nexa_vehicles, nexa_organizations, nexa_permissions, nexa_economy`

Nicht erlaubt sind Reverse-Dependencies aus Core, Economy oder Characters.
