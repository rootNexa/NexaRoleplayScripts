# nexa_logs

Technisches Logging fuer Nexa Roleplay.

## Zweck

- strukturierte Resource-Logs schreiben
- Fehler- und Performance-Ereignisse einheitlich formatieren
- aktuelle Logeintraege zur Diagnose im Speicher halten

## Abhaengigkeiten

- `ox_lib`
- `nexa_config`
- `nexa_locales`

## Exports

- `info(resourceName, message, metadata)`
- `warn(resourceName, message, metadata)`
- `error(resourceName, message, metadata)`
- `performance(resourceName, message, metadata)`
- `recent(limit)`

## Events und Callbacks

Keine oeffentlichen Events oder Callbacks.

## Datenbanktabellen

Keine Datenbankzugriffe in Phase 2. Persistente Tabellen `server_logs`, `error_logs`, `resource_logs`, `performance_logs` und `webhook_logs` werden ab Phase 3 angebunden.

## Permissions

Keine fachlichen Permissions.

## Config-Werte

- `nexa:logLevel`
- `bufferLimit`

## Testhinweise

Exports koennen von anderen Core-Resources genutzt werden. Production-Debug wird ueber `nexa_config` begrenzt.
