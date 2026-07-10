# Jobframework Architecture

`nexa_jobframework` ist die gemeinsame Domain fuer zivile und legale Gameplay-Auftraege. Es verhindert, dass Mining, Taxi, Garbage oder Logistics jeweils eine eigene Sonderengine entwickeln.

Die Resource verwaltet Definitionen, Phasen, Tasks, Sessions, Gruppen, Progress, Checkpoints, Resource Nodes, Production Chains, Rewards, Cooldowns, Anti-AFK und Audit. `nexa_legaljobs` liefert konkrete Definitionen. `nexa_jobs` bleibt fuer primaere Organisationsmitgliedschaft und Duty verantwortlich.

## Dependency Direction

- `nexa_legaljobs -> nexa_jobframework`
- `nexa_jobframework -> nexa_items`
- `nexa_jobframework -> nexa_inventory`
- `nexa_jobframework -> nexa_economy`
- `nexa_jobframework -> nexa_vehicles`
- `nexa_jobframework -> nexa_garages`
- `nexa_jobframework -> nexa_crafting`

Rueckabhaengigkeiten von Inventory, Economy oder Jobs auf das Framework sind verboten.

## Security Model

Clients melden nur Beobachtungen. Server validiert Character, Session, Task, Phase, Distance, Bucket, Tools, Vehicle, Cargo, Cooldown und Idempotency. Rewards werden ausschliesslich aus Definitionen erzeugt und ueber Economy/Inventory-Sagas vorbereitet.
