# Nexa Core Cache

Stand: 2026-07-10

`Nexa.Cache` ist eine kleine interne Key-Value-Cache-Schicht fuer haeufig benoetigte Frameworkdaten. Sie ist keine Persistenz, kein ORM und keine zweite Datenbank.

## Geeignete Cache-Daten

Geeignet sind Daten, die:

- serverseitig berechnet oder aus der Datenbank gelesen wurden,
- klar invalidiert werden koennen,
- keine Secrets enthalten,
- keine FiveM-Handles oder Clientobjekte enthalten,
- kurzfristig wiederverwendet werden,
- bei Verlust erneut geladen werden koennen.

Beispiele:

- Permission-Entscheidungen oder aufgeloeste Rollen, sofern separat invalidiert.
- Public Player Snapshots.
- Konfigurationsauszuege ohne Secrets.
- Lookup-Ergebnisse fuer stabile Stammdaten.

## Ungeeignete Cache-Daten

Nicht in den Cache gehoeren:

- Passwoerter, Tokens, Secrets, API-Keys.
- Vollstaendige IP-Adressen.
- Clientobjekte, Entity-Handles, Ped-/Vehicle-Handles.
- Gameplay-State, der autoritativ persistiert werden muss.
- Geld, Inventar, Itembewegungen, Shop-Kaeufe.
- Daten, deren Gueltigkeit nicht beschrieben werden kann.

`Cache.Set(..., { secret = true })` wird bewusst blockiert.

## API

- `Cache.Set(namespace, key, value, options)`
- `Cache.Get(namespace, key)`
- `Cache.Has(namespace, key)`
- `Cache.Delete(namespace, key)`
- `Cache.Clear(namespace)`
- `Cache.GetOrLoad(namespace, key, loader, options)`
- `Cache.GetStats(namespace)`
- `Cache.Cleanup()`

Namespaces trennen Domains. Beispiele:

- `permissions`
- `sessions`
- `config.public`
- `items.definitions`

## TTL-Regeln

`ttlMs` ist optional.

- Ohne `ttlMs` laeuft ein Eintrag nicht automatisch ab.
- Mit `ttlMs` wird ein Ablaufzeitpunkt gesetzt.
- Abgelaufene Eintraege werden bei `Get` entfernt.
- `Cleanup()` entfernt abgelaufene Eintraege gesammelt.

TTL ersetzt keine fachliche Invalidierung. Wenn Daten durch eine Schreiboperation ungueltig werden, muss die verantwortliche Resource explizit invalidieren.

## Invalidierung

- `Cache.Delete(namespace, key)` entfernt einen Eintrag.
- `Cache.Clear(namespace)` leert einen Namespace.
- `Cache.Clear()` leert alle Namespaces.

Runtime-Updates sollen die betroffenen Keys sofort invalidieren. Der Cache darf nicht als versteckte Quelle fuer veraltete Autorisierung oder Gameplay-Werte dienen.

## Limits

Jeder Namespace besitzt:

- maximale Eintragszahl,
- optionale Groessenbegrenzung pro Wert,
- Statistiken fuer Hits, Misses, Sets, Deletes, Clears, Evictions, Expirations, Loads und Loader-Fehler.

Wenn ein Namespace zu viele Eintraege enthaelt, werden die aeltesten Eintraege entfernt.

## Get-or-Load und Stampede-Schutz

`GetOrLoad(namespace, key, loader, options)` prueft zuerst den Cache. Bei Miss ruft es den Loader auf und speichert nur erfolgreiche Werte.

Wenn eine Runtime Promises unterstuetzt, warten parallele Requests fuer denselben Key auf denselben Loader. Loader-Fehler werden nicht gecached.

## Mutationsschutz

Werte werden beim Schreiben und Lesen geklont. Dadurch koennen Aufrufer keine internen Cachewerte versehentlich veraendern. Nicht serialisierbare Typen wie Funktionen, Threads oder Userdata werden blockiert.

## Lifecycle

Der Core startet die automatische Bereinigung ueber den Bootstrap und stoppt sie kontrolliert beim Core-Stop. Der Cache persistiert standardmaessig nichts ueber Resource-Restarts hinweg.
