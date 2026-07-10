# nexa_jobframework

`nexa_jobframework` ist die serverautoritative Grundlage fuer legale Gameplay-Jobs und Produktionsketten.

Es trennt temporaere Job-Sessions klar von Organisationsmitgliedschaft und Duty aus `nexa_jobs`. Eine Person kann einer Organisation angehoeren, waehrend ein Mining-, Taxi- oder Delivery-Auftrag nur eine laufende Session mit Phasen, Tasks, Progress, Cooldowns und Rewards ist.

## Enthalten

- registrierbare Jobtypen
- registrierbare Tasktypen
- Jobdefinitionen mit Phasen und Tasks
- serverseitige Job-Sessions
- Gruppen-Foundation
- servervalidierter Progress
- Checkpoint-Foundation
- Resource Nodes fuer Mining, Farming und Fishing
- Production Chains als Bruecke zu `nexa_crafting`
- Reward-Foundation mit Idempotency
- Audit und interne Events

## Nicht enthalten

- keine Job-NUI
- keine Cliententscheidung ueber Progress, Completion oder Rewards
- keine illegalen Jobs
- keine Fraktionsjobs wie Police oder EMS
- keine direkte Economy-, Inventory- oder Vehicle-Mutation aus Clientdaten

## Exports

- `GetJobDefinition`
- `ListJobDefinitions`
- `CanStartJob`
- `StartJob`
- `CancelJob`
- `GetJobSession`
- `GetCharacterJobSession`
- `ListActiveJobSessions`
- `GetTaskProgress`
- `CompleteJobTask`
- `GetJobRewards`
- `RetryJobReward`
- `CreateJobDefinition`
- `UpdateJobDefinition`
- `ActivateJobDefinition`
- `SuspendJobDefinition`
- `DisableJobDefinition`
- `RegisterJobType`
- `RegisterTaskType`
- `RegisterResourceNode`
- `RegisterProductionChain`

## Security

Der Client darf nur technische Beobachtungen melden. Character, Session, Phase, Task, Route, Resource Node und Reward werden serverseitig aus Definitionen und aktuellem Runtime-State geprueft.

## Sessions, Groups und Progress

Sessions werden pro Character gebunden und verhindern doppelte aktive Auftraege. Gruppen sind als Foundation mit Leader, Invite und Membership-Kontext vorbereitet. Progress laeuft ueber `Progress.Get`, `Progress.Apply`, `Progress.SetValidated` und `Progress.Complete`; alle Pfade schreiben serverseitige Audit- und Event-Kontexte statt Clientwerte ungeprueft zu uebernehmen.

## Resource Nodes, Production und Rewards

Resource Nodes nutzen Reservations fuer Harvesting, damit Mining, Farming und Fishing keine unbegrenzten Client-Ernten erzeugen. Production Chains verweisen kontrolliert auf `nexa_crafting`. Rewards werden als eigene Records mit Idempotency-Key vorbereitet und koennen spaeter ueber Economy- und Inventory-Sagas finalisiert oder wiederholt werden.

## Creator, Admin und Anti-AFK

Creator- und Adminfunktionen muessen die mutierenden Exports mit Actor, Reason, Source-Resource, Correlation-ID und Permission-Kontext verwenden. Anti-AFK ist als serverseitige Foundation vorbereitet und akzeptiert nur plausible Aktionen aus Session- und Task-Kontext.
