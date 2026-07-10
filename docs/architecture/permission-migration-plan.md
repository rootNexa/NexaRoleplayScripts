# Permission Migration Plan

## Goal

Migrate Nexa from a partial legacy permission resource to a server-authoritative domain system built on the Core permission engine. The migration must preserve existing callers while eliminating direct oxmysql usage and role-name checks.

## Migration Order

1. Document current state and target role model.
2. Add a permission catalog and role hierarchy seed to `nexa_permissions`.
3. Add append-only Core migrations for catalog, audit, role metadata, account aliases, and admin-duty state.
4. Refactor `nexa_permissions` to use `exports['nexa-core']:GetCoreObject().Database`.
5. Keep legacy exports as wrappers with stable return format.
6. Add actor-aware mutating exports and owner protection.
7. Add audit logging for every mutation and failed protected mutation.
8. Add admin-duty foundation.
9. Add validators for static safety checks.
10. Run core, identity/character, and permission validators.

## Found Legacy Items

| Finding | Purpose | Problem | Recommended Measure | Risk | Order |
| --- | --- | --- | --- | --- | --- |
| `nexa_permissions` direct `MySQL.*` calls | Reads/writes role and assignment data | Breaks core DB ownership rule | Replace with Core DB abstraction calls | High | 4 |
| `@oxmysql/lib/MySQL.lua` in `nexa_permissions/fxmanifest.lua` | Enables direct DB access | Forbidden outside core DB layer | Remove script include and `oxmysql` dependency | High | 4 |
| `sql/001_permissions_roles.sql` | Manual legacy schema | Duplicates Core migration tables and is not append-only tracked | Keep as historical reference, do not require import; use Core migrations | Medium | 3 |
| `nexa_permission_assignments` | Old player/identifier/character role assignment | Mixes player IDs, identifiers, and characters | Migrate to `nexa_permission_subject_roles` with subject type | Medium | 4 |
| Legacy `admin` role | Broad wildcard admin permission | Does not match Chapter 03 role model | Replace seed with Owner/Admin/Support hierarchy | Medium | 2 |
| ACE evaluated in legacy resource | Bootstrap/fallback | ACE can override DB Deny in legacy path | Delegate effective decision to Core, where DB Deny wins first | Medium | 4 |
| `/nexaassignrole` dev command | Manual assignment testing | Missing actor, reason, owner protection | Route through protected `AssignRole` with console actor and reason | Medium | 6 |
| `nexa-core` technical permission API | Boolean permission checks | Domain catalog missing | Keep technical engine; add domain catalog in `nexa_permissions` | Low | 2 |

## Compatibility Rules

- Keep `Has(source, permission)` returning `{ ok, data, error }`.
- Keep `HasAny`, `HasAll`, `GetRoles`, `AssignRoleToPlayer`, `RemoveRoleFromPlayer`, `ReloadPermissions`, and `GetPermissionCache`.
- Add new server exports without removing old names.
- Do not change `nexa_api:HasPermission` or `nexa-core:HasPermission` signatures.
- Existing source-based checks must continue to work for online players.

## Data Migration Rules

- Migrations are append-only.
- Existing migration `002_permission_foundation` must not be edited.
- New migration creates:
  - `nexa_registered_permissions`
  - `nexa_permission_audit`
  - `nexa_admin_duty`
  - compatibility views/tables only where necessary
- Legacy table `nexa_permissions` remains readable for fallback until a later cleanup chapter.
- Legacy `nexa_permission_assignments` may be read for compatibility if present, but new writes go to subject tables.

## Owner Bootstrap

Owner bootstrap must be explicit and server-side:

- No hardcoded license in Lua.
- Optional ACE bootstrap permission can grant controlled first owner.
- Optional server config can name allowed bootstrap principals locally, but secrets/identifiers are not committed.
- Once an owner exists, only Owner can assign or remove Owner.

## Removal Criteria

Legacy paths can be removed when:

- No resource calls old assignment exports except compatibility wrappers.
- All accounts use `nexa_permission_subject_roles`.
- `nexa_permission_assignments` has been migrated or is empty.
- Runtime logs show no deprecated mutation usage.
- Validators pass with no direct oxmysql in `nexa_permissions`.

## Runtime Tests Requiring FXServer

- Real ACE bootstrap against connected player source.
- Player disconnect clearing admin duty.
- Race condition behavior for last-owner removal in live DB.
- Cross-resource exports from resources started in production order.
