# nexa_drugs

`nexa_drugs` implementiert die aktuelle illegale Drogenphase: Pflanzen, Ernten, Verarbeitung, Verkauf, Reputation, Cooldowns und Illegal-API-Anbindung.

## Architekturgrenze

- Keine direkte Datenbanklogik in der Fachresource.
- Keine direkten Inventory- oder Geldzugriffe in der Fachresource.
- Alle kritischen Aktionen laufen ueber `nexa_illegal_core`.
- Persistente Batches, Sales, Itembewegungen, Auszahlungen, Reputation und Audit laufen ueber `nexa_api.criminal`, `nexa_api.inventory` und `nexa_api.account`.
- Nicht enthalten sind Moneywash und Heists.

## Callbacks und Events

- `nexa:drugs:cb:plant`
- `nexa:drugs:cb:harvest`
- `nexa:drugs:cb:process`
- `nexa:drugs:cb:sell`
- `nexa:drugs:server:requestPlant`
- `nexa:drugs:server:requestHarvest`
- `nexa:drugs:server:requestProcess`
- `nexa:drugs:server:requestSell`

Der Client sendet nur IDs, Mengen und optionale Kontoreferenzen. Items, Preise, Ertraege, Reputation und Statuswechsel werden serverseitig validiert.
