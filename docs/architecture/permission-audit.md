# Permission Audit

## Purpose

Permission audit records provide an immutable administrative trail for role, permission, owner-protection, and admin-duty changes.

## Table

`nexa_permission_audit` stores:

- Audit ID.
- Action.
- Actor account ID.
- Target account ID.
- Target character ID.
- Role name.
- Permission.
- Old value.
- New value.
- Reason.
- Correlation ID.
- Source resource.
- Result.
- Metadata.
- Timestamp.

## Logged Actions

- Role assigned.
- Role removed.
- Permission granted.
- Permission denied.
- Permission revoked.
- Permission registered.
- Role registered.
- Role inheritance changed.
- Owner role changed.
- Failed self-elevation.
- Failed owner mutation.
- Last-owner protection.
- Permission cache invalidation when relevant.
- Bootstrap owner use.
- Admin-duty set and clear.

## Rules

- Mutating actions require a non-empty reason.
- Failure paths for protected actions are audited.
- Secrets, full identifiers, and client payloads should not be written unfiltered.
- Audit records are append-only.
- Permission audit visibility requires `nexa.permissions.audit`.
