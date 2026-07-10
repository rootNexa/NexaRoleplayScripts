# Property Data Model

Core tables:

- `nexa_property_definitions`
- `nexa_properties`
- `nexa_property_ownership_history`
- `nexa_property_leases`
- `nexa_property_residents`
- `nexa_property_keys`
- `nexa_property_interiors`
- `nexa_property_furniture`
- `nexa_property_security_events`
- `nexa_property_audit`

Specialized resources add door/access, interior occupant and security state tables. All tables are created through append-only Core DB migrations. Records are soft-deleted or statused where history matters.
