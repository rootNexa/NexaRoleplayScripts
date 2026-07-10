# Permission Decision Order

Effective checks follow this order:

1. Explicit account Deny.
2. Explicit character Deny when a character subject is checked.
3. Role Deny.
4. Direct account Allow.
5. Direct character Allow.
6. Role Allow.
7. ACE fallback when enabled and available.
8. Default Deny.

The Core engine enforces Deny-before-Allow by splitting cached rules into deny and allow sets and testing deny candidates first.

## Decision Trace

A trace contains:

- Requested permission.
- Subject type and ID.
- Matching roles.
- Direct and role-derived rules.
- Matched wildcard or exact permission.
- ACE fallback result when used.
- Final decision and reason.

Decision traces are sensitive. `nexa_permissions:GetDecisionTrace` requires `nexa.permissions.audit`.

## Unknown Permissions

`nexa_permissions` keeps a registered catalog. If a permission is not registered, the domain API returns `allowed = false` with reason `PERMISSION_NOT_FOUND`. This prevents typo-based accidental Allows.
