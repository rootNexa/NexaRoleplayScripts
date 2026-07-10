# nexa_billing

`nexa_billing` is the server-authoritative foundation for invoices, invoice items, payments, cancellations, disputes, credits and overdue states.

## Rules

- Invoice totals are calculated server-side from items.
- Amounts are positive integers.
- Payments use `nexa_economy` and store Economy transaction IDs.
- Paid invoices are not silently changed; corrections use credits.
- Overdue status never auto-debits an account.
- No UI is included in this chapter.
