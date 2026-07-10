# Admin Testing

## Static Validators

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-admin-foundation.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-admin-actions.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-admin-security.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-admin-runtime-harness.ps1
```

## Runtime Tests

Runtime tests live in `[nexa-tests]/nexa-admin-runtime-tests` and are development-only. Some checks are reported as open unless executed inside FXServer with safe test accounts.
