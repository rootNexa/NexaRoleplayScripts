# nexa_featureflags

Feature-Schalter fuer kontrollierte Aktivierung.

## Zweck

- Core-Featureflags bereitstellen
- Runtime-Aenderungen im laufenden Serverprozess erlauben
- spaetere DB-Persistenz vorbereiten

## Abhaengigkeiten

- `ox_lib`
- `oxmysql`
- `nexa_config`

## Exports

- `isEnabled(flagName)`
- `set(flagName, enabled)`
- `reload()`
- `list()`

## Events und Callbacks

Keine oeffentlichen Events oder Callbacks.

## Datenbanktabellen

Keine Datenbankschreibvorgaenge in Phase 2. `feature_flags` wird ab Phase 3 angebunden.

## Permissions

Keine direkte Permission-Pruefung in Phase 2.

## Config-Werte

- `defaults`
- `allowRuntimeChanges`

## Testhinweise

Runtime-Aenderungen gelten bis zum Resource-Restart.
