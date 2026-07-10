# Economy Cash

Cash ist physisches Bargeld und gehoert dem Inventory.

## Item

Das Standarditem heisst `currency_cash`. Es wird ueber `nexa_items` definiert und in `nexa_inventory` als normale Iteminstanz gehalten.

## Economy-Funktionen

`GetCash`, `AddCash` und `RemoveCash` sind Integrationshelfer. Sie nutzen Inventory-APIs und schreiben Economy-Audit, erzeugen aber keine Bank-Ledger-Buchung, solange kein Deposit oder Withdraw stattfindet.

## Deposit und Withdraw

Deposit entfernt Cash aus dem Inventory und schreibt danach Bank-Credit. Withdraw schreibt Bank-Debit und legt danach Cash im Inventory ab. Beide sind Saga-Workflows mit Kompensationsschritten.
