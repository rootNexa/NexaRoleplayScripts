# nexa_economy

`nexa_economy` ist die serverautoritative Foundation fuer Bankgeld, Konten, Ledger, Transaktionen, Reservierungen und Cash-Integration.

## Grenzen

- Bankgeld liegt nur in Economy-Accounts.
- Cash liegt als Item `currency_cash` im Inventory.
- Dirty Cash liegt als Item `currency_dirty_cash` im Inventory.
- Es gibt keine Legacy-Framework- oder UI-Library-Abhaengigkeit.
- Clients duerfen keine Account-, Character- oder Balancewerte autoritativ setzen.

## Kernmodelle

- Accounts: `character_bank`, `organization`, `government`, `system`, `escrow`, `temporary`
- Currencies: `bank`, `cash`, `dirty_cash`
- Transactions: Credit, Debit, Transfer, Reservation, Capture, Release, Deposit, Withdraw
- Ledger: unveraenderliche Buchungshistorie pro Konto
- Reservations: reservierte Bankmittel mit Capture/Release
- Sagas: Deposit/Withdraw ueber Economy und Inventory

## Exports

- `GetAccount`
- `GetCharacterBankAccount`
- `GetBalance`
- `GetAvailableBalance`
- `GetReservedBalance`
- `GetLedger`
- `GetTransaction`
- `GetCash`
- `GetDirtyCash`
- `CanAfford`
- `Credit`
- `Debit`
- `Transfer`
- `Reserve`
- `CaptureReservation`
- `ReleaseReservation`
- `DepositCash`
- `WithdrawCash`
- `AddCash`
- `RemoveCash`
- `AddDirtyCash`
- `RemoveDirtyCash`

## Runtime Tests

Die Runtime-Abnahme liegt in `[nexa-tests]/nexa-economy-runtime-tests` und wird per Servercommand gestartet:

```text
nexa_test_economy_runtime all
```

Einige Tests brauchen eine laufende FXServer-Instanz mit Datenbank, `nexa_items`, `nexa_inventory` und Test-Characters.
