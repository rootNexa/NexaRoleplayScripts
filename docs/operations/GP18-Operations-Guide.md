# GP18 Operations Guide

## Startup Validation

Run the static validators from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-gp18-foundation.ps1
powershell -ExecutionPolicy Bypass -File scripts/validate-gp18-ui.ps1
```

Run the FXServer harness from the server console in a test environment:

```text
nexa_test_beta_runtime all
```

## Operational Checks

- `nexa_beta` starts after core, API, permissions and domain foundations.
- `nexa_admin_ui` opens with `/nexa_admin`.
- `nexa_ui` window, loading and error overlays render without script errors.
- Creator registry contains expected domain surfaces.
- Health checks report required resources.

## Restart Behavior

Restart `nexa_beta` and `nexa_admin_ui` after backend services in test. No
state from the admin UI should be trusted as authoritative after restart.
