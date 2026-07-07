# nexa_jobs_core

Zivile Jobbasis fuer Phase 4D.

## Umfang

- Jobdefinitionen und Jobraenge ueber vorhandene Tabellen `jobs` und `job_grades`
- Charakter-Jobzuordnung ueber `character_jobs`
- Duty-System ueber `duty_sessions`
- Gehaltszahlung ueber `nexa_api.account.addSystemMoney`
- minimale ox_lib-Interaktion per `/nexajob`

## Grenzen

- Keine Polizei-, EMS-, Dispatch- oder Fraktionslogik
- Keine direkte Geldbuchung ausserhalb von `nexa_api.account`
- Keine Nutzung von `salary_payments`, weil die Tabelle laut ADR-003 offen ist
