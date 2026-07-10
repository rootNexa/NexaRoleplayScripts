# nexa-admin-runtime-tests

Development-only runtime harness for `nexa_admin`.

Do not autostart this resource in production.

## Command

```text
nexa_test_admin_runtime [suite]
```

Suites:

- `warnings`
- `bans`
- `kick`
- `teleport`
- `freeze`
- `recovery`
- `spectate`
- `noclip`
- `notes`
- `security`
- `restart`
- `all`

Most suites require a running FXServer with safe test accounts and therefore report `open` until executed manually.
