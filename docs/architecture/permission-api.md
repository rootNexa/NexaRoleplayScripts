# Permission API

## Read API

| Export | Purpose |
| --- | --- |
| `Has(source, permission)` | Check a source against a registered permission. |
| `HasAny(source, permissions)` | Check if any permission is allowed. |
| `HasAll(source, permissions)` | Check if all permissions are allowed. |
| `GetPermissions(target)` | Load effective permissions for a subject. |
| `GetRoles(target)` | Load assigned roles for a subject. |
| `GetDecisionTrace(actor, target, permission)` | Load trace when actor has `nexa.permissions.audit`. |
| `GetRole(roleName)` | Read one role. |
| `ListRoles()` | List seeded and registered roles. |
| `ListRegisteredPermissions()` | List catalog permissions. |

## Mutating API

| Export | Required Permission |
| --- | --- |
| `AssignRole(actor, target, role, reason)` | `nexa.permissions.assign_role` |
| `RemoveRole(actor, target, role, reason)` | `nexa.permissions.remove_role` |
| `GrantPermission(actor, target, permission, reason)` | `nexa.permissions.grant` |
| `DenyPermission(actor, target, permission, reason)` | `nexa.permissions.deny` |
| `RevokePermission(actor, target, permission, reason)` | `nexa.permissions.revoke` |
| `RegisterPermission(permission, actor, reason)` | `nexa.permissions.grant` |
| `RegisterRole(role, actor, reason)` | `nexa.permissions.assign_role` |
| `SetRoleInheritance(role, inheritedRole, actor, reason)` | `nexa.permissions.assign_role` |

Every mutating export requires a reason and writes audit.

## Error Codes

- `PERMISSION_NOT_FOUND`
- `ROLE_NOT_FOUND`
- `ROLE_ALREADY_ASSIGNED`
- `ROLE_NOT_ASSIGNED`
- `PERMISSION_ALREADY_GRANTED`
- `PERMISSION_ALREADY_DENIED`
- `PERMISSION_NOT_ASSIGNED`
- `ROLE_HIERARCHY_FORBIDDEN`
- `OWNER_PROTECTION`
- `LAST_OWNER_PROTECTION`
- `SELF_ELEVATION_FORBIDDEN`
- `ROLE_INHERITANCE_CYCLE`
- `ACTOR_NOT_AUTHORIZED`
- `TARGET_NOT_FOUND`
- `AUDIT_REASON_REQUIRED`

## Target Format

Targets may be:

- Online source.
- `{ type = 'account', id = accountId }`.
- `{ type = 'character', id = characterId }`.
- Legacy identifier when resolvable through `nexa_identity`.
