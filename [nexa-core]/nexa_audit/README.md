# nexa_audit

Audit-Grundlage fuer kritische Ereignisse.

## Zweck

- Audit-Eintraege normalisieren
- Admin- und Security-Ereignisse vorbereiten
- Audit-IDs fuer spaetere Persistenz erzeugen

## Abhaengigkeiten

- `ox_lib`
- `oxmysql`
- `nexa_config`

## Exports

- `write(entry)`
- `writeAdmin(entry)`
- `writeSecurity(entry)`
- `linkLedger(entry)`
- `recent(limit)`

## Events

- `nexa:audit:internal:write`

## Callbacks

Keine.

## Datenbanktabellen

Keine Datenbankschreibvorgaenge in Phase 2. `audit_events`, `admin_logs`, `security_events`, `economy_ledger`, `item_ledger` und `vehicle_history` werden ab Phase 3 per Migration angebunden.

## Permissions

Keine direkten Permission-Entscheidungen.

## Config-Werte

- `bufferLimit`
- `severities`

## Testhinweise

Ungueltige Audit-Eintraege werden abgelehnt und technisch geloggt.
