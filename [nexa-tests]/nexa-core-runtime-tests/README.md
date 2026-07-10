# nexa-core-runtime-tests

Manual FXServer runtime acceptance harness for `nexa-core` chapter 01.

This resource is intentionally separate from the normal foundation stack. It is not a gameplay resource, does not add UI, does not replace the existing `[standalone]/nexa-core-test`, and must not be ensured in production.

## Start

Start it only after `oxmysql` and `nexa-core` are running:

```cfg
ensure oxmysql
ensure nexa-core
ensure nexa-core-runtime-tests
```

The repository `server/foundation.dev.cfg` is not changed by this harness. For a one-off run, start it from the FXServer console:

```text
ensure nexa-core-runtime-tests
nexa_test_core_runtime all
```

## Command

```text
nexa_test_core_runtime [suite]
```

Supported suites:

- `all`
- `core_readiness`
- `database_health`
- `public_exports_defensive`
- `event_bus`
- `cache_runtime`
- `callbacks_runtime`
- `sessions_runtime`
- `permissions_runtime`
- `modules_runtime`
- `manual_runtime_boundaries`

Console execution is allowed. Player execution requires ACE:

```cfg
add_ace group.admin nexa.test.core_runtime allow
```

## Safety

The harness is designed for runtime acceptance, not production automation.

- No forbidden framework dependency.
- No gameplay systems.
- No direct client trust.
- No automatic character creation or mutation.
- No automatic permission writes.
- No destructive database writes.
- Mutating exports are reported as skipped unless a later isolated test database flow is explicitly added.

## Result Format

Each test writes one structured console line with:

- `suite`
- `status`: `pass`, `fail`, or `skip`
- `code`
- `message`
- `durationMs`
- optional `data`

The final line contains a summary:

```json
{"pass":8,"fail":0,"skip":1,"total":9}
```

Skipped tests are not counted as success. They mark cases that require a real player, a controlled restart, an unavailable database, or a deliberately stopped dependency.
