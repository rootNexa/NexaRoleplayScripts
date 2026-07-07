# nexa_locales

Zentrale deutsche Sprachverwaltung.

## Zweck

- deutsche Systemtexte bereitstellen
- Fehlertexte konsistent halten
- lore-friendly Begriffe zentralisieren

## Abhaengigkeiten

- `ox_lib`
- `nexa_config`

## Exports

- `get(key, fallback)`
- `exists(key)`

## Events und Callbacks

Keine oeffentlichen Events oder Callbacks.

## Datenbanktabellen

Keine.

## Permissions

Keine.

## Config-Werte

- `defaultLocale`
- `fallbackLocale`

## Testhinweise

Core-Fehlertexte liegen unter `common.*` und koennen server- und clientseitig abgefragt werden.
