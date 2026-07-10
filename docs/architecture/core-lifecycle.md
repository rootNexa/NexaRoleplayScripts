# Core Lifecycle

Stand: 2026-07-10

`nexa-core` besitzt eine kontrollierte Bootstrap- und Lifecycle-Schicht. Sie verhindert stille Teilstarts, doppelte Initialisierung und oeffentliche API-Zugriffe, bevor der Core vollstaendig bereit ist.

## Zustaende

Der Core verwendet folgende internen Zustaende:

- `created`: Lua-Dateien sind geladen, Bootstrap wurde noch nicht gestartet.
- `initializing`: Abhaengigkeiten, Datenbank und Initialisierungshooks werden geprueft.
- `initialized`: Initialisierung ist abgeschlossen, aber Runtime-Start-Hooks liefen noch nicht.
- `starting`: Runtime-Hooks laufen, bestehende Spieler werden registriert.
- `ready`: Core ist bereit; API-Zugriffe, Events und Callbacks duerfen arbeiten.
- `stopping`: Resource wird kontrolliert heruntergefahren.
- `stopped`: Stop-Hooks sind abgeschlossen.
- `failed`: Bootstrap oder Lifecycle ist fehlgeschlagen; APIs melden keine Bereitschaft.

## Zustandswechsel

Gueltige Wechsel:

```text
created -> initializing
created -> failed
initializing -> initialized
initializing -> failed
initialized -> starting
initialized -> stopping
initialized -> failed
starting -> ready
starting -> stopping
starting -> failed
ready -> stopping
ready -> failed
stopping -> stopped
stopping -> failed
stopped -> initializing
failed -> stopping
```

Alle anderen Wechsel werden blockiert und geloggt. Ein blockierter Wechsel veraendert den aktuellen Zustand nicht.

## Bootstrap

Der Resource-Start ruft `Nexa.Bootstrap.Start()` auf. Der Ablauf ist:

1. Doppelte Initialisierung pruefen.
2. Zustand `initializing` setzen.
3. `initializing`-Hooks ausfuehren.
4. Pflichtabhaengigkeiten pruefen.
5. Datenbankbereitschaft pruefen.
6. Zustand `initialized` setzen.
7. `initialized`-Hooks ausfuehren.
8. Zustand `starting` setzen.
9. `starting`-Hooks ausfuehren.
10. Zustand `ready` setzen.
11. `ready`-Hooks ausfuehren.

Wenn ein Schritt fehlschlaegt, wird der Core auf `failed` gesetzt. Der Fehlergrund ist ueber `Nexa.Lifecycle.GetFailureReason()` intern verfuegbar.

## Pflichtabhaengigkeiten

Aktuell ist nur `oxmysql` Pflichtabhaengigkeit. Fehlt `oxmysql` oder ist die Datenbank nicht erreichbar, startet `nexa-core` nicht still weiter:

- Zustand wird `failed`.
- Fehler wird klar geloggt.
- `Nexa.Bootstrap.started` bleibt `false`.
- `Nexa.Lifecycle.IsReady()` bleibt `false`.
- Exports, Events und Callbacks melden keine falsche Bereitschaft.

## Hooks

Interne Hooks werden registriert ueber:

```lua
Nexa.Lifecycle.RegisterLifecycleHook(stage, callback)
```

Unterstuetzte Stages entsprechen den Lifecycle-Stages:

- `initializing`
- `initialized`
- `starting`
- `ready`
- `stopping`
- `stopped`
- `failed`

Hook-Fehler werden mit `pcall` isoliert. Fehler in Start-/Initialisierungshooks fuehren kontrolliert zu `failed`. Fehler in Stop-Hooks werden geloggt; der Stop wird fortgesetzt.

Aktuelle interne Hooks:

- `starting`: Online-Spieler werden in Nexa Sessions registriert.
- `stopping`: Sessions und Character-Caches werden kontrolliert entladen.

## Readiness

Interne Readiness-API:

- `Nexa.Lifecycle.GetState()`
- `Nexa.Lifecycle.IsReady()`
- `Nexa.Lifecycle.RegisterLifecycleHook(stage, callback)`
- `Nexa.Lifecycle.GetStartTimestamp()`
- `Nexa.Lifecycle.GetFailureReason()`

`Nexa.Lifecycle.RequireReady(operation)` schuetzt Zugriffe, die erst nach `ready` erlaubt sind.

Geschuetzt sind:

- Core-Exports ausser `GetCoreObject`
- Core Server-Callbacks
- Core Net Events
- `playerJoining`
- `playerDropped` ausser waehrend `stopping`

## Stop

FiveM signalisiert Resource-Stops ueber `onResourceStop`. Wenn `nexa-core` stoppt, wird `Nexa.Bootstrap.Stop('resource_stop')` ausgefuehrt:

1. Zustand `stopping`.
2. Stop-Hooks ausfuehren.
3. Zustand `stopped`.
4. Stopped-Hooks ausfuehren.

Wenn eine Pflichtabhaengigkeit wie `oxmysql` stoppt, waehrend der Core `ready` ist, wird der Core auf `failed` gesetzt. So meldet er nicht weiter Bereitschaft, obwohl die Grundlage fehlt.

## Server-Shutdown

FiveM meldet Server-Shutdowns nicht in allen Situationen als separates Ereignis. Der verlaessliche Pfad ist `onResourceStop`, der auch beim Stop der Resource oder beim Server-Shutdown feuern soll. Darueber laeuft das kontrollierte Entladen.
