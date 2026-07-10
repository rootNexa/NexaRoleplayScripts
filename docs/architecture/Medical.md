# GP16 Medical

`nexa_medical` besitzt den autoritativen Health State, lokalisierte Verletzungen, Bleeding, Bewusstlosigkeit, Death-State, Respawn-Audit, Treatment-Sessions und medizinische Reports. Der Client meldet nur Signale; Zustandswechsel erfolgen serverseitig ueber whitelisted APIs.

## Ownership

- Health State, Injuries, Death/Respawn und Treatment-Sessions gehoeren `nexa_medical`.
- EMS-Workflow und Krankenhausakten gehoeren `nexa_ems`.
- Inventory-Verlust und Items werden nur ueber die spaeteren Inventory/Item APIs integriert.

## States

Death State: `alive -> incapacitated -> critical -> dead -> respawned -> alive`.

Treatment Session: `active -> completed|cancelled|failed`.

## APIs

Exports: `GetMedicalState`, `NormalizeDamageEvent`, `ApplyInjury`, `InspectPatient`, `StartTreatmentSession`, `CompleteTreatmentSession`, `CancelTreatmentSession`, `SetUnconscious`, `SetDeathState`, `RecordDeath`, `RespawnAtHospital`, `CreateMedicalReport`, `ListMedicalReports`.

Callbacks: `nexa:medical:cb:getState`, `nexa:medical:cb:inspectPatient`, `nexa:medical:cb:applyInjury`, `nexa:medical:cb:startTreatment`, `nexa:medical:cb:completeTreatment`, `nexa:medical:cb:respawnAtHospital`.

## Security

Keine Character-ID vom Client wird als eigene Identitaet vertraut. GP17-UI muss alle Requests gegen Session, Character, Organisation, Duty und Permissions validieren lassen.
