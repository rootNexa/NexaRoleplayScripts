# Start Groups

## Foundation Core

Start these resources in order for the current foundation flow:

```cfg
ensure oxmysql
ensure chat
ensure nexa-lib
ensure nexa-core
ensure nexa_identity
ensure nexa_characters
ensure nexa_playerstate
ensure nexa-character
ensure nexa-identity
ensure nexa_config
ensure nexa_locales
ensure nexa_audit
ensure nexa_logs
ensure nexa_featureflags
ensure nexa_permissions
ensure nexa_api
ensure nexa_security
ensure nexa-core-test
ensure nexa-character-test
```

`nexa_playerstate` is the only authoritative spawn lifecycle resource. `nexa-spawn` is a deprecated development helper and must not be started in the current foundation flow.

`nexa_api` belongs after `nexa_permissions` so permission bridge calls can use the dedicated permission service when available.

`nexa-core` now has a controlled lifecycle. It requires `oxmysql` to be started and reachable before the Core can move to `ready`. If `oxmysql` is missing or stops while the Core is ready, the Core enters `failed` and public Core APIs must not report false readiness.

For lifecycle details, see `docs/architecture/core-lifecycle.md`.
