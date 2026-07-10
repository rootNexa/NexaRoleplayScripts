# nexa_payroll

`nexa_payroll` is the server-authoritative foundation for salary policies, duty-time evaluation, payroll periods, payroll runs, payroll entries and payout audit.

## Rules

- Default interval is two hours and configurable.
- Salaries are funded by organization accounts.
- There is no automatic money creation and no automatic tax.
- Duty time is calculated from server-side duty sessions.
- Payouts use `nexa_economy` and must reference Economy transactions.
- Live FXServer tests are provided by `nexa-payroll-runtime-tests`.
