# Admin Security

## Rules

- Never trust actor source from payload.
- Never trust client permission, role, or duty.
- Target source is only a hint and must be resolved server-side.
- Every mutating action requires a reason.
- Every action writes an audit row.
- Owner and Co-Owner targets are protected through permission hierarchy checks.
- Client events only execute server-approved effects.

## Forbidden

- Direct SQL through oxmysql.
- ESX/QBCore/Qbox bridges.
- Role-name checks as authority.
- Hidden superadmin backdoors.
- IP or hardware based permissions.
- Discord role as sole authority.
