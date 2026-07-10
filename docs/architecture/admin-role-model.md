# Admin Role Model

## Principle

Roles are permission collections only. Resources must check concrete permissions such as `nexa.admin.kick`, never role names such as `admin`.

## Roles

| Role | Category | Inherits | Purpose |
| --- | --- | --- | --- |
| `owner` | Project leadership | `co_owner` | Full operational authority, owner protection, critical security changes. |
| `co_owner` | Project leadership | `head_admin` | Almost full admin authority without changing Owner protection rules. |
| `head_admin` | Administration | `senior_admin` | Admin team management, permanent sanctions, full admin audit visibility. |
| `senior_admin` | Administration | `admin` | Senior enforcement and sensitive player inspection. |
| `admin` | Administration | `trial_admin` | Standard moderation actions and temporary sanctions. |
| `trial_admin` | Administration | none | Limited supervised moderation. |
| `head_support` | Support | `supporter` | Support team management and support audits. |
| `supporter` | Support | `support_trainee` | Ticket handling and limited player help. |
| `support_trainee` | Support | none | View and claim supervised tickets only. |
| `developer` | Technical | none | Technical diagnostics only, not automatically granted. |
| `qa_tester` | Technical | none | Test diagnostics only, not automatically granted. |

Support does not inherit Administration. Technical roles do not imply Owner.

## Permission Catalog

### Core

- `nexa.core.health.view`
- `nexa.core.logs.view`
- `nexa.core.modules.view`

### Accounts

- `nexa.accounts.view`
- `nexa.accounts.status.view`
- `nexa.accounts.status.change`
- `nexa.accounts.review.view`
- `nexa.accounts.review.resolve`

### Characters

- `nexa.characters.view`
- `nexa.characters.view_all`
- `nexa.characters.update`
- `nexa.characters.delete`
- `nexa.characters.restore`
- `nexa.characters.block`

### Admin

- `nexa.admin.panel`
- `nexa.admin.duty`
- `nexa.admin.teleport`
- `nexa.admin.noclip`
- `nexa.admin.spectate`
- `nexa.admin.freeze`
- `nexa.admin.revive`
- `nexa.admin.heal`
- `nexa.admin.kick`
- `nexa.admin.warn`
- `nexa.admin.ban.temp`
- `nexa.admin.ban.permanent`
- `nexa.admin.unban`
- `nexa.admin.inventory.view`
- `nexa.admin.inventory.modify`
- `nexa.admin.money.view`
- `nexa.admin.money.modify`
- `nexa.admin.vehicle.view`
- `nexa.admin.vehicle.modify`
- `nexa.admin.character.view`
- `nexa.admin.character.modify`
- `nexa.admin.logs.view`
- `nexa.admin.audit.view`

### Support

- `nexa.support.panel`
- `nexa.support.ticket.view`
- `nexa.support.ticket.claim`
- `nexa.support.ticket.close`
- `nexa.support.teleport`
- `nexa.support.freeze`
- `nexa.support.revive`
- `nexa.support.player.view`
- `nexa.support.notes.view`
- `nexa.support.notes.create`

### Permission Management

- `nexa.permissions.view`
- `nexa.permissions.assign_role`
- `nexa.permissions.remove_role`
- `nexa.permissions.grant`
- `nexa.permissions.deny`
- `nexa.permissions.revoke`
- `nexa.permissions.audit`
- `nexa.permissions.manage_owner`

## Default Role Grants

| Role | Grants |
| --- | --- |
| `support_trainee` | `nexa.support.panel`, `nexa.support.ticket.view`, `nexa.support.ticket.claim`, `nexa.support.player.view` |
| `supporter` | Adds ticket close, support teleport, freeze, revive, notes view/create |
| `head_support` | Adds support audit through `nexa.permissions.audit` and support role assignment where hierarchy allows |
| `trial_admin` | Admin panel, duty, teleport, freeze, revive, warn, limited character/player view |
| `admin` | Adds spectate, kick, temp ban, player inventory/money/vehicle view |
| `senior_admin` | Adds inventory, money, vehicle, character modify and unban |
| `head_admin` | Adds permanent ban, admin audit view, role assignment up to allowed hierarchy |
| `co_owner` | Adds broad core/account/character/permission management except owner-only actions |
| `owner` | Adds `nexa.permissions.manage_owner` and all critical management permissions |
| `developer` | Core health/log/module view |
| `qa_tester` | Core health view and selected test diagnostics |

## Owner Protection

- Only Owner may assign or remove `owner`.
- Co-Owner cannot modify Owner.
- Head Admin cannot assign or remove Owner or Co-Owner.
- No actor may grant themselves a higher role except controlled Owner bootstrap.
- The last active Owner cannot be removed.
- Owner mutations always write audit entries.

## Admin Duty

Duty states:

- `off_duty`
- `on_duty`
- `suspended`

Duty may be required for operational admin permissions such as teleport, freeze, revive, spectate, and player inspection. Owner and security recovery permissions must not depend fully on duty, so an owner can recover broken duty state.
