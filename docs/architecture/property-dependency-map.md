# Property Dependency Map

Start order:

1. `nexa-core`
2. `nexa_identity`
3. `nexa_characters`
4. `nexa_playerstate`
5. `nexa_permissions`
6. `nexa_economy`
7. `nexa_inventory`
8. `nexa_garages`
9. `nexa_properties`
10. `nexa_propertykeys`
11. `nexa_property_interiors`
12. `nexa_property_security`

Allowed direct dependencies:

- `nexa_properties -> nexa-core, nexa_characters, nexa_permissions, nexa_playerstate, nexa_economy, nexa_inventory, nexa_garages`
- `nexa_propertykeys -> nexa-core, nexa_properties, nexa_characters, nexa_permissions`
- `nexa_property_interiors -> nexa-core, nexa_properties, nexa_playerstate`
- `nexa_property_security -> nexa-core, nexa_properties, nexa_propertykeys, nexa_inventory`

No reverse dependency from Core, Economy, Characters, Inventory or Garages is allowed.
