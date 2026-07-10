# Core Test Guide

Stand: 2026-07-10

Dieses Dokument beschreibt die automatisierten und manuellen Tests fuer Kapitel 01 `nexa-core`.

## Automatisierte Validierung

Gesamtlauf:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-foundation.ps1
```

Der Gesamtlauf prueft:

- Bootstrap und Lifecycle
- Logger
- Konfiguration
- Datenbank-Layer und Migrationen
- EventBus
- Callback-System
- Module Loader
- Permission-Grundsystem
- Session Manager
- Cache
- Suchregeln gegen QBCore/Qbox/ESX/ox_lib-Reste
- TODO/FIXME/Platzhalter
- unstrukturierte Prints
- offensichtliche 0-ms-Loop-Muster

## Einzeltests

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-lifecycle.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-logger.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-config.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-database.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-eventbus.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-callbacks.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-modules.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-permissions.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-sessions.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-cache.ps1
```

## FXServer-Tests

Diese Tests sind nicht vollstaendig lokal automatisierbar, weil sie eine laufende FiveM/FXServer-Instanz, MariaDB und `oxmysql` brauchen.

Fuer reproduzierbare Runtime-Abnahmen gibt es zusaetzlich den manuellen Harness:

```text
ensure nexa-core-runtime-tests
nexa_test_core_runtime all
```

Die Resource liegt unter `[nexa-tests]/nexa-core-runtime-tests` und wird nicht automatisch in `server/foundation.dev.cfg` gestartet. Details stehen in [core-runtime-validation.md](core-runtime-validation.md).

### Starttest

1. `ensure oxmysql`
2. `ensure nexa-core`
3. Erwartet: Lifecycle erreicht `ready`.
4. Erwartet: Konsole zeigt keine `SCRIPT ERROR`.
5. Erwartet: `nexa_core_status` zeigt `ready = true`.

### Stoptest

1. `stop nexa-core`
2. Erwartet: Lifecycle laeuft ueber `stopping` nach `stopped`.
3. Erwartet: Sessions, Cache und Pending Requests werden geschlossen.

### Restarttest

1. `restart nexa-core`
2. Erwartet: keine verwaisten Sessions, keine doppelten Hooks, kein doppelter Cache-Cleanup.
3. Erwartet: Migrationen werden nicht doppelt fehlerhaft ausgefuehrt.

### Dependency-Ausfall

1. `stop oxmysql`
2. `restart nexa-core`
3. Erwartet: Core geht in `failed`.
4. Erwartet: `IsReady()` bleibt false.

### Migrationen

- Bereits ausgefuehrte Migration: Erwartet idempotent und checksum-stabil.
- Fehlerhafte Migration: Erwartet klarer Fehler, kein falscher Ready-Zustand.

### Session Connect/Drop

1. Spieler verbindet sich mit License.
2. Erwartet: Session `active`.
3. Spieler disconnectet.
4. Erwartet: Session `closed`, Source-Index entfernt.

### Permission-Checks

1. Direkte Permission `Grant` setzen.
2. `Has` pruefen.
3. `Deny` setzen.
4. Erwartet: Deny gewinnt.

### Callback-Timeout

1. Callback ohne Antwort simulieren.
2. Erwartet: `TIMEOUT`, Pending Request entfernt.

### Event-Listener-Fehler

1. EventBus-Listener mit Fehler registrieren.
2. Event emitten.
3. Erwartet: Fehler wird geloggt, weitere Listener laufen weiter.

### Cache-Ablauf

1. Cachewert mit kurzem `ttlMs` setzen.
2. Nach Ablauf `Get` ausfuehren.
3. Erwartet: `EXPIRED`, Eintrag entfernt, Expiration-Statistik erhoeht.

### Exporttests

Pruefen:

- `GetCoreObject`
- `GetPlayer`
- `GetCharacter`
- `ListCharacters`
- `HasPermission`
- `GetIdentifier`
- `CreateCharacter`
- `SelectCharacter`
- `UpdateCharacter`

Exports duerfen vor Core-Ready keine falschen produktiven Antworten liefern.

Mutierende Character-Exports werden im automatischen Runtime-Harness bewusst nicht ausgefuehrt. Sie gehoeren fachlich spaeter in eine Character-/Identity-Resource und duerfen erst in einer isolierten Testdatenbank mit echtem Testspieler validiert werden. Die Bewertung steht in [core-domain-boundary-review.md](core-domain-boundary-review.md).
