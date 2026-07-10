# nexa_playerstate

Server-authoritative gameplay lifecycle and spawn pipeline for Nexa Roleplay.

## Responsibilities

- Player gameplay lifecycle.
- Spawn preparation and authorization.
- Source/character-bound spawn tokens.
- Last-position persistence.
- Safe fallback spawn.
- Spawn provider registry.
- Routing bucket foundation.
- Basic life-state foundation.
- Position snapshots and disconnect persistence.

## Not Included

- Inventory.
- Money.
- Jobs.
- Clothing.
- Character creator UI.
- Housing.
- Vehicle persistence.
- Hospital gameplay.

## Exports

- `GetPlayerState(source)`
- `IsPlayerActive(source)`
- `IsPlayerReadyForGameplay(source)`
- `GetActiveCharacter(source)`
- `GetLastPosition(sourceOrCharacterId)`
- `RequestSpawn(source)`
- `RegisterSpawnProvider(definition)`
- `GetByAccount(accountId)`
- `GetByCharacter(characterId)`
- `GetTransitionHistory(source)`
- `SetLifeState(actor, target, state, context)`
- `GetLifeState(target)`
- `SetBucket(source, bucket, context)`
- `GetBucket(source)`
- `AllowPositionJump(source, context)`

## Migration

Migration `050_playerstate_foundation` creates:

- `nexa_character_positions`
- `nexa_character_states`

## Security

The client only executes authorized spawn and sends limited position snapshots. It cannot choose spawn position, bucket, character ID, account ID, token, or ready state.
