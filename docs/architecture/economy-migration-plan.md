# Economy Migration Plan

## Phase 1: Foundation

Neue Resource `nexa_economy` anlegen, Migrationen bereitstellen, Currencies, Accounts, Ledger, Transactions, Reservations, Idempotency, Cash-Integration und Sagas implementieren.

## Phase 2: Runtime-Abnahme

FXServer-Testresource ausfuehren und Kernfaelle pruefen:

- Character-Bankkonto anlegen.
- Credit, Debit und Transfer.
- Reservation Capture und Release.
- Cash und Dirty Cash als Inventory-Items.
- Deposit und Withdraw mit Saga-Kompensation.
- Ledger- und Audit-Nachvollziehbarkeit.

## Phase 3: Legacy-Banking isolieren

`nexa_banking` wird analysiert und seine API-Aufrufe werden schrittweise auf `nexa_economy` gemappt. Dabei werden ox_lib-Callbacks entfernt und UI-Interaktionen auf NexaUI/Nexa Callback-System umgestellt.

## Phase 4: Domain-Integrationen

Shops, JobsCreator, Inventory, Adminsystem, Taxes, Payroll und Rechnungen verwenden nur noch Economy-Exports. Direkte Geldfelder oder alte Kontoabstraktionen werden deprecated.

## Phase 5: Cleanup

Nicht mehr genutzte Legacy-Funktionen werden entfernt, sobald Runtime-Tests und Betriebslogs zeigen, dass keine Resource sie mehr verwendet.

## Reihenfolge

1. `nexa_economy`
2. Runtime-Tests
3. Banking-Migration
4. Shop/Inventory/JobsCreator-Integration
5. Admin-UI
6. Legacy-Entfernung
