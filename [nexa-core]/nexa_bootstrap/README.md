# nexa_bootstrap

`nexa_bootstrap` validiert in Phase 1 den Serverstart und die Basisabhaengigkeiten.

## Zweck

- Environment pruefen
- Qbox-/Ox-Abhaengigkeiten pruefen
- Production-Regeln erzwingen
- Startstatus bereitstellen

## Abhaengigkeiten

- `ox_lib`
- `oxmysql`
- `qbx_core`
- `nexa_config`
- `nexa_logs`

## Exports

- `getStatus`

## Events

Keine oeffentlichen Client- oder Serverevents.

## Datenbanktabellen

Keine Datenbankzugriffe in Phase 2. `schema_migrations` und `server_config_snapshots` werden ab Phase 3 angebunden.

## Permissions

Keine fachlichen Permissions in Phase 1.

## Config-Werte

- `nexa:environment`
- `nexa:debug`
- `validationDelayMs`
- `failOnMissingDependency`

## Testhinweise

`tools/windows/Validate-Repository.ps1` prueft Struktur und Startreihenfolge. Der Runtime-Dependency-Check laeuft beim Start der Resource.
