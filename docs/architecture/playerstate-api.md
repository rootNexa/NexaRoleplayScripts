# Playerstate API

Exports:

- `GetPlayerState`
- `IsPlayerActive`
- `IsPlayerReadyForGameplay`
- `GetActiveCharacter`
- `GetLastPosition`
- `RequestSpawn`
- `RegisterSpawnProvider`
- `GetByAccount`
- `GetByCharacter`
- `GetTransitionHistory`
- `SetLifeState`
- `GetLifeState`
- `SetBucket`
- `GetBucket`
- `AllowPositionJump`

Internal events:

- `nexa:internal:playerstate:stateChanged`
- `nexa:internal:playerstate:spawnPreparing`
- `nexa:internal:playerstate:spawnAuthorized`
- `nexa:internal:playerstate:active`
- `nexa:internal:playerstate:unloading`
- `nexa:internal:playerstate:failed`
