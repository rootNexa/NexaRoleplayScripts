# nexa_chopshop

`nexa_chopshop` implementiert Fahrzeug zerlegen, Teile, Verkauf, Illegal API und Audit.

## Architekturgrenze

- Keine direkte Datenbanklogik in der Fachresource.
- Keine direkten Vehicle-, Inventory- oder Geldzugriffe in der Fachresource.
- Zerlegen und Verkauf laufen ueber `nexa_illegal_core`.
- Fahrzeugstatus, Fahrzeughistorie, Chopshop-Orders, Itembewegungen, Auszahlung und Audit laufen ueber `nexa_api.criminal`, `nexa_api.inventory` und `nexa_api.account`.
- Nicht enthalten sind Heists.

## Callbacks und Events

- `nexa:chopshop:cb:dismantle`
- `nexa:chopshop:cb:sell`
- `nexa:chopshop:server:requestDismantle`
- `nexa:chopshop:server:requestSell`

Der Client sendet nur Yard-ID, Vehicle-ID oder Teileverkaufsdaten. Teile, Preise, Fahrzeugstatus und Audit werden serverseitig entschieden.
