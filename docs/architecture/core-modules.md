# Nexa Core Module Loader

Stand: 2026-07-10

Der interne Module Loader von `nexa-core` steuert Core-Komponenten innerhalb derselben FiveM-Resource. Er ist bewusst kein dynamischer Loader fuer beliebige FiveM-Ressourcen und ersetzt nicht `ensure`, `fxmanifest.lua` oder die Server-Startreihenfolge.

## Zweck

Der Loader loest drei Probleme im Core:

- Core-Komponenten koennen ihre Abhaengigkeiten explizit deklarieren.
- Initialisierung, Start, Ready und Stop laufen in reproduzierbarer Reihenfolge.
- Fehler in kritischen Modulen verhindern den Core-Start kontrolliert, waehrend nicht kritische Module isoliert fehlschlagen duerfen.

## Modulformat

Ein Modul wird serverseitig ueber `Nexa.Modules.Register(definition)` registriert.

Pflichtfelder:

- `name`: eindeutiger Modulname, zum Beispiel `database`, `sessions` oder `permissions`.
- `version`: Modulversion als String.

Optionale Felder:

- `dependencies`: harte Modulabhaengigkeiten. Fehlt eine davon, kann der Loader nicht sortieren.
- `optionalDependencies`: weiche Abhaengigkeiten. Sind sie vorhanden, werden sie in die Reihenfolge einbezogen; fehlen sie, wird nur geloggt.
- `critical`: Standard `true`. Kritische Module verhindern bei Fehlern den Core-Start.
- `optional`: Alternative zu `critical = false`.
- `Initialize(module)`: fruehe Initialisierung.
- `Start(module)`: Start nach Core-`starting`-Hooks.
- `Ready(module)`: Ready-Phase kurz vor Core-`ready`.
- `Stop(module)`: kontrolliertes Stoppen.
- `Health(module)`: optionale Health-Daten.
- `metadata`: freie interne Metadaten.

## Lifecycle

Der Core-Bootstrap ruft den Loader an festen Punkten auf:

1. Nach erfolgreicher Konfiguration, Pflichtresource-Pruefung, DB-Health und Migrationen: `Nexa.Modules.InitializeAll()`.
2. Im Core-Zustand `starting`, nach den bestehenden Lifecycle-Hooks: `Nexa.Modules.StartAll()`.
3. Direkt danach und vor dem Core-Zustand `ready`: `Nexa.Modules.ReadyAll()`.
4. Beim Core-Stop nach `stopping`-Hooks und vor `stopped`: `Nexa.Modules.StopAll(reason)`.

Beim Stop wird die zuletzt gestartete Reihenfolge umgekehrt. Dadurch werden abhaengige Module vor ihren Abhaengigkeiten beendet.

## Dependency-Regeln

Der Loader baut aus `dependencies` und vorhandenen `optionalDependencies` einen Graphen und sortiert ihn topologisch.

Regeln:

- Harte Dependencies muessen registriert sein.
- Optionale Dependencies duerfen fehlen.
- Zyklen sind ungueltig.
- Ein Modul darf nur einmal registriert werden.
- Ein bereits initialisierter oder gestarteter Loader blockiert doppelte Starts.

Der Loader startet keine externen Resources. Externe FiveM-Abhaengigkeiten bleiben im `fxmanifest.lua` und in der Core-Lifecycle-Dependency-Pruefung.

## Fehlerverhalten

Fehler werden strukturiert ueber `Nexa.Logger` geloggt.

Kritische Module:

- Fehler in `Initialize`, `Start` oder `Ready` beenden die Phase.
- Der Bootstrap geht in den Core-Zustand `failed`.
- Bereits gestartete oder teilweise initialisierte Module werden ueber `StopAll()` kontrolliert gestoppt.

Nicht kritische Module:

- Fehler werden am Modul markiert.
- Der Core-Start darf weiterlaufen, sofern keine kritische Abhaengigkeit dadurch fehlschlaegt.

Fehler in `Stop` verhindern nicht das Stoppen weiterer Module. Das betroffene Modul wird als `failed` markiert.

## Status und Health

Interne API:

- `Nexa.Modules.Get(name)`
- `Nexa.Modules.GetStatus(name)`
- `Nexa.Modules.GetAllStatuses()`
- `Nexa.Modules.IsReady(name)`
- `Nexa.Modules.GetHealth(name)`

Statuswerte:

- `registered`
- `initializing`
- `initialized`
- `starting`
- `started`
- `readying`
- `ready`
- `stopping`
- `stopped`
- `failed`

`GetHealth(name)` liefert Basisdaten wie Name, Version, Status, Ready-Flag, Kritikalitaet und Fehlergrund. Falls ein Modul eine eigene `Health`-Funktion besitzt, werden deren Werte in die Antwort gemischt.

## Beispiel

```lua
Nexa.Modules.Register({
    name = 'sessions',
    version = '1.0.0',
    dependencies = { 'database' },
    optionalDependencies = { 'permissions' },
    critical = true,
    Initialize = function(module)
        -- Caches vorbereiten
    end,
    Start = function(module)
        -- Runtime aktivieren
    end,
    Ready = function(module)
        -- Ab jetzt darf das Modul produktiv genutzt werden
    end,
    Stop = function(module)
        -- Runtime sauber entladen
    end,
    Health = function(module)
        return {
            cacheSize = 0
        }
    end
})
```

## Abgrenzung

Der Loader ist nur fuer interne `nexa-core`-Module gedacht. Domain-Ressourcen wie `nexa_items`, `nexa_inventory`, `nexa_jobscreator` oder `nexa_shops` werden weiterhin als normale FiveM-Ressourcen gestartet und integrieren sich ueber Exports, Callbacks, Events oder spaeter definierte API-Fassaden.
