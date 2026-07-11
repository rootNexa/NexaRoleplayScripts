# nexa-playerstate-runtime-tests

Development-only runtime harness for `nexa_playerstate`.

Do not autostart this resource in production.

Command:

```text
nexa_test_playerstate_runtime [suite]
```

Suites:

- `lifecycle`
- `spawn`
- `position`
- `bucket`
- `lifestate`
- `identity_spawn`
- `disconnect`
- `restart`
- `security`
- `all`

Most suites require FXServer and report `open` until manually executed.
`identity_spawn` verifies the production resource trio is running and then
requires a live selected-character fixture for end-to-end execution.
