# nexa-character

Character foundation resource for the Nexa Framework.

This resource owns the server-facing Character API for later UI resources. It does not build character selection UI, identity UI, jobs, inventory, or gameplay systems.

## Dependencies

- `nexa-core`

Database access is delegated to `nexa-core` exports. This resource does not access the database directly.

## Exports

- `exports['nexa-character']:ListCharacters(source)`
- `exports['nexa-character']:CreateCharacter(source, data)`
- `exports['nexa-character']:SelectCharacter(source, characterId)`
- `exports['nexa-character']:GetActiveCharacter(source)`
- `exports['nexa-character']:UpdateCharacter(source, data)`

## Events

Server:

- `nexa-character:server:list`
- `nexa-character:server:create`
- `nexa-character:server:select`
- `nexa-character:server:update`

Client:

- `nexa-character:client:charactersLoaded`
- `nexa-character:client:characterSelected`
- `nexa-character:client:characterUpdated`

## Security

- The server validates `source`.
- Character ownership is enforced by `nexa-core`.
- Client payloads cannot set player IDs, permissions, jobs, groups, or generated IDs.
- Coordinates, sessions, permissions, and database writes are never trusted from the client.
- No sensitive player data is sent by this resource.

## Development Order

```cfg
ensure oxmysql
ensure nexa-core
ensure nexa-character
ensure nexa-spawn
ensure nexa-core-test
```
