# nexa-economy-runtime-tests

Development-only runtime harness for `nexa_economy`.

Run from the server console:

```text
nexa_test_economy_runtime all
```

Suites:

- accounts
- credit
- debit
- transfer
- reservations
- cash
- dirtycash
- deposit
- withdraw
- ledger
- admin
- security
- restart
- all

Most mutation suites need an isolated FXServer database and test characters. Static validators cover repository structure and forbidden dependency checks.
