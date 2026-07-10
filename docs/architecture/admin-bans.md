# Admin Bans

Bans are account-based and stored in `nexa_admin_bans`.

## Types

- `temporary`
- `permanent`
- revoked by `active = 0`
- expired by `expires_at <= CURRENT_TIMESTAMP`

Identifiers are stored as references only and must not become the sole account authority.

## Connection Enforcement

`nexa_identity` calls `nexa_admin:ResolveConnection` when `nexa_admin` is started. Active bans reject the connection with a safe public message.
