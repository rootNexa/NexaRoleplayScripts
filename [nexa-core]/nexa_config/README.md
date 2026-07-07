# nexa_config

Zentrale Projektkonfiguration fuer Nexa Roleplay.

## Zweck

- Environment zentral auslesen
- sichere Public-Config fuer Clients bereitstellen
- Production-Regeln fuer Debug und geschuetzte Resources definieren

## Abhaengigkeiten

- `ox_lib`

## Exports

- `get(key, fallback)`
- `getEnvironment()`
- `isProduction()`
- `isDebugEnabled()`
- `getPublicConfig()`

## Events und Callbacks

Keine oeffentlichen Events oder Callbacks.

## Datenbanktabellen

Keine Datenbankzugriffe in Phase 2. `resource_settings` und `feature_flags` werden ab Phase 3 angebunden.

## Permissions

Keine fachlichen Permissions.

## Config-Werte

- `nexa:environment`
- `nexa:debug`
- `nexa:locale`

## Testhinweise

Die Resource startet nur mit gueltiger Umgebung. Production blockiert aktivierten Debugmodus.
