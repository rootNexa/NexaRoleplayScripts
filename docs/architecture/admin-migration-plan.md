# Admin Migration Plan

## Goal

Migrate `nexa_admin` into a server-authoritative admin foundation that depends on `nexa-core`, `nexa_identity`, `nexa_characters`, and `nexa_permissions` only.

## Order

1. Document current state and the target action model.
2. Remove `ox_lib` and old `lib.callback` usage.
3. Add append-only database migration through the Core DB layer.
4. Add the action registry and common execution pipeline.
5. Implement warnings, bans, unbans, notes, and action audit.
6. Implement kick, teleport, freeze, heal, revive, spectate, and noclip foundations.
7. Add server command adapters and server exports.
8. Add runtime test resource and static validators.
9. Update architecture docs and README.

## Migration Table

| Finding | Current Purpose | Problem | Recommended Measure | Risk | Order |
| --- | --- | --- | --- | --- | --- |
| `ox_lib` dependency | UI menu, input, callbacks | Forbidden in Nexa foundation | Remove dependency and use `nexa_ui`/`nexa_api` only where needed | High | 2 |
| `lib.callback.register` | Server callbacks | Forbidden ox_lib API | Replace with `nexa_api:RegisterServerCallback` wrappers or direct server exports/commands | High | 2 |
| In-memory warnings and notes | Runtime moderation records | Lost on restart, not auditable enough | Persist to `nexa_admin_warnings` and `nexa_admin_notes` | High | 5 |
| Tempban prepare only | UI placeholder | No enforcement | Persist to `nexa_admin_bans`, integrate identity connection checks | High | 5 |
| Old `admin.*` permissions | Legacy admin model | Does not match Chapter 03 catalog | Use `nexa.admin.*` and `nexa.support.*` permissions | High | 4 |
| Client admin menu | Convenience UI | Not part of Chapter 04's UI goal and uses ox_lib | Keep minimal client executor only; no critical client decisions | Medium | 2 |
| Teleport return state | In-memory and no TTL | Can become stale | Store server-side TTL state and cleanup on disconnect/resource stop | Medium | 6 |
| Freeze state | In-memory client effect | Needs server-authoritative state | Add server state and client apply event only | Medium | 6 |
| Spectate/noclip prepare | Placeholder | Needs controlled state and cleanup | Add server state, client can only execute directed effect | Medium | 6 |

## Compatibility

New canonical exports are required, but old dotted exports may stay as aliases where practical:

- `admin.moderation.warn` -> `WarnPlayer`
- `admin.moderation.kick` -> `KickPlayer`
- `admin.utility.goto` -> `GoToPlayer`
- `admin.utility.bring` -> `BringPlayer`
- `admin.utility.return` -> `ReturnPlayer`

## Ban Integration

`nexa_admin` exposes `ResolveConnection(identityContext)` and `IsAccountBanned(accountId)`. `nexa_identity` can call these later during account resolution. If `nexa_admin` is not started, identity must not fail closed in Chapter 04; the required production start order should be documented and runtime-tested before enforcement is mandatory.

## Removal Criteria

Legacy UI/menu code can be removed when:

- No `lib.*` or `ox_lib` remains.
- Actions are in the registered catalog.
- All mutating actions require reasons.
- All canonical exports and commands are available.
- Validators pass.
