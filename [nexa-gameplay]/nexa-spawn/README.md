# nexa-spawn

Minimal development spawn flow for the Nexa Framework foundation.

This resource exists only to unblock local runtime testing after the framework moved away from legacy spawn resources. It closes the loading screen and places the player at one configured development spawn point.

## Dependencies

- `nexa-core`

It does not use inventory resources, legacy framework resources, a database connection, NUI, identity, or character selection.

## Events

- `nexa-spawn:server:requestInitialSpawn`
- `nexa-spawn:client:spawnApproved`

The client only requests the initial spawn. The server validates `source` and returns the configured default spawn. Client-supplied coordinates are never accepted.

## Development Order

Use this order in the foundation development config:

```cfg
ensure oxmysql
ensure nexa-core
ensure nexa-spawn
ensure nexa-core-test
```
