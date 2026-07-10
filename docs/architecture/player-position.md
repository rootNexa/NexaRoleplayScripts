# Player Position

`nexa_character_positions` stores:

- character ID
- coordinates
- heading
- routing bucket
- position type
- validity
- version
- metadata

Snapshots are rate-limited and validated for coordinate range and implausible jumps. Admin teleports can call `AllowPositionJump`.
