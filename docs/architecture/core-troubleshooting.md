# Core Troubleshooting

Stand: 2026-07-10

## Core bleibt `failed`

Pruefen:

- Ist `oxmysql` gestartet?
- Ist MariaDB erreichbar?
- Sind Configwerte gueltig?
- Ist eine Migration fehlgeschlagen?

Validierung:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-foundation.ps1
```

In einer echten FXServer-Instanz:

```text
ensure nexa-core-runtime-tests
nexa_test_core_runtime core_readiness
```

## `Could not find dependency oxmysql`

`oxmysql` fehlt oder wird nach `nexa-core` gestartet. Startreihenfolge korrigieren:

```cfg
ensure oxmysql
ensure nexa-core
```

## Migration schlägt fehl

Pruefen:

- Tabelle `nexa_core_migrations`.
- Checksumme der Migration.
- MariaDB-Rechte.
- Ob eine bereits angewendete Migration nachtraeglich veraendert wurde.

Regel: Veraenderte angewendete Migrationen muessen durch neue Migrationen ersetzt werden.

## Spieler wird abgelehnt

Moegliche Ursachen:

- Keine `license` oder `license2` vorhanden.
- Source nicht gueltig.
- Datenbankfehler beim Erstellen des Accounts.

Der Session Manager darf IP-Adressen nicht als Ersatz-Identifier verwenden.

## Permission wird nicht erkannt

Pruefen:

- Permissionformat `nexa.<bereich>.<aktion>`.
- Existiert ein explizites Deny?
- Ist die Rolle aktiv?
- Gibt es einen Rollenvererbungszyklus?
- Wurde der Cache invalidiert?

Debug:

```lua
Nexa.Permissions.GetDecisionTrace(source, 'nexa.admin.kick')
```

## Callback antwortet nicht

Pruefen:

- Callbackname folgt `nexa:<resource>:cb:<action>`.
- Netzwerkcallback ist explizit registriert.
- Timeout wurde erreicht.
- Spieler ist disconnected.
- Source-Bindung der Response passt.

Runtime-Harness:

```text
nexa_test_core_runtime callbacks_runtime
```

Der Harness prueft interne Callback-Pfade. Ein echter Server-zu-Client-Timeout braucht einen verbundenen Testclient und bleibt ein manueller Runtime-Test.

## EventBus Listener blockiert

Fehler in Listenern werden geloggt. Bei `failFast` kann ein Event bewusst abbrechen. Rekursive Events werden durch das Depth-Limit blockiert.

## Cache liefert alte Daten

Pruefen:

- Wurde nach einer Schreiboperation `Cache.Delete` oder `Cache.Clear` aufgerufen?
- Ist ein passendes `ttlMs` gesetzt?
- Wird der richtige Namespace verwendet?

Runtime-Harness:

```text
nexa_test_core_runtime cache_runtime
```

Der Harness verwendet nur den Namespace `runtime_tests`.

## Runtime-Harness startet nicht

Pruefen:

- Wurde `nexa-core` vorher gestartet?
- Ist die Resource `[nexa-tests]/nexa-core-runtime-tests` im FXServer Resource-Pfad sichtbar?
- Wird der Command aus der Konsole oder von einem Spieler mit ACE `nexa.test.core_runtime` ausgefuehrt?
- Wurde die Resource versehentlich in Production ensured? Das ist nicht vorgesehen.

## Keine Logs sichtbar

Pruefen:

- Logger-Level.
- Console-Adapter.
- Ob ein externer Adapter Fehler wirft. Adapterfehler werden isoliert und in der Console gemeldet.

## Performance-Symptome

Pruefen:

- Dauerhafte Threads.
- Zu kurze Cache-Cleanup-Intervalle.
- Sehr grosse Cachewerte.
- Unbegrenzte Namespaces.
- EventBus-Listener, die nicht entfernt werden.
- Offene Callback-Pendings.
