# Core Configuration

Stand: 2026-07-10

`nexa-core` besitzt ein validierbares Konfigurationssystem unter `Nexa.Config`. Es ersetzt lose globale Konfigurationstabellen durch einen zentralen, validierten und immutable Snapshot. Bestehende direkte Lesezugriffe wie `Nexa.Config.character.maxPerPlayer` bleiben moeglich.

## Ziele

- zentrale Core-Konfiguration
- dokumentierte Defaults
- Umgebungsspezifische Overrides
- serverseitige Werte
- clientseitig freigegebene Werte
- Schema-Validierung
- Typ- und Bereichspruefung
- Pflichtfelder
- kontrollierte Behandlung unbekannter Felder
- immutable Snapshots
- sichere Pfadabfragen
- kein Secret-Leak an Clients

## API

```lua
Nexa.Config.Get(path, defaultValue)
Nexa.Config.Has(path)
Nexa.Config.GetSection(path)
Nexa.Config.Validate()
Nexa.Config.GetEnvironment()
Nexa.Config.GetPublicSnapshot()
```

`path` ist ein Punktpfad, zum Beispiel:

```lua
local timeout = Nexa.Config.Get('callbacks.timeoutMs', 10000)
local characterConfig = Nexa.Config.GetSection('character')
```

## Struktur

Aktuelle Core-Sektionen:

- `debug`: globaler Debug-Schalter.
- `environment`: `development`, `staging`, `production` oder `test`.
- `defaultPermissionRole`: server-only Standardrolle.
- `identifierPriority`: server-only Identifier-Reihenfolge.
- `character`: Character-Limits und Validierungswerte.
- `callbacks`: Callback-Cooldown und Timeout.
- `logging`: Logging-Level.
- `validation`: Verhalten bei unbekannten Feldern.
- `server.secrets`: server-only Secret-Bereich.

## Umgebungen

Die Umgebung kommt aus:

```cfg
setr nexa:environment development
```

Unterstuetzte Werte:

- `development`
- `staging`
- `production`
- `test`

Umgebungsspezifische Overrides werden vor Runtime-Convars angewendet. Runtime-Convars duerfen definierte Werte gezielt ueberschreiben.

## Defaults

Dokumentierte Defaults:

```lua
debug = false
environment = 'development'
defaultPermissionRole = 'user'
identifierPriority = { 'license', 'license2', 'fivem', 'steam', 'discord' }
character.maxPerPlayer = 4
character.minNameLength = 2
character.maxNameLength = 32
character.minBirthYear = 1900
character.maxBirthYear = 2010
callbacks.defaultCooldownMs = 1000
callbacks.timeoutMs = 10000
logging.level = 'info'
validation.unknownFields = 'warn'
```

## Convars

Aktuell genutzte Convars:

```cfg
setr nexa:debug false
setr nexa:environment development
setr nexa:maxCharacters 4
setr nexa:logLevel info
setr nexa:configUnknownFields warn
set nexa:bootstrapToken ""
```

`nexa:bootstrapToken` ist server-only. Es darf nicht als `setr` veroeffentlicht werden.

## Secret-Regeln

Server-Secrets duerfen niemals an Clients gehen.

Regeln:

- Secrets liegen nur in `serverOnly`-Sektionen.
- Secrets sind im Schema mit `secret = true` markiert.
- `GetPublicSnapshot()` entfernt `serverOnly`, `secret` und `public = false`.
- Client-UI und Client-Resources verwenden nur `GetPublicSnapshot()`.
- Secrets duerfen nicht geloggt werden.

## Public Snapshot

`Nexa.Config.GetPublicSnapshot()` liefert nur freigegebene Werte. Aktuell freigegeben:

- `debug`
- `environment`
- `character`
- `callbacks`
- `logging`

Nicht freigegeben:

- `defaultPermissionRole`
- `identifierPriority`
- `validation`
- `server`
- `server.secrets`

## Validierung

`Nexa.Config.Validate()` liefert:

```lua
local ok, errors, warnings = Nexa.Config.Validate()
```

Fehler verhindern den Core-Start. Warnungen werden geloggt, blockieren aber nicht.

Validiert wird:

- fehlende Pflichtfelder
- falsche Typen
- erlaubte Werte
- Zahlenbereiche
- Array-Elementtypen
- unbekannte Felder
- zusammenhaengende Bereiche wie `minNameLength <= maxNameLength`

## Unbekannte Felder

`validation.unknownFields` unterstuetzt:

- `warn`: unbekannte Felder werden geloggt, Start laeuft weiter.
- `error`: unbekannte Felder verhindern den Start.
- `ignore`: unbekannte Felder werden ignoriert.

## Immutable Snapshots

Die Konfiguration wird nach dem Aufbau eingefroren. Laufzeitaenderungen sind standardmaessig nicht erlaubt:

```lua
Nexa.Config.character.maxPerPlayer = 99 -- Fehler
```

Es gibt keinen automatischen Hot-Reload fuer sicherheitskritische Einstellungen. Ein spaeterer Reload muss explizit, serverseitig und mit eigenen Reload-Hooks gebaut werden.

## Beispiel

```cfg
setr nexa:environment production
setr nexa:debug false
setr nexa:maxCharacters 4
setr nexa:logLevel info
setr nexa:configUnknownFields error
set nexa:bootstrapToken "server-local-secret"
```

## Bootstrap-Verhalten

`nexa-core` validiert die Konfiguration waehrend `Nexa.Bootstrap.Initialize()`. Bei Fehlern:

- Fehler werden strukturiert geloggt.
- Bootstrap gibt `CONFIG_INVALID` zurueck.
- Lifecycle geht auf `failed`.
- Core meldet keine Bereitschaft.
