# GP16 Schema

## Migrationen

- `160_medical_foundation`: Medical states, injuries, treatments, treatment sessions, deaths, respawns and reports.
- `165_ems_foundation`: EMS inspections, transports and hospital records.
- `161_police_foundation`: Agencies, arrests, restraints, searches, seizures, fines, bookings, incarcerations and transports.
- `162_dispatch_foundation`: Call types, calls, units, assignments and history.
- `166_mdt_domain`: Cases, reports, warrants, BOLOs, notes and links.
- `164_evidence_foundation`: Evidence types, records, traces, custody, analysis and locker.
- `163_licenses_foundation`: License types, licenses and history.

Alle Migrationen sind idempotent ueber `CREATE TABLE IF NOT EXISTS` und ergaenzende `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` modelliert.
