# Core Operations Guide

Stand: 2026-07-10

Dieses Dokument beschreibt den Betrieb von Kapitel 01 `nexa-core`.

## Minimalbetrieb

Serverstart:

```cfg
ensure oxmysql
ensure nexa-core
```

`oxmysql` ist Pflichtabhaengigkeit. Der Core darf ohne `oxmysql` nicht produktiv bereit melden.

## Start

Beim Start:

1. Shared Constants, Config und Init werden geladen.
2. Servermodule werden in Manifest-Reihenfolge geladen.
3. Bootstrap prueft Konfiguration und Pflichtdependencies.
4. Datenbank-Health wird geprueft.
5. Migrationen laufen.
6. Interne Module werden initialisiert und gestartet.
7. Cache-Cleanup startet.
8. Core wechselt zu `ready`.

## Stop

Beim Stop:

1. Core wechselt zu `stopping`.
2. Sessions werden geschlossen.
3. Player- und Character-Caches werden geleert.
4. Module werden in umgekehrter Reihenfolge gestoppt.
5. Cache-Cleanup wird gestoppt.
6. Core wechselt zu `stopped`.

## Restart

Ein Restart muss denselben Pfad wie Stop plus Start laufen. Erwartet wird:

- keine doppelten Sessions,
- keine doppelten Cache-Cleanup-Threads,
- keine offenen Callback-Pendings alter Spieler,
- keine doppelt angewendeten Migrationen,
- keine mehrfach registrierten Module.

## Monitoring

Serverkonsole:

```text
nexa_core_status
```

Die Ausgabe enthaelt:

- Bootstrap-Status
- Lifecycle-State
- Ready-Flag
- Startzeitpunkt
- Failure-Reason
- Player Count
- Session Count

## Logs

Alle Core-Logs sollen ueber `Nexa.Logger` oder `Nexa.Log` laufen. Der Console-Adapter schreibt strukturierte Eintraege. Sensitive Daten werden maskiert.

## Datenbank

Migrationen werden in `nexa_core_migrations` verfolgt. Migrationen duerfen nach Anwendung nicht veraendert werden, ohne bewusst eine neue Migration zu erstellen.

## Security-Grenzen

- Clientdaten sind nie autoritativ.
- `source` wird serverseitig auf Sessions und Accounts gemappt.
- Permissions werden serverseitig geprueft.
- Deny gewinnt gegen Allow.
- Callbacknamen muessen dem Nexa-Namespace folgen.
- Netzwerkcallbacks muessen explizit registriert sein.

## Performance-Regeln

- Keine dauerhaften 0-ms-Loops.
- Keine unkontrollierten Timer.
- Cache-Namespaces brauchen Limits.
- Datenbankzugriffe muessen parametrisiert sein.
- EventBus-Listener muessen entfernt werden koennen.
- Pending Callback Requests muessen bei Timeout oder Disconnect entfernt werden.
