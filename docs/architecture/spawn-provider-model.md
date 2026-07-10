# Spawn Provider Model

Providers define:

- `name`
- `priority`
- `CanProvide(context)`
- `Resolve(context)`
- `Validate(result)`
- optional `OnSpawned(context)`

Initial providers:

- `last_position`, priority 100.
- `safe_fallback`, priority 0.

Higher priority wins only when the resolved result validates.
