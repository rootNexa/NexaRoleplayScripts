# Permission Architecture

## Purpose

The Nexa permission system is server-authoritative. It separates technical decision logic from domain administration:

- `nexa-core` owns the technical engine, cache, inheritance evaluation, Deny precedence, and ACE fallback.
- `nexa_permissions` owns the permission catalog, role model, role assignment, owner protection, audit, admin-duty state, and compatibility exports.

No gameplay resource should make a permission decision on the client.

## Data Ownership

Effective decisions are based on Core tables:

- `nexa_permission_roles`
- `nexa_permission_role_permissions`
- `nexa_permission_role_inheritance`
- `nexa_permission_subject_roles`
- `nexa_permission_subject_permissions`

Domain administration adds:

- `nexa_registered_permissions`
- `nexa_account_roles`
- `nexa_account_permissions`
- `nexa_character_roles`
- `nexa_character_permissions`
- `nexa_permission_audit`
- `nexa_admin_duty`

Account permissions are OOC/admin permissions. Character permissions are reserved for character-scoped rules and must not be mixed with Owner/Admin/Support authority.

## Permission Names

All permissions use:

```text
nexa.<area>.<action>
```

Unknown permissions are denied by default. Wildcards are controlled and only valid at the end, for example `nexa.admin.*`.

## Role Rules

Roles are collections of permissions. Resources must never compare roles directly for access control. A resource checks `nexa.admin.kick`, not `role == "admin"`.

## Security Boundaries

- Client payloads never decide roles or permissions.
- Discord roles are not a source of truth in this chapter.
- IP addresses and hardware identifiers are never permission sources.
- Mutating exports require actor context, target context, hierarchy checks, reason, audit, and cache invalidation.
- Owner mutations have additional protection.

## Compatibility

Legacy callers can continue using `Has`, `HasAny`, `HasAll`, `GetRoles`, `AssignRoleToPlayer`, and `RemoveRoleFromPlayer`. New code should prefer actor-aware exports.
