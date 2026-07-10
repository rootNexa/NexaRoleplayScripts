# Payroll Security

Verbote:

- Client setzt Gehalt
- Client setzt Duty-Zeit
- Client setzt Organisation oder Konto
- Floats oder negative Betraege
- Auszahlung ohne Ledger
- Auszahlung ohne Idempotenz
- direkte Datenbanktreiber
- Framework-Bridges

Alle Mutationen brauchen Actor, Reason, Permission, Audit und serverseitige Aufloesung.
