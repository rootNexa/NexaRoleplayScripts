# Database

Dieser Ordner enthaelt ab Phase 3 das versionierte Datenbankmodell fuer Nexa Roleplay.

## Struktur

- `migrations/`: versionierte SQL-Migrationen nach `YYYYMMDD_HHMM_short_description`.
- `schema.sql`: Einstiegspunkt fuer das kanonische Schema.
- `seeds.sql`: nicht-gameplaybezogene Basisdaten.
- `dev_seed.sql`: lokale Development-Defaults ohne Gameplay-Testdaten.

## Phase-3-Grenze

Die Migration `20260705_1200_create_phase_3_schema.sql` legt nur Tabellen an, die in `docs/02_Datenbankmodell.md` in Abschnitt 4 vollstaendig spezifiziert sind.

## Phase 3.1 - Database Completion

Die Migration `20260705_1300_complete_core_database_tables.sql` entscheidet ADR-003 fuer Core und Phase 4. Sie ergaenzt Permissions, technische Logs, Account-/Business-Erweiterungen, Lizenzhistorie, Storage-/Stash-Metadaten, Faction-Zugriffe, Radio-Metadaten, Telefon-Metadaten und Dokument-Signaturen.

`feature_flags` und `resource_settings` bleiben unveraendert, weil sie bereits in Phase 3 vollstaendig umgesetzt wurden.

Tabellen ausserhalb des ADR-003-Phase-3.1-Umfangs bleiben offen und werden nicht geraten.

## Phase 4B - Dokumente & Lizenzen

Phase 4B verwendet nur vorhandene Tabellen:

- `documents`
- `document_types`
- `document_signatures`
- `licenses`
- `license_types`
- `license_history`

`seeds.sql` ergaenzt nur Feature-Flag-, Permission- und Typkatalog-Defaults ohne Spieler- oder Gameplay-Testdaten.

## Phase 4D - Jobs Core & Businesses

Phase 4D verwendet ausschliesslich vorhandene Tabellen:

- `jobs`
- `job_grades`
- `character_jobs`
- `duty_sessions`
- `businesses`
- `business_members`
- `business_accounts`
- `business_transactions`
- `accounts`
- `account_members`
- `economy_ledger`
- `bank_transactions`

`salary_payments` und `business_roles` bleiben offen, weil ADR-003 diese Tabellen ausdruecklich nicht umgesetzt hat. Gehaltszahlungen laufen daher ueber `nexa_api.account` und `economy_ledger`; Business-Rollen werden serverseitig aus `business_members.role_name` interpretiert.

## Phase 7A Housing Core

Phase 7A nutzt ausschliesslich vorhandene Tabellen:

- `properties`
- `property_units`
- `property_access`
- `property_transactions`
- `accounts`
- `account_members`
- `bank_transactions`
- `economy_ledger`

Es wurde keine neue Migration erstellt. `property_owners`, `property_furniture` und Storage-/Doorlock-Erweiterungen bleiben ausserhalb von Phase 7A.

## Phase 7B - Property Access / Keys

Phase 7B nutzt weiterhin ausschliesslich vorhandene Tabellen:

- `property_units`
- `property_access`
- `audit_events`
- `rate_limit_events`

Temporaerer Zugriff ist mit der bestehenden Spalte `property_access.expires_at` sauber abbildbar. Es wurde keine neue Migration erstellt. Zugriffsentzug entfernt nur Zeilen aus `property_access`; Besitz bleibt in `property_units.owner_character_id` autoritativ.

## Phase 7C - Housing Storage

Phase 7C nutzt ausschliesslich vorhandene Tabellen:

- `property_units`
- `property_access`
- `property_storage`
- `stash_registry`
- `audit_events`
- `rate_limit_events`

Es wurde keine neue Migration erstellt. `property_storage` ordnet Property Units registrierten Stashes aus `stash_registry` zu. Die eigentliche Item- und Inventarlogik bleibt bei `ox_inventory`; Nexa speichert nur Registry, Zuordnung und Audit-Kontext.

## Phase 7D - Furniture

Phase 7D ergaenzt die vorhandene Property-Struktur additiv:

- `property_units`
- `property_access`
- `property_furniture`

Die Migration `20260706_1200_create_property_furniture.sql` speichert ausschliesslich Moebelmodell, Position, Rotation, Aktivstatus und Audit-Kontext pro Property Unit. Zugriff, Besitz und Plausibilitaet werden serverseitig ueber `nexa_api.property` validiert. Es wird keine Item-Logik, keine Doorlock-Vollintegration und kein komplexes Interior-System eingefuehrt.

## Phase 4E - Dispatch

Phase 4E verwendet ausschliesslich die vorhandene Tabelle:

- `dispatch_calls`

Zuweisungen, Ziel-Fraktionen, Status-Historie und Actor-Snapshots werden in `dispatch_calls.metadata` abgelegt. Dadurch bleibt Dispatch eigenstaendig und benoetigt keine neue Schemaentscheidung. MDT darf spaeter nur lesend auf die API/Callbacks aufsetzen.

## Validierung

```powershell
.\tools\windows\Validate-DatabaseSchema.ps1
.\tools\windows\Validate-Repository.ps1
```

## Backup-/Restore-Test

Der Test nutzt lokale MariaDB-/MySQL-Clienttools und speichert Dumps unter `backups/dev`, das nicht versioniert wird.

```powershell
.\tools\windows\Test-DatabaseBackupRestore.ps1 -Database nexa_roleplay_dev -User root
```
