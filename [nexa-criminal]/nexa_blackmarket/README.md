# nexa_blackmarket

`nexa_blackmarket` implementiert Phase 9B: Haendler, Kategorien, serverseitige Preise, Kauf, Verkauf, Cooldowns, Audit und Rate-Limits.

## Architekturgrenze

- Keine direkte Datenbanklogik in der Fachresource.
- Kauf und Verkauf laufen ueber `nexa_illegal_core`.
- Persistente Orders, Preisvalidierung, Geld- und Itembewegungen laufen ueber `nexa_api.criminal`, `nexa_api.account` und `nexa_api.inventory`.
- Nicht enthalten sind Drugs, Heists und Moneywash.

## Callbacks und Events

- `nexa:blackmarket:cb:getCatalog`
- `nexa:blackmarket:cb:buy`
- `nexa:blackmarket:cb:sell`
- `nexa:blackmarket:server:requestBuy`
- `nexa:blackmarket:server:requestSell`

Der Client sendet nur Haendler-ID, Katalog-ID, Menge und optional eine Kontoreferenz. Preise und Items werden serverseitig aus der Config gelesen.
