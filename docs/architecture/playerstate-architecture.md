# Playerstate Architecture

`nexa_playerstate` owns gameplay readiness after account resolution and character selection.

Sessions remain in `nexa-core`, accounts in `nexa_identity`, and character ownership in `nexa_characters`. Character selection is not gameplay-ready until the spawn pipeline completes and the server transitions the state to `active`.

Dependencies:

- `nexa-core`
- `nexa_identity`
- `nexa_characters`
- `nexa_api`

`nexa_admin` may depend on `nexa_playerstate` for recovery and position-jump integration.
