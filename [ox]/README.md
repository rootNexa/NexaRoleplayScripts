# [ox]

Ox infrastructure layer for local development. Expected runtime dependencies:

- `oxmysql`
- `ox_lib`
- `ox_inventory`
- `ox_target`
- `ox_doorlock`

For the Nexa framework foundation, `setr inventory:framework "ox"` must be set before `ensure ox_inventory`.

In local Windows development, the active Ox resources may be directory junctions. See `docs/DEVELOPMENT_ENVIRONMENT.md`.
