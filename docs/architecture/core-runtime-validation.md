# Core Runtime Validation

Stand: 2026-07-10

Dieses Dokument beschreibt die FXServer-Runtime-Abnahme fuer Kapitel 01 `nexa-core`.

## Ausgangslage

Lokale Pruefung im Repository `NexaRoleplayScripts`:

- Letzter bestaetigter Core-Commit vor dieser Abnahme: `c3efe9b test(core): validate core foundation`
- Branch: `main`
- FXServer executable not available in PATH: `FXServer` und `FXServer.exe` waren lokal nicht auffindbar.
- `mysql` und `mariadb` waren lokal ebenfalls nicht im `PATH` auffindbar.
- `[ox]/oxmysql` ist im Repository vorhanden.
- `server/foundation.dev.cfg` enthaelt bereits eine Development-Startreihenfolge mit `oxmysql`, `nexa-core` und bestehenden Smoke-Test-Resources.
- Bestehende unstaged Deletes in `[nexa-factions]` wurden nicht angefasst.

Die reale Runtime wurde deshalb lokal nicht simuliert und nicht als bestanden ausgegeben. Die neu erstellte Resource `[nexa-tests]/nexa-core-runtime-tests` ist ein kontrollierter Harness fuer echte FXServer-Laeufe.

## Runtime-Harness

Resource:

```text
[nexa-tests]/nexa-core-runtime-tests
```

Zweck:

- kontrollierte Runtime-Pruefung von `nexa-core`
- keine Gameplay-Logik
- keine UI
- keine QBCore/Qbox/ESX/ox_lib-Abhaengigkeit
- keine automatischen Datenmutationen
- keine Aenderung an `server.cfg`, `systemd`, `txAdmin` oder `server/foundation.dev.cfg`

Start nur manuell:

```text
ensure nexa-core-runtime-tests
nexa_test_core_runtime all
```

Spielerduerfen den Command nur mit ACE ausfuehren:

```cfg
add_ace group.admin nexa.test.core_runtime allow
```

Die Konsole darf den Command direkt ausfuehren.

## Gepruefte Runtime-Bereiche

| Suite | Zweck | Mutation |
| --- | --- | --- |
| `core_readiness` | `GetCoreObject`, Lifecycle-State, Ready-Status | nein |
| `database_health` | `Database.IsReady`, `SELECT 1`, Migrationstabelle lesbar | nein |
| `public_exports_defensive` | Exports mit invaliden Sources defensiv pruefen | nein |
| `event_bus` | On, Once, Off, Prioritaeten, Fehlerisolation | nur interne Test-Listener |
| `cache_runtime` | Set, Get, TTL, GetOrLoad, Secret-Guard | nur Test-Namespace |
| `callbacks_runtime` | interner Callback, Validation, NOT_FOUND | nur temporaerer Callback |
| `sessions_runtime` | invalid source, missing license, cleanup | temporaere rejected Session |
| `permissions_runtime` | invalid subject, DecisionTrace | nein |
| `modules_runtime` | Modulstatus und kritische Fehler | nein |
| `manual_runtime_boundaries` | listet nicht automatisierbare Akzeptanzpunkte | nein |

## Manuelle Runtime-Abnahme

Diese Tests duerfen nur in einer echten Development-FXServer-Instanz mit kontrollierter Datenbank laufen.

### Start

1. MariaDB starten.
2. `oxmysql` starten.
3. `nexa-core` starten.
4. `nexa-core-runtime-tests` manuell starten.
5. `nexa_test_core_runtime all` ausfuehren.

Erwartung:

- `core_readiness` ist `pass`.
- `database_health` ist `pass`.
- Keine `SCRIPT ERROR`.
- Finale Summary hat `fail = 0`.
- `skip` ist nur fuer dokumentierte manuelle Grenzen erlaubt.

### Stop

1. `stop nexa-core-runtime-tests`.
2. `stop nexa-core`.

Erwartung:

- Core wechselt kontrolliert nach `stopping` und `stopped`.
- Cache-Cleanup stoppt.
- Pending Callback Requests alter Spieler bleiben nicht offen.

### Restart

1. `restart nexa-core`.
2. `ensure nexa-core-runtime-tests`.
3. `nexa_test_core_runtime all`.

Erwartung:

- keine doppelten Lifecycle-Hooks
- keine doppelten Module
- keine doppelten Cache-Cleanup-Threads
- Migrationen werden idempotent erkannt

### Fehlendes oxmysql

1. In einer isolierten Development-Session `oxmysql` nicht starten.
2. `ensure nexa-core`.

Erwartung:

- Core meldet einen klaren Dependency-Fehler.
- Lifecycle-State wird `failed`.
- `IsReady()` meldet false.
- Public Exports melden keine falsche Bereitschaft.

### Datenbank nicht verfuegbar

1. `oxmysql` starten, aber MariaDB absichtlich nicht erreichbar machen.
2. `ensure nexa-core`.

Erwartung:

- Core geht nicht `ready`.
- Fehler ist als Datenbank-/Health-Fehler sichtbar.
- SQL-Details werden nicht ungefiltert an Clients geleakt.

### Migration bereits ausgefuehrt

1. Core einmal starten.
2. Core erneut starten.

Erwartung:

- `nexa_core_migrations` wird gelesen.
- Bereits angewendete Migrationen werden nicht doppelt ausgefuehrt.
- Checksumme bleibt stabil.

### Fehlerhafte Migration

Nur in isolierter Testdatenbank:

1. Testmigration mit fehlerhaftem SQL registrieren.
2. Core starten.

Erwartung:

- Migration wird als failed markiert.
- Core meldet `failed`.
- Keine falsche Ready-Meldung.

### Session Connect/Drop

1. Spieler mit gueltiger License verbindet sich.
2. Harness ausfuehren.
3. Spieler disconnectet.

Erwartung:

- Session wird `active`.
- Drop schliesst Session.
- Source- und License-Index werden bereinigt.

### Callback Timeout und Disconnect

1. Server-zu-Client-Callback gegen einen Testclient starten.
2. Keine Antwort senden oder Client disconnecten.

Erwartung:

- `TIMEOUT` oder `DISCONNECTED`.
- Pending Request wird entfernt.
- Falsche Source-Responses werden blockiert.

## Nicht automatisierbare Tests im lokalen Kontext

Nicht lokal ausgefuehrt, weil kein FXServer-Binary und kein MariaDB-CLI im PATH verfuegbar waren:

- echter Resource-Start mit FXServer
- echter Stop/Restart
- gestopptes `oxmysql`
- nicht erreichbare Datenbank
- echte Player-Session
- echter Client-Callback-Roundtrip

Diese Punkte bleiben als manuelle Runtime-Abnahme offen, bis eine echte Development-Instanz bereitsteht.

## Bewertung

Der Harness reduziert das Risiko, indem er echte Runtime-Pfade prueft, ohne die Domain-Grenzen zu verwischen. Er ersetzt keine echte FXServer-Abnahme, verhindert aber, dass manuelle Konsolentests ad hoc und ohne reproduzierbare Suite durchgefuehrt werden.
