# Organizations Migration Plan

## Phase 1: Parallel Foundation

`nexa_organizations` und `nexa_jobs` werden neben `nexa_jobscreator` erstellt. Bestehende Daten werden nicht automatisch migriert.

## Phase 2: Datenmapping

`organizations` aus JobsCreator werden auf `nexa_organizations` gemappt. `organization_grades` werden zu `nexa_organization_ranks`, `organization_members` zu `nexa_organization_members`.

## Phase 3: Legacy-APIs einfrieren

Neue Systeme nutzen nur noch `nexa_organizations` und `nexa_jobs`. Legacy-Exports bleiben lesbar, bis alle Nutzer migriert sind.

## Phase 4: Runtime-Abnahme

Mit Testorganisationen werden Organisationstypen, Ranks, Memberships, Duty, Economy-Konten, Storage-, Garage- und Modulregistrierung geprueft.

## Phase 5: Removal

Legacy-Jobresources werden erst entfernt, wenn Dependency-Graph und Runtime-Logs zeigen, dass keine aktive Resource sie noch verwendet.

## Entfernungskriterien

- Keine `nexa_jobs_core`-Nutzer.
- Keine festen Faction-Resources im Startplan.
- Keine direkte Job-/Grade-Quelle ausser `nexa_organizations` und `nexa_jobs`.
- Alle statischen Validatoren und FXServer-Runtime-Tests sind gruen oder offen dokumentiert.
