# Spawn Pipeline

1. Session exists.
2. Identity is ready.
3. Character is selected.
4. Playerstate loads persistent state.
5. Spawn provider resolves.
6. Server validates spawn.
7. Server creates source/character-bound token.
8. Client receives authorized spawn.
9. Client applies fade, freeze, collision and coordinates.
10. Client confirms token.
11. Server validates token and transitions to `active`.

The client cannot provide arbitrary spawn coordinates.
