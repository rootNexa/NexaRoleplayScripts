# Core Chapter 01 Validation Report

Stand: 2026-07-10

## Zusammenfassung

Kapitel 01 `nexa-core` wurde statisch und dokumentationsseitig validiert. Die lokalen Validierungen decken Bootstrap, Lifecycle, Logger, Config, Datenbank, Migrationen, EventBus, Callbacks, Module, Permissions, Sessions, Cache und Suchregeln gegen verbotene Frameworkreste ab.

Es sind keine kritischen oder hohen Fehler im neuen Core offen. Vollstaendige Runtime-Aussagen zu FXServer-Start, Stop, Restart, oxmysql-Ausfall und echter MariaDB-Ausfuehrung brauchen eine laufende FiveM-Instanz und sind in `docs/architecture/core-testing.md` als manuelle Tests dokumentiert.

## Status-Tabelle

| Bereich | Status | durchgefuehrter Test | Ergebnis | verbleibendes Risiko |
|---|---|---|---|---|
| Bootstrap | Bestanden | `validate-core-lifecycle.ps1` | State-Machine, Dependencies, Hooks erkannt | Runtime-Start braucht FXServer |
| Lifecycle | Bestanden | `validate-core-lifecycle.ps1` | Gueltige/ungueltige Wechsel, Stop-Pfade dokumentiert | Server-Shutdown-Signale sind FiveM-abhaengig |
| Logger | Bestanden | `validate-core-logger.ps1` | Level, Context, Maskierung, Adapter | Externe Adapter spaeter separat testen |
| Konfiguration | Bestanden | `validate-core-config.ps1` | Defaults, Schema, Secrets, Public Snapshot | Environment-Werte im Livebetrieb pruefen |
| Datenbank-Layer | Bestanden | `validate-core-database.ps1` | Query APIs, Transaktionen, Fehler, Migrationen | Echte MariaDB-Fehler nur live voll pruefbar |
| Migrationen | Bestanden | `validate-core-database.ps1` | Migrationstabelle, Checksumme, doppelte Ausfuehrung | Bereits produktive DB vor Deployment sichern |
| EventBus | Bestanden | `validate-core-eventbus.ps1` | Listener, Once, Prioritaet, Fehlerisolation | Fachliche Listener spaeter separat testen |
| Callback-System | Bestanden | `validate-core-callbacks.ps1` | Request-ID, Timeout, Source-Bindung, Rate-Limit | Echte Client Roundtrips brauchen FXServer |
| Module Loader | Bestanden | `validate-core-modules.ps1` | Toposort, Zyklen, Fehlerstatus, Stop-Reihenfolge | Keine fachlichen Module registriert |
| Permissions | Bestanden | `validate-core-permissions.ps1` | Allow/Deny, Vererbung, Wildcards, Cache, Audit | Adminrollen-Belegung folgt spaeter |
| Sessions | Bestanden | `validate-core-sessions.ps1` | License-Pflicht, Reconnect, Drop, Datenschutz | Echte Connect/Drop-Flows brauchen FXServer |
| Cache | Bestanden | `validate-core-cache.ps1` | TTL, Cleanup, GetOrLoad, Stats, Limits | Runtime-Lasttests spaeter sinnvoll |
| Oeffentliche API | Bestanden | Dokumentation und Manifest | Exports dokumentiert | Exportaufrufe live testen |
| Resource-Start | Teilweise | statische Lifecycle-Pruefung | Startpfad vorhanden | Manueller FXServer-Test erforderlich |
| Resource-Stop | Teilweise | statische Lifecycle-Pruefung | Stop- und Cleanup-Pfad vorhanden | Manueller FXServer-Test erforderlich |
| Dependency-Ausfall | Teilweise | statische Dependency-Pruefung | `oxmysql` als Pflichtdependency erkannt | Live-Ausfalltest erforderlich |
| Dokumentation | Bestanden | README und Architekturdocs aktualisiert | Kapitel-01-Doku vorhanden | Weiterpflege bei Kapitel 02 |
| Namenskonventionen | Bestanden | `validate-core-foundation.ps1` | Nexa-Namespace und Exports geprueft | Neue Ressourcen muessen Konventionen halten |
| Security-Grenzen | Bestanden | Such- und Fachvalidierung | Kein Clientvertrauen als Core-Prinzip | Fachmodule spaeter separat pruefen |

## Ausgefuehrte Tests

Automatisiert:

- `scripts/validate-core-foundation.ps1`
- `scripts/validate-core-lifecycle.ps1`
- `scripts/validate-core-logger.ps1`
- `scripts/validate-core-config.ps1`
- `scripts/validate-core-database.ps1`
- `scripts/validate-core-eventbus.ps1`
- `scripts/validate-core-callbacks.ps1`
- `scripts/validate-core-modules.ps1`
- `scripts/validate-core-permissions.ps1`
- `scripts/validate-core-sessions.ps1`
- `scripts/validate-core-cache.ps1`
- `git diff --check`

