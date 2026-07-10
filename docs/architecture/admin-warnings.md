# Admin Warnings

Warnings are stored in `nexa_admin_warnings`.

## API

- `WarnPlayer`
- internal `Warnings.Create`
- internal `Warnings.ListForAccount`
- internal `Warnings.ListForCharacter`
- internal `Warnings.Revoke`
- internal `Warnings.Get`

Warnings are never physically deleted. Revocation sets status and revoke metadata.
