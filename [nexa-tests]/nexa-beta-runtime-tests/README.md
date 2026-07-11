# nexa-beta-runtime-tests

Runtime harness for GP18 alpha and beta readiness.

Run from the server console:

```text
nexa_test_beta_runtime all
```

Available suites:

- `ui`
- `creators`
- `admin`
- `health`
- `release`
- `all`

The harness checks that GP18 integration surfaces are present and callable. It
does not replace live playtesting, permission review or a full FXServer startup
matrix.
