# Core Logging

Stand: 2026-07-10

`nexa-core` besitzt ein strukturiertes Logging-System unter `Nexa.Logger`. Es ersetzt unstrukturierte Logausgaben innerhalb des Core durch ein einheitliches Entry-Format, behaelt aber `Nexa.Log(level, message, context)` als kompatiblen Kurzweg fuer bestehende Core-Module.

## Ziele

- Einheitliche Logeintraege fuer alle Core-Module.
- Strukturierte Metadaten statt frei zusammengesetzter Strings.
- Schutz vor sensiblen Daten in Logs.
- Begrenzte Serialisierung grosser oder zyklischer Tabellen.
- Adapter-Schnittstelle fuer spaetere externe Ziele.
- Keine fest eingebauten Webhooks oder externen Logziele.

## Log-Level

Unterstuetzte Level:

- `debug`
- `info`
- `warn`
- `error`
- `audit`
- `security`

Die globale Mindeststufe wird mit `Nexa.Logger.SetLevel(level)` gesetzt. Standard ist `info`. Wenn `nexa:debug=true` gesetzt ist, startet der Logger mit `debug`.

## Logeintrag

Jeder Entry enthaelt:

- `timestamp`: UTC-Zeitstempel im ISO-aehnlichen Format.
- `level`: Log-Level.
- `resource`: aktuelle Resource.
- `module`: Modul aus `context.module` oder `nexa-core`.
- `category`: fachliche Kategorie.
- `message`: kurze Nachricht.
- `context`: optionale strukturierte Metadaten.
- `source`: optionale Spielerquelle aus `context.source`.
- `characterId`: optionale Character-ID aus `context.characterId` oder `context.character_id`.
- `correlationId`: optionale Correlation-ID aus `context.correlationId` oder `context.correlation_id`.

## API

```lua
Nexa.Logger.Debug(category, message, context)
Nexa.Logger.Info(category, message, context)
Nexa.Logger.Warn(category, message, context)
Nexa.Logger.Error(category, message, context)
Nexa.Logger.Audit(category, message, context)
Nexa.Logger.Security(category, message, context)
Nexa.Logger.WithContext(context)
Nexa.Logger.SetLevel(level)
```

Kompatibilitaetsweg:

```lua
Nexa.Log('info', 'Core Status', {
    category = 'status'
})
```

`Nexa.Log` ordnet bestehende Aufrufe der Kategorie `core` zu.

## Context-Merging

`WithContext` erstellt einen scoped Logger. Der Basis-Kontext wird mit dem Kontext des einzelnen Logaufrufs zusammengefuehrt.

```lua
local logger = Nexa.Logger.WithContext({
    module = 'characters',
    correlationId = requestId
})

logger.Info('character.select', 'Charakterauswahl gestartet.', {
    source = source,
    characterId = characterId
})
```

Der konkrete Logaufruf darf Basisfelder ueberschreiben, wenn das noetig ist.

## Erlaubte Logdaten

Erlaubt:

- technische Statuswerte
- stabile Fehlercodes
- Resource- und Modulnamen
- FiveM `source`
- interne IDs, wenn sie fuer Diagnose noetig sind
- Character-ID
- Correlation-ID
- Zaehler, Limits, Laufzeitstatus
- bereits freigegebene fachliche Labels

## Verbotene Logdaten

Nicht ungefiltert loggen:

- Passwoerter
- Tokens
- Secrets
- API-Keys
- Authorization Header
- Cookies
- Session-Werte
- vollstaendige IP-Adressen
- grosse Payloads
- ganze Player-Objekte, wenn sie Identifierlisten enthalten
- komplette Request- oder Datenbankpayloads ohne vorherige Reduktion

Der Logger maskiert sensible Keys automatisch mit `<redacted>` und kuerzt IP-Adressen auf die ersten zwei Oktette. Das ersetzt keine fachliche Vorsicht: Module sollen weiterhin nur notwendige Daten loggen.

## Serialisierungsschutz

Der Logger schuetzt gegen:

- zyklische Tabellen: Ausgabe `<cycle>`
- zu tiefe Tabellen: Ausgabe `<max_depth>`
- zu viele Tabellenfelder: `__truncated = true`
- zu lange Strings: Suffix `<truncated>`
- zu grosse encodierte Kontexte: kompakte Truncation-Metadaten
- nicht serialisierbare Typen: Ausgabe als Typmarker

## Adapter

Standardmaessig ist ein Konsolenadapter aktiv. Er schreibt strukturierte JSON-nahe Eintraege in die Konsole.

Adapter koennen registriert werden:

```lua
Nexa.Logger.RegisterAdapter('my_adapter', {
    level = 'warn',
    categories = { 'lifecycle', 'database' },
    write = function(entry)
        -- externe Weiterleitung spaeter hier
    end
})
```

Adapter koennen entfernt werden:

```lua
Nexa.Logger.RemoveAdapter('my_adapter')
```

Regeln:

- `write(entry)` ist Pflicht.
- `level` ist optional und filtert Mindestlevel fuer diesen Adapter.
- `categories` ist optional und erlaubt nur benannte Kategorien.
- Adapterfehler werden mit `pcall` isoliert.
- Fehlerhafte Adapter duerfen den Core nicht zerstoeren.
- Der Konsolenadapter kann nicht entfernt werden.

## Kategorien

Empfohlene Kategorien:

- `lifecycle`
- `database`
- `players`
- `characters`
- `permissions`
- `callbacks`
- `events`
- `exports`
- `audit`
- `security`
- `logger`

Kategorien sollen fachlich stabil sein und nicht dynamisch aus Nutzerinput entstehen.
