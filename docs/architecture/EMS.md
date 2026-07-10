# GP16 EMS

`nexa_ems` ist die Workflow-Schicht fuer EMS-Inspection, Patiententransport und Krankenhausakten. Es besitzt keine feste Ambulance-Resource und keine harten Jobnamen.

## APIs

Exports und Callbacks:

- `InspectPatient`
- `StartPatientTransport`
- `CompletePatientTransport`
- `CreateHospitalRecord`

## Integrationen

EMS liest Medical State ueber `nexa_medical`, prueft spaeter JobsCreator-Module wie `medical`, `dispatch`, `mdt`, `garage` und schreibt Krankenhausakten in eigene Tabellen.
