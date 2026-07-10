# Permission Operations

## Start Order

`nexa_permissions` depends on:

- `nexa-core`
- `nexa_identity`

The Core may start without `nexa_permissions`, but domain role administration is unavailable until `nexa_permissions` starts.

## Setup

1. Start `nexa-core`.
2. Start `nexa_identity`.
3. Start `nexa_permissions`.
4. Verify that migration `030_permission_domain` applied.
5. Assign the first Owner through controlled console or ACE bootstrap.
6. Disable bootstrap when complete.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| All checks deny | Confirm permission is registered and role is assigned to account subject. |
| Owner assignment denied | Actor must be Owner, console, or controlled bootstrap. |
| Permission mutation denied | Actor lacks required `nexa.permissions.*` permission or hierarchy. |
| Audit missing | Check `nexa_permission_audit` migration and DB health. |
| Duty not active | Confirm source is online and `SetAdminDuty` returned OK. |

## Runtime Tests

Some tests require FXServer:

- Live ACE bootstrap.
- Source-to-account resolution through `nexa_identity`.
- Disconnect clearing duty.
- Cross-resource export calls in real start order.
