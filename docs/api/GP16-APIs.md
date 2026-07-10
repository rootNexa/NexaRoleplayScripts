# GP16 APIs

Alle GP16 APIs geben Nexa-Response-Tabellen mit `success`, `ok`, `code`, `message`, `data`, `meta` und optionalem `error` zurueck.

## Medical

`nexa_medical`: `GetMedicalState`, `NormalizeDamageEvent`, `ApplyInjury`, `InspectPatient`, `StartTreatmentSession`, `CompleteTreatmentSession`, `CancelTreatmentSession`, `RespawnAtHospital`.

## EMS

`nexa_ems`: `InspectPatient`, `StartPatientTransport`, `CompletePatientTransport`, `CreateHospitalRecord`.

## Police

`nexa_police`: restraints, search, seizure, fines, booking, incarceration, transport and checks.

## Dispatch

`nexa_dispatch`: call type registry, calls, unit status, assignments and panic.

## MDT

`nexa_mdt`: cases, reports, warrants, BOLOs and notes.

## Evidence

`nexa_evidence`: types, traces, collection, packaging, custody, analysis and locker.

## Licenses

`nexa_licenses`: type registry, issue, suspend, reinstate, revoke, expire, validate and history.
