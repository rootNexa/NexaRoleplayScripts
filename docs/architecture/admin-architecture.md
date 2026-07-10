# Admin Architecture

`nexa_admin` is the server-authoritative domain resource for Chapter 04 admin actions. It depends on `nexa-core`, `nexa_identity`, `nexa_characters`, `nexa_permissions`, and `nexa_api`.

The Core never depends on `nexa_admin`. Permissions and duty remain owned by `nexa_permissions`.

## Boundaries

- No full admin UI.
- No ticket system expansion.
- No inventory, money, vehicle, or character editing.
- No Discord bot control.
- No framework bridges.

## Runtime Flow

1. Command, callback, or export calls an admin adapter.
2. Adapter calls `AdminActions.Execute`.
3. Action registry validates permission, duty, target, reason, and rate limit.
4. Handler performs one bounded domain action.
5. Domain table and `nexa_admin_actions` receive records.
6. Client receives only effect events where required.
