# Identity to PlayerState Spawn Flow

The production character selection flow is server-authoritative:

1. `nexa-identity` NUI sends only the selected character id to the identity client.
2. The identity client forwards the request to `nexa-identity:server:selectCharacter`.
3. `nexa-identity` calls `exports['nexa-character']:SelectCharacter(source, characterId)`.
4. `nexa-identity` verifies the active character server-side via `GetActiveCharacter`.
5. `nexa-identity` calls `exports['nexa_playerstate']:RequestSpawn(source)`.
6. `nexa_playerstate` resolves spawn data, creates a source/character-bound token and sends `nexa:playerstate:client:spawnExecute`.
7. The playerstate client applies the authorized spawn and confirms with the token.
8. `nexa_playerstate` transitions to `active` and emits `nexa:player:ready`.
9. `nexa-identity` clears its pending spawn guard.

The identity UI is closed only after character selection succeeded and the
server-side `RequestSpawn(source)` call was accepted. The client never selects
position, character id authority, spawn status or routing bucket.

## Failure Handling

- `nexa_playerstate` not started: identity returns `RESOURCE_NOT_STARTED`.
- Active character missing or mismatched: identity returns `NOT_FOUND`.
- Spawn request rejected: identity forwards a safe spawn error to the UI.
- Spawn confirmation timeout: `nexa_playerstate` transitions the state to failed;
  identity clears its pending guard after its own timeout.
- Disconnect: identity clears pending spawn state on `playerDropped`.
- Duplicate select/spawn request: identity returns `SPAWN_ALREADY_PENDING` while
  a previous accepted spawn request is still pending.
- Duplicate direct `RequestSpawn(source)` calls are rejected by `nexa_playerstate`
  while the state is `spawn_preparing`, `spawn_authorized` or `spawning`.

## Deprecated Path

`nexa-spawn:client:requestSpawn` is no longer part of the production
identity/character flow. `nexa-spawn` may remain in the repository as a
deprecated helper, but it must not be started alongside `nexa_playerstate`.
