# nexa-organizations-runtime-tests

Development-only runtime harness for `nexa_organizations` and `nexa_jobs`.

Run from the server console:

```text
nexa_test_organizations_runtime all
```

Suites: organizations, ranks, memberships, duty, economy, storages, garages, modules, creator, security, restart, all.

Mutation suites require an isolated FXServer database and test characters. Open tests are intentionally not reported as passed.
