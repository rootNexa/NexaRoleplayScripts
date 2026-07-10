# nexa_ems

`nexa_ems` ist die serverseitige EMS-Workflow-Foundation fuer Untersuchungen, Patiententransport und Krankenhausakten.

Die Resource besitzt keine feste Job- oder Fraktionsannahme. Duty, Organisation, Module und Permissions werden ueber JobsCreator/Nexa Permissions integriert.

## Exports

- `InspectPatient(patientCharacterId, payload)`
- `StartPatientTransport(patientCharacterId, payload)`
- `CompletePatientTransport(transportId, payload)`
- `CreateHospitalRecord(patientCharacterId, payload)`
- `getSchema()`

## Migration

`165_ems_foundation` erstellt:

- `nexa_ems_inspections`
- `nexa_ems_transports`
- `nexa_ems_hospital_records`
