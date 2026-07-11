# GP18 Security Review

GP18 hardening focuses on UI trust boundaries and operational safety.

## Rules

- No client-controlled privileged mutations.
- No direct SQL from NUI or client scripts.
- No framework bridges to QBCore, Qbox, ESX, ox_lib or ox_inventory.
- Admin actions require server-side permissions and audit logs.
- Feature flags are server-owned.
- Error details shown to clients must be safe public messages.

## Review Checklist

- Validate every NUI callback.
- Bind every network request to actual FiveM source.
- Keep creator registry metadata non-sensitive.
- Do not log secrets, tokens, passwords or full IP addresses.
- Prefer official Nexa callbacks and exports over raw events.
