# nexa_moneywash

`nexa_moneywash` implementiert Geldwaesche fuer Dirty Money, Clean Money, Audit, Ledger und Illegal-API-Anbindung.

## Architekturgrenze

- Keine direkte Datenbanklogik in der Fachresource.
- Keine direkten Inventory- oder Geldzugriffe in der Fachresource.
- Waschvorgaenge laufen ueber `nexa_illegal_core`.
- Dirty Money wird serverseitig ueber `nexa_api.inventory` entfernt.
- Clean Money wird serverseitig ueber `nexa_api.account.addSystemMoney` gutgeschrieben und erzeugt dadurch `economy_ledger`.
- Persistente Waschvorgaenge und Audit laufen ueber `nexa_api.criminal`.
- Nicht enthalten sind Heists.

## Callbacks und Events

- `nexa:moneywash:cb:wash`
- `nexa:moneywash:server:requestWash`

Der Client sendet nur Station-ID, Menge und optionale Kontoreferenz. Items, Umrechnung, Gebuehren und Ledger-Anbindung werden serverseitig validiert.
