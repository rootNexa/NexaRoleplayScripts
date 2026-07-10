# Economy Currencies

Nexa unterscheidet Buchgeld und physische Waehrungen.

## bank

`bank` ist die einzige echte Konto-Waehrung in `nexa_economy`. Sie wird in Economy-Accounts gefuehrt, ledgerfaehig gebucht und serverseitig auditiert.

## cash

`cash` ist physisches Bargeld und wird als Item `currency_cash` in `nexa_inventory` gefuehrt. Die Economy darf Cash nicht als Konto-Balance speichern. Deposit und Withdraw sind koordinierte Cross-Domain-Aktionen.

## dirty_cash

`dirty_cash` ist physisches Schwarzgeld und wird als Item `currency_dirty_cash` im Inventory gefuehrt. Es ist nicht automatisch bankfaehig. Reinigung, Beschlagnahme oder Speziallogik gehoeren spaeter in eigene Module.

## Registrierung

Currencies haben einen Namen, ein Label, einen Typ und Regeln:

- `account`: darf in Konten gebucht werden.
- `item`: existiert als Inventory-Item.
- `restricted`: darf nur ueber explizite APIs bewegt werden.

Neue Waehrungen muessen registriert werden, bevor Buchungen oder Item-Integrationen sie verwenden.
