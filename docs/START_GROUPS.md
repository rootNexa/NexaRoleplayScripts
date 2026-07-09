# Start Groups

## Foundation Core

Start these resources in order for the current foundation flow:

```cfg
ensure oxmysql
ensure chat
ensure nexa-lib
ensure nexa-core
ensure nexa-character
ensure nexa-identity
ensure nexa-spawn
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

`nexa_api` belongs after `nexa_permissions` so permission bridge calls can use the dedicated permission service when available.
