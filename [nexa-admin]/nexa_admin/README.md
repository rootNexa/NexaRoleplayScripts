# nexa_admin

Server-authoritative admin foundation for Nexa Roleplay.

## Purpose

`nexa_admin` owns the technical foundation for admin actions:

- warnings
- kicks
- temporary and permanent bans
- unbans
- teleport, bring, goto and return
- freeze
- admin heal and revive recovery
- spectate state
- noclip state
- admin notes
- action audit
- command and export adapters

It does not provide a full NUI admin menu in this chapter.

## Dependencies

- `nexa-core`
- `nexa_identity`
- `nexa_characters`
- `nexa_permissions`
- `nexa_api`

No legacy framework bridge, old UI library dependency or direct database-driver usage is allowed.

## Security Model

- All actions are checked server-side.
- Commands and callbacks are thin adapters.
- Client events only apply server-approved effects.
- Mutating actions require reasons.
- Duty-gated actions use `nexa_permissions` admin-duty state.
- Actor source is always the real FiveM source.
- Bans are account-based; identifiers are enforcement references only.

## Canonical Exports

- `WarnPlayer(actorSource, targetSource, reason)`
- `KickPlayer(actorSource, targetSource, reason)`
- `BanPlayer(actorSource, targetSourceOrAccountId, reason, durationMinutes)`
- `UnbanPlayer(actorSource, banId, reason)`
- `GoToPlayer(actorSource, targetSource)`
- `BringPlayer(actorSource, targetSource)`
- `ReturnPlayer(actorSource, targetSource)`
- `SetPlayerFrozen(actorSource, targetSource, state, reason)`
- `HealPlayer(actorSource, targetSource, reason)`
- `RevivePlayer(actorSource, targetSource, reason)`
- `StartSpectate(actorSource, targetSource)`
- `StopSpectate(actorSource)`
- `StartNoclip(actorSource)`
- `StopNoclip(actorSource)`
- `CreateAdminNote(actorSource, target, payload)`
- `ListAdminNotes(actorSource, target)`
- `GetAdminActionState(source)`
- `ResolveConnection(identityContext)`
- `IsAccountBanned(accountId)`
- `ListActions()`

## Commands

- `/warn`
- `/kick`
- `/tempban`
- `/ban`
- `/unban`
- `/goto`
- `/bring`
- `/return`
- `/freeze`
- `/unfreeze`
- `/heal`
- `/revive`
- `/spectate`
- `/specoff`
- `/noclip`
- `/adminduty`

Commands call the domain exports and do not contain core business logic.

## Migration

Migration `040_admin_foundation` creates:

- `nexa_admin_warnings`
- `nexa_admin_bans`
- `nexa_admin_notes`
- `nexa_admin_actions`
