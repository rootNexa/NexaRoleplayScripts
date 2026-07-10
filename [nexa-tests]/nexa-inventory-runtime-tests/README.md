# nexa-inventory-runtime-tests

Development-only runtime harness for `nexa_inventory`.

Do not autostart this resource in production.

Command:

```text
nexa_test_inventory_runtime [suite]
```

Suites:

- `create`
- `addremove`
- `slots`
- `transfer`
- `quickslots`
- `containers`
- `drops`
- `integrity`
- `security`
- `restart`
- `all`

Most suites require a running FXServer and isolated test inventories. Without FXServer they remain open.
