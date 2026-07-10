# Playerstate Operations

Development start order should start `nexa_playerstate` after `nexa_identity` and `nexa_characters`.

`nexa-spawn` is a deprecated development helper and should not be the production lifecycle owner once playerstate is enabled.

Resource restart limits are FiveM-dependent. Live players may need a controlled reconnect if a restart interrupts a spawn token.
