# Economy Operations

## Betrieb

`nexa_economy` muss nach Core, API, Items und Inventory starten. Migrationen sind idempotent. Beim Restart duerfen keine offenen In-Memory-Locks erhalten bleiben; persistierte Reservierungen und Sagas werden anhand ihres Status fortgefuehrt oder bereinigt.

## Monitoring

Wichtige Kennzahlen:

- Anzahl aktiver Konten.
- offene Reservierungen.
- fehlgeschlagene Sagas.
- Ledger-Schreibfehler.
- Idempotency-Konflikte.
- Admin-Mutationen.

## Backup

Economy-Tabellen sind finanzielle Kerndaten. Backups muessen Accounts, Transactions, Ledger, Reservations, Sagas und Audit konsistent erfassen.
