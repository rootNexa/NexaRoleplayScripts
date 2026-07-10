# nexa-items-runtime-tests

Development-only runtime harness for `nexa_items`.

Do not autostart this resource in production.

Command:

```text
nexa_test_items_runtime [suite]
```

Suites:

- `registry`
- `metadata`
- `stacking`
- `durability`
- `expiration`
- `actions`
- `assets`
- `studio`
- `inventory`
- `security`
- `restart`
- `all`

Most suites require a running FXServer and isolated test definitions. Without FXServer they remain open.