Repository-Suchen:

- QBCore/Qbox/ESX/ox_lib-Reste im neuen Core
- TODO/FIXME/Platzhalter
- unstrukturierte Prints
- 0-ms-Loop-Muster
- Hardware-ID-Logik
- direkte Netzwerkevents
- SQL-Muster und dynamische Stringstellen

## Nicht automatisierbare Tests

Diese Tests brauchen FXServer, MariaDB und `oxmysql`:

- echter Starttest
- echter Stoptest
- Restarttest
- `oxmysql` fehlt
- Datenbank nicht verfuegbar
- Migration bereits ausgefuehrt gegen echte DB
- fehlerhafte Migration gegen echte DB
- Spieler Connect/Drop
- Callback-Timeout mit echtem Client
- Event-Listener-Fehler zur Laufzeit
- Cache-Ablauf unter Runtime-Timer
- Exporttests aus anderer Resource

Anleitung: `docs/architecture/core-testing.md`.

## Geaenderte Dateien

- `[nexa-core]/nexa-core/README.md`
- `docs/architecture/core-overview.md`

## Neue Dateien

- `scripts/validate-core-foundation.ps1`
- `docs/architecture/core-testing.md`
- `docs/architecture/core-operations.md`
- `docs/architecture/core-troubleshooting.md`
- `docs/architecture/core-chapter01-validation.md`

## Migrationen

- `001_foundation`: Core-Tabellen `nexa_players`, `nexa_characters`, `nexa_permissions`, `nexa_audit_log`
- `002_permission_foundation`: Rollen, Rollen-Permissions, Rollenvererbung, Subject-Rollen, Subject-Permissions

## Oeffentliche Exports

- `GetCoreObject`
- `GetPlayer`
- `GetCharacter`
- `ListCharacters`
- `HasPermission`
- `GetIdentifier`
- `CreateCharacter`
- `SelectCharacter`
- `UpdateCharacter`

## Interne Module und APIs

- `Nexa.Bootstrap`
- `Nexa.Lifecycle`
- `Nexa.Logger`
- `Nexa.Config`
- `Nexa.Database`
- `Nexa.EventBus`
- `Nexa.Events`
- `Nexa.Callbacks`
- `Nexa.Modules`
- `Nexa.Permissions`
- `Nexa.Sessions`
- `Nexa.Cache`
- `Nexa.Players`
- `Nexa.Characters`

## Fehlercodes

Zentrale Codes:

- `OK`
- `INVALID_INPUT`
- `NOT_FOUND`
- `NO_PERMISSION`
- `DATABASE_ERROR`
- `SECURITY_REJECTED`
- `CHARACTER_NOT_LOADED`
- `CORE_NOT_READY`
- `LIFECYCLE_ERROR`
- `INTERNAL_ERROR`

Spezialisierte Codes:

- `CONFIG_INVALID`
- `DATABASE_MIGRATIONS_FAILED`
- `DB_INVALID_INPUT`
- `DB_TIMEOUT`
- `DB_UNAVAILABLE`
- `DB_QUERY_FAILED`
- `DB_TRANSACTION_FAILED`
- `DB_MIGRATION_FAILED`
- `DB_MIGRATION_CHECKSUM_MISMATCH`
- `TIMEOUT`
- `RATE_LIMITED`
- `INVALID_PAYLOAD`
- `DISCONNECTED`
- `ROLE_INHERITANCE_CYCLE`
- `MISSING_LICENSE`
- `INVALID_STATE_TRANSITION`
- `SECRET_CACHE_BLOCKED`
- `VALUE_TOO_LARGE`
- `LOAD_IN_PROGRESS`

## Offene Punkte

- Live-FXServer-Tests stehen noch aus.
- Adminrollen und finale Rechtebelegung sind nicht Teil von Kapitel 01.
- Gameplay-Systeme bleiben absichtlich ausserhalb des Core.
- Die dedizierte Resource `nexa_permissions` existiert parallel und muss spaeter mit der Core-Foundation strategisch vereinheitlicht werden.
- Vorhandene unstaged Faction-Deletes im Worktree gehoeren nicht zu Kapitel 01.

## Empfehlungen fuer Kapitel 02

1. Ein kleines FXServer-Testharness fuer Start/Stop/Restart und Client-Callback-Roundtrips aufbauen.
2. `nexa_api` auf die neuen Core-APIs ausrichten.
3. Permission-Resource und Core-Permission-Foundation konsolidieren oder klare Ownership definieren.
4. Domain-Resources schrittweise auf `Nexa.Database`, `Nexa.Cache`, `Nexa.Callbacks` und `Nexa.Permissions` migrieren.
5. Runtime-Metriken fuer Sessions, Cache, DB-Health und Callback-Pendings als Admin-Status ausgeben.
6. Kapitel 02 erst starten, wenn die manuellen FXServer-Tests fuer Kapitel 01 abgeschlossen sind.
