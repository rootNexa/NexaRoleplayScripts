# Permission Testing

## Static Validators

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-permissions.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-admin-roles.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-permission-audit.ps1
```

Also run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-foundation.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-runtime-harness.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-identity-character.ps1
```

## Covered

- Forbidden framework dependencies.
- No direct oxmysql in `nexa_permissions`.
- Permission catalog exists.
- Admin role hierarchy exists.
- Owner protection code paths exist.
- Mutating exports require reasons.
- Audit table and audit calls exist.
- Admin-duty API exists.
- `git diff --check`.

## Runtime-Only

- Real database migration execution.
- ACE permission resolution for connected source.
- Race behavior for last-owner removal.
- Disconnect and restart duty cleanup.
