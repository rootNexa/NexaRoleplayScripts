# nexa_admin_ui

GP18 admin operations surface for Nexa Roleplay.

The resource is a NUI shell for diagnostics, beta readiness, creator discovery,
feature flag review, security review entry points and operational dashboards.
It does not implement gameplay mutations and does not duplicate backend domain
logic. Runtime data is consumed through official Nexa services, primarily
`nexa_beta` and the Nexa callback API.

## Scope

- Admin navigation shell
- Read-only readiness and health overview
- Creator registry overview
- Foundation for later secured admin workflows

## Out of Scope

- Direct database editing
- Gameplay-specific authority
- Legacy framework bridges
- Unsafe client-trusted mutations
