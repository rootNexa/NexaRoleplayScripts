# Economy Testing

Die Economy benoetigt statische Validatoren und FXServer-Runtime-Tests.

## Statische Tests

- Foundation-Dateien, Manifest und Abhaengigkeiten.
- Keine verbotenen Frameworks.
- Keine direkten oxmysql-Aufrufe.
- Transaction-Engine und Ledger-Pfade.
- Idempotency, Reservations und Sagas.
- Cash/DirtyCash-Domaintrennung.

## Runtime-Suites

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

Einige Tests koennen nur in einer laufenden FXServer-Instanz mit Datenbank, `nexa_items`, `nexa_inventory` und aktiven Test-Characters vollstaendig ausgefuehrt werden.
