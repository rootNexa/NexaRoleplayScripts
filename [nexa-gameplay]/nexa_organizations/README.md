# nexa_organizations

`nexa_organizations` is the server-authoritative foundation for organizations, ranks, memberships, invitations, organization permissions, modules, storage and garage registration.

## Boundaries

- Duty runtime belongs to `nexa_jobs`.
- Bank balances belong to `nexa_economy`.
- Items and storage mutation belong to `nexa_inventory`.
- OOC admin roles stay in `nexa_permissions`.

## Organization Types

Supported defaults: `police`, `ems`, `government`, `gang`, `business`, `media`, `taxi`, `mechanic`, `custom`, `security`, `fire_department`.

## Rules

- One active primary organization per character.
- At least 5 and at most 15 ranks for activation.
- Exactly one owner rank.
- Organization permissions are IC rank permissions and use `organization.*`.
- Mutations require actor context, reason where sensitive, hierarchy checks and audit.

## Exports

The resource exposes organization reads, rank/member operations, invitations, permission checks, module enable/disable, storage registration and garage registration. It has no legacy framework bridge or direct database-driver dependency.
