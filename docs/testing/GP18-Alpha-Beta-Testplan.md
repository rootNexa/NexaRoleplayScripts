# GP18 Alpha and Beta Testplan

## Automated Static Tests

- GP18 foundation validator
- GP18 UI validator
- JavaScript syntax checks for NUI apps
- Git diff whitespace check

## Runtime Tests

Use `nexa-beta-runtime-tests` on a running FXServer:

- `nexa_test_beta_runtime ui`
- `nexa_test_beta_runtime creators`
- `nexa_test_beta_runtime admin`
- `nexa_test_beta_runtime health`
- `nexa_test_beta_runtime release`
- `nexa_test_beta_runtime all`

## Manual Alpha Checks

- Start server with GP01-GP18 resources.
- Open `/nexa_admin`.
- Trigger a `nexa_ui` loading overlay from a test command or client console.
- Confirm no SCRIPT ERROR appears.
- Restart `nexa_beta` and `nexa_admin_ui`.

## Beta Checks

- Permission review for each future admin mutation.
- Performance baseline recorded during 30 minutes of test play.
- Security review for NUI callbacks and network callbacks.
- Documentation reviewed against actual server.cfg start order.
