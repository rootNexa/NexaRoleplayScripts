# Admin Action Model

## Principle

Every admin operation is a registered server-side action. Commands, callbacks, and exports are adapters and never contain domain logic.

## Action Definition

Each action has:

- Unique name.
- Required permission.
- Duty requirement.
- Target type.
- Reason requirement.
- Audit category.
- Rate-limit window.
- Allowed execution source.
- Handler.
- Validation.
- Optional rollback or return-state.

## Registered Actions

| Action | Permission | Duty | Target | Reason | Purpose |
| --- | --- | --- | --- | --- | --- |
| `admin.warn` | `nexa.admin.warn` | yes | online player/account | yes | Create warning. |
| `admin.kick` | `nexa.admin.kick` | yes | online player | yes | Drop online player. |
| `admin.ban.temp` | `nexa.admin.ban.temp` | yes | account/online player | yes | Temporary account ban. |
| `admin.ban.permanent` | `nexa.admin.ban.permanent` | yes | account/online player | yes | Permanent account ban. |
| `admin.unban` | `nexa.admin.unban` | no | ban ID | yes | Revoke active ban. |
| `admin.goto` | `nexa.admin.teleport` or `nexa.support.teleport` | yes | online player | no | Move actor to target. |
| `admin.bring` | `nexa.admin.teleport` or `nexa.support.teleport` | yes | online player | no | Move target to actor. |
| `admin.return` | `nexa.admin.teleport` or `nexa.support.teleport` | yes | online player/self | no | Return player to stored position. |
| `admin.teleport.coords` | `nexa.admin.teleport` | yes | coordinates | yes | Move actor to coordinates. |
| `admin.freeze` | `nexa.admin.freeze` or `nexa.support.freeze` | yes | online player | yes | Set freeze state. |
| `admin.heal` | `nexa.admin.heal` | yes | online player | yes | Admin recovery heal. |
| `admin.revive` | `nexa.admin.revive` or `nexa.support.revive` | yes | online player | yes | Admin recovery revive. |
| `admin.spectate.start` | `nexa.admin.spectate` | yes | online player | no | Start spectate state. |
| `admin.spectate.stop` | `nexa.admin.spectate` | yes | actor | no | Stop spectate state. |
| `admin.noclip.start` | `nexa.admin.noclip` | yes | actor | no | Start noclip state. |
| `admin.noclip.stop` | `nexa.admin.noclip` | yes | actor | no | Stop noclip state. |
| `admin.note.create` | `nexa.support.notes.create` | no | account/character | yes | Create admin note. |
| `admin.note.view` | `nexa.support.notes.view` | no | account/character | no | List visible notes. |

## Execution Rules

- Unknown action returns `ADMIN_ACTION_NOT_FOUND`.
- Missing permission returns Deny.
- Duty is checked on the server through `nexa_permissions`.
- Actor source is always the actual server source or explicit server/console actor.
- Client payload may include target hints, never trusted actor identity.
- Every execution gets a correlation ID.
- Every mutating action writes to `nexa_admin_actions`.
- Critical operations also write their domain table.

## Error Format

All admin domain responses use:

```lua
{
    success = true,
    ok = true,
    code = 'OK',
    message = '...',
    data = {},
    meta = {
        correlationId = '...'
    }
}
```
