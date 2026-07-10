# nexa_legaljobs

`nexa_legaljobs` liefert konkrete legale Jobdefinitionen fuer `nexa_jobframework`.

Die Resource besitzt keine eigene Engine und fuehrt keine Rewards direkt aus. Sie beschreibt Mining, Farming, Fishing, Delivery, Trucking, Taxi, Garbage, Mechanic Service, Courier und Warehouse Logistics als wiederverwendbare Definitionen aus Phasen und Tasks.

## Enthaltene Foundations

- Mining
- Farming
- Fishing
- Delivery
- Trucking
- Taxi
- Garbage
- Mechanic Service
- Courier
- Warehouse Logistics

## Regeln

- keine Fremdbibliotheks-Abhaengigkeit
- keine Legacy-Framework-Bridges
- kein direkter Clientprogress
- kein direkter Clientreward
- keine eigene Organisationslogik

## Exports

- `RegisterLegalJobDefinitions`
- `GetLegalJobDefinitions`
- `GetLegalJobDefinition`
- `getStatus`

## Delivery, Trucking und Logistics

Delivery und Courier bilden kurze Pickup/Dropoff-Auftraege ab. Trucking nutzt Cargo- und Vehicle-Kontext fuer laengere Routen. Warehouse Logistics verbindet Picking, Packing und Loading als Produktions-Foundation, ohne schon ein eigenes Warehouse-UI zu bauen.

## Taxi, Garbage und Mechanic

Taxi nutzt Passagier- und Routenaufgaben ohne komplexe NPC-KI. Garbage kombiniert Routen, Interaktionen und Entsorgung. Mechanic Service beschraenkt sich auf Inspection und einfache Repair-Aufgaben; Tuning und Werkstattverwaltung bleiben spaeteren Ressourcen vorbehalten.
