# Economy Troubleshooting

## Balance stimmt nicht

Pruefe Account, Ledger-Summe, offene Reservierungen und letzte Transactions. Eine manuelle Korrektur erfolgt nur ueber Admin-Adjust mit Grund.

## Doppelte Buchung vermutet

Pruefe Idempotency-Key, Correlation-ID und Transaction-Status. Replay mit gleichem Key muss das bestehende Ergebnis liefern.

## Deposit/Withdraw teilweise fehlgeschlagen

Pruefe Saga und Saga-Schritte. Falls Kompensation fehlgeschlagen ist, muss ein Admin anhand des Audit-Kontexts entscheiden.

## Cash fehlt

Cash liegt im Inventory, nicht in Economy. Pruefe Inventory-Items `currency_cash` und `currency_dirty_cash`.

## Resource nicht ready

Pruefe Startreihenfolge, Core-DB-Health, Migrationen, `nexa_items` und `nexa_inventory`.
