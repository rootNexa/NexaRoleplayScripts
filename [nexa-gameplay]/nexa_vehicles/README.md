# nexa_vehicles

`nexa_vehicles` is the server-authoritative foundation for vehicle definitions, persisted vehicles, ownership, lifecycle, spawn authorization, state snapshots, damage, fuel, mileage, insurance, maintenance, tuning metadata and theft/admin integration.

Clients may request actions through dedicated gameplay resources, but ownership, VIN, plate, model, garage, impound, spawn token and persisted state are decided by the server.

## Boundaries

- No legacy framework bridge.
- No direct database driver access.
- No client-trusted ownership or identity fields.
- No inventory, shop or UI logic in this resource.

## Core Exports

- `CreateVehicle(actor, payload)`
- `RegisterVehicleDefinition(payload)`
- `GetVehicle(id)`
- `GetVehicleByVin(vin)`
- `GetVehicleByPlate(plate)`
- `ListCharacterVehicles(characterId)`
- `ListOrganizationVehicles(organizationId)`
- `TransferVehicle(actor, vehicleId, ownerType, ownerId, reason)`
- `RequestVehicleSpawn(actor, vehicleId, options)`
- `ConfirmVehicleSpawn(actor, token, netId, entityHandle)`
- `RequestVehicleDespawn(actor, vehicleId, reason)`
- `GetVehicleState(vehicleId)`
- `UpdateVehicleState(actor, vehicleId, snapshot)`
- `RecordVehicleDamage(actor, vehicleId, snapshot)`
- `GetVehicleFuel(vehicleId)` / `SetVehicleFuel(actor, vehicleId, fuel)`
- `GetVehicleMileage(vehicleId)` / `RecordVehicleMileage(actor, vehicleId, delta)`
- `GetVehicleMods(vehicleId)`
- `ApplyVehicleMods(actor, vehicleId, mods)`
- `CreateVehicleInsurance(actor, vehicleId, payload)`
- `RecordVehicleMaintenance(actor, vehicleId, payload)`
- `IsVehicleMaintenanceDue(vehicleId)`
- `BeginVehicleLockpick(actor, vehicleId)` / `BeginVehicleHotwire(actor, vehicleId)`
- `ResolveVehicleTheftAttempt(actor, vehicleId, successful)`
- `AdminSetVehicleStatus(actor, vehicleId, status, reason)`

## Persistence

Migration `110_vehicles_foundation` creates definitions, persisted vehicles, insurance and audit tables. Related domains such as keys, garages and impound have their own resources.

## State Foundation

Vehicle state snapshots are clamped server-side. Fuel, mileage, engine health, body health and tank health are persisted through the Core database layer. Damage state is derived from submitted health snapshots and never accepted as an ownership or lifecycle authority.

## Insurance, Maintenance And Tuning

Insurance policies are persisted in `nexa_vehicle_insurance`. Maintenance history is stored as structured metadata for the foundation phase and exposes a due check based on mileage intervals. Tuning data is stored as server-owned JSON in `mods_json` so later mechanic gameplay can validate changes before they reach persisted state.

## Theft And Admin Foundation

The theft foundation records and resolves attempts only. It does not transfer ownership, grant keys or change persisted identity. Admin status changes are exposed through an audited export for later permission-gated admin tools.
