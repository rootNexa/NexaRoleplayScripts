# Player Lifecycle

Allowed lifecycle states:

```text
disconnected -> connected -> session_ready -> identity_ready -> character_selection
character_selection -> character_selected -> state_loading -> spawn_preparing
spawn_preparing -> spawn_authorized -> spawning -> active
active -> incapacitated -> dead
active/incapacitated/dead -> unloading -> disconnected
any loading state -> failed -> unloading
```

Invalid transitions are denied and added to bounded transition history.

Gameplay resources should require `IsPlayerReadyForGameplay(source)`.
