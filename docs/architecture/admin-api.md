# Admin API

## Exports

- `WarnPlayer`
- `KickPlayer`
- `BanPlayer`
- `UnbanPlayer`
- `GoToPlayer`
- `BringPlayer`
- `ReturnPlayer`
- `SetPlayerFrozen`
- `HealPlayer`
- `RevivePlayer`
- `StartSpectate`
- `StopSpectate`
- `StartNoclip`
- `StopNoclip`
- `CreateAdminNote`
- `ListAdminNotes`
- `GetAdminActionState`
- `ResolveConnection`
- `IsAccountBanned`
- `ListActions`

## Callbacks

Callbacks are registered through `nexa_api:RegisterServerCallback` and mirror the export adapters. They do not bypass the action registry.
