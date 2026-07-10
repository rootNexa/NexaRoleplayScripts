# Admin Current State

## Scope

This document captures the admin system before the Chapter 04 migration. It focuses on existing admin resources, commands, moderation utilities, callback usage, dependencies, security boundaries, and migration risks.

## Existing Admin Resources

| Location | Current Owner | Current Permission Check | Security Risk | Future Owner | Migration Strategy | Compatibility Need | Removal Criteria |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `[nexa-admin]/nexa_admin` | `nexa_admin` | Legacy `admin.*` permissions through `nexa_api` and old wrappers | High: still depends on `ox_lib`, uses `lib.callback`, stores warnings/kicks/notes in memory, permissions are not the Chapter 03 `nexa.*` model | `nexa_admin` | Refactor into server-authoritative domain resource using `nexa_permissions`, Core DB, and thin commands/exports | Keep broadly named admin exports where possible, add new canonical exports | No `ox_lib`, no `lib.*`, no direct SQL, actions registered with `nexa.*` permissions |
| `[nexa-core]/nexa_anticheat/server/bans.lua` | `nexa_anticheat` | Anticheat domain, not admin domain | Medium if reused for admin bans because semantics differ | `nexa_anticheat` for anticheat only | Keep separate; admin bans live in `nexa_admin` and may inform anticheat later | No direct dependency from admin to anticheat required in Chapter 04 | Kept as separate anticheat enforcement |
| `[nexa-admin]/nexa_devtools` | Devtools | Development-only operational tools | Medium if confused with production admin actions | `nexa_devtools` | Keep separate; do not merge into admin domain | None | Kept for dev-only workflows |

## Existing Features in `nexa_admin`

- Report and ticket runtime structures.
- Player overview.
- Moderation placeholders for warn, kick, tempban prepare, freeze, spectate prepare, notes.
- Utility placeholders for bring, goto, return, coordinates, heal prepare, revive prepare.
- Client menu and dialogs via `ox_lib`.
- Server callbacks via `lib.callback.register`.
- Audit through `nexa_audit` and logs through `nexa_logs`.

## Problems

- `fxmanifest.lua` depends on `ox_lib` and loads `@ox_lib/init.lua`.
- Client uses `lib.notify`, `lib.callback.await`, `lib.registerContext`, `lib.showContext`, and `lib.inputDialog`.
- Server callbacks use `lib.callback.register`.
- Old permission names such as `admin.menu`, `admin.utility.goto`, and `admin.moderation.warn` do not match `nexa.<area>.<action>`.
- Existing moderation records are in memory and disappear on restart.
- Tempban and spectate are only prepared, not persisted/enforced.
- Kick uses runtime structures rather than the new action model.
- Commands are mostly menu/report oriented; Chapter 04 requires command adapters for moderation and recovery.
- No central action registry with duty, reason, rate-limit, target type, and audit metadata.
- Ban connection enforcement is not integrated with `nexa_identity`.

## Existing Permission Callers

Existing resource checks use server-side `nexa_api` or old admin-internal wrappers. No client should be trusted to decide permission, duty, actor, or target.

## Future Ownership

`nexa_admin` becomes the domain owner for:

- Admin action registry.
- Warning records.
- Admin bans and unbans.
- Kick.
- Teleport/bring/goto/return.
- Freeze state.
- Admin heal/revive recovery.
- Spectate and noclip state foundations.
- Admin notes.
- Admin action audit.
- Command adapters and server exports.

`nexa_permissions` remains the owner for permissions, roles, owner protection, and admin-duty state.

## Runtime Gaps

Runtime tests that require FXServer are documented in `docs/architecture/admin-testing.md`. Static validation can verify structure and forbidden dependencies, but real player movement, disconnect cleanup, and connection rejection require a running server.
