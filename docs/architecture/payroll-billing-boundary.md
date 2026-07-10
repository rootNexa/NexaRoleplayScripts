# Payroll Billing Boundary

`nexa_payroll` zahlt Gehaelter aus Organisationskonten an Character-Bankkonten. `nexa_billing` erzeugt Forderungen und bucht Zahlungen zwischen Empfaenger- und Ausstellerkonten.

Gemeinsamkeiten:

- Integer-Betraege
- Economy-Ledger
- Idempotenz
- Audit
- Serverautoritaet

Abgrenzung:

- Payroll nutzt Duty-Zeit und Policies.
- Billing nutzt Rechnungspositionen und Zahlungsstatus.
- Economy bleibt alleiniger Konten- und Ledger-Owner.
