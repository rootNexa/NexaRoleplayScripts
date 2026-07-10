# nexa_permissions

`nexa_permissions` is the domain resource for Nexa permission administration. It owns the permission catalog, admin/support role seed, account and character role management, owner protection, audit records, and admin-duty state.

The technical decision engine remains in `nexa-core`. This resource uses the Core database abstraction and does not load the oxmysql Lua include directly.

## Responsibilities

- Register known permission names.
- Seed Owner/Admin/Support/Developer/QA roles.
- Seed role inheritance and default role grants.
- Assign and remove account or character roles.
- Grant, deny, and revoke direct account or character permissions.
- Enforce owner protection, hierarchy protection, and self-elevation protection.
- Write audit records for every mutating action.
- Provide server-side admin-duty foundation.
- Keep legacy exports compatible while routing new writes through the Core permission tables.

## Non-Responsibilities

- No admin menu.
- No kick, ban, noclip, spectate, or gameplay action implementation.
- No Discord role sync.
- No client-side permission decisions.
- No direct SQL ownership outside the Core database layer.

## Role Model

Project leadership:

- `owner`
- `co_owner`

Administration:

- `head_admin`
- `senior_admin`
- `admin`
- `trial_admin`

Support:

- `head_support`
- `supporter`
- `support_trainee`

Technical roles:

- `developer`
- `qa_tester`

Roles are only permission collections. Resources must check permissions such as `nexa.admin.kick`, never role names.

## Exports

Read exports:

- `Has(source, permission)`
- `HasAny(source, permissions)`
- `HasAll(source, permissions)`
- `GetPermissions(target)`
- `GetRoles(target)`
- `GetDecisionTrace(actor, target, permission)`
- `GetRole(roleName)`
- `ListRoles()`
- `ListRegisteredPermissions()`
- `GetPermissionCache(source)` legacy alias

Mutating exports:

- `AssignRole(actor, target, role, reason)`
- `RemoveRole(actor, target, role, reason)`
- `GrantPermission(actor, target, permission, reason)`
- `DenyPermission(actor, target, permission, reason)`
- `RevokePermission(actor, target, permission, reason)`
- `RegisterPermission(permission, actor, reason)`
- `RegisterRole(role, actor, reason)`
- `SetRoleInheritance(role, inheritedRole, actor, reason)`

Admin-duty exports:

- `SetAdminDuty(source, state, actor, reason)`
- `GetAdminDuty(source)`
- `IsAdminOnDuty(source)`
- `ClearAdminDuty(source, reason)`

Compatibility exports:

- `AssignRoleToPlayer(sourceOrIdentifier, roleName)`
- `RemoveRoleFromPlayer(sourceOrIdentifier, roleName)`
- `ReloadPermissions()`

## Response Format

Exports return Nexa-compatible response tables:

```lua
{
    ok = true,
    success = true,
    code = 'OK',
    message = '...',
    data = {}
}
```

Failures include `ok = false`, `success = false`, and an `error` table with a public code and message.

## Owner Protection

- Only Owner can assign or remove `owner`.
- Co-Owner cannot mutate Owner.
- Lower roles cannot mutate equal or higher roles unless they have explicit owner-management permission.
- Self-elevation is denied.
- The last Owner cannot be removed.
- Console and controlled bootstrap are the only exceptions.

## ACE

ACE is a bootstrap or fallback mechanism only. Database Deny remains authoritative through the Core decision order. Do not use Discord roles, IP addresses, or hardware identifiers as permission sources.

## Admin Duty

Supported states:

- `off_duty`
- `on_duty`
- `suspended`

Disconnects and resource stop clear in-memory duty state and write an audit entry. Duty-gated operational permissions are documented in `docs/architecture/admin-duty.md`.

## Database

New append-only migration `030_permission_domain` creates:

- `nexa_registered_permissions`
- `nexa_account_roles`
- `nexa_account_permissions`
- `nexa_character_roles`
- `nexa_character_permissions`
- `nexa_permission_audit`
- `nexa_admin_duty`

Core tables from `002_permission_foundation` remain the effective decision source.
