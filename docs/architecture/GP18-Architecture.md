# GP18 Architecture

GP18 turns the GP01-GP17 foundations into an integrated Nexa operations layer.
It does not introduce new gameplay domains. The goal is unification, creator
discoverability, admin operation surfaces, hardening, performance visibility and
alpha/beta readiness.

## Resource Roles

- `nexa_ui` provides shared UI primitives: panels, notify, context, input,
  window surfaces, loading overlays and error overlays.
- `nexa_beta` is the GP18 integration and readiness resource. It tracks creator
  surfaces, feature flags, performance snapshots, release metadata and health.
- `nexa_admin_ui` is a read-only operations UI shell. It consumes official Nexa
  APIs and does not implement gameplay authority.
- `nexa-beta-runtime-tests` validates GP18 runtime wiring inside FXServer.

## Creator Model

Creators are registered by type and resource. A creator is an administrative
surface for a domain such as jobs, vehicles, items, housing, shops, dispatch,
medical, evidence or licenses. The registry is intentionally generic so later
creator UIs can be discovered without hardcoded menu logic.

## Admin Model

Admin UI is a presentation layer only. Mutations must remain behind server-side
permissions and official callbacks. The UI may display players, characters,
vehicles, inventories, housing, businesses, dispatch, MDT, evidence, banking,
logs, security, audit, performance and feature flags, but each action must be
implemented by the owning backend service.

## Integration Rules

- No QBCore, Qbox, ESX, ox_lib or ox_inventory dependencies.
- UI consumes official Nexa callbacks and exports only.
- Domain resources own their business logic and database writes.
- `nexa_beta` may observe health and registry state, but it must not become a
  second gameplay framework.
- Runtime checks must be additive and safe to run on a live test server.

## Start Order

Recommended order for GP18 surfaces:

1. `oxmysql`
2. `nexa_core`
3. `nexa_api`
4. `nexa_permissions`
5. `nexa_ui`
6. domain foundations from GP01-GP17
7. `nexa_beta`
8. `nexa_admin_ui`
9. `nexa-beta-runtime-tests` on test environments

## Alpha and Beta Gates

Alpha is reached when all resources start, UI primitives render, creators are
registered, health can be collected and validators pass. Beta is reached after
manual FXServer runtime testing, permission review, performance baseline review
and a documented release checklist.
