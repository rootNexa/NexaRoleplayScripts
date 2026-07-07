# nexa_security

Eventschutz und Missbrauchserkennung.

## Zweck

- Source-Validierung
- Rate-Limit-Grundlage
- Security-Reports erzeugen
- Security-Ereignisse an Audit und Logs weitergeben

## Abhaengigkeiten

- `ox_lib`
- `nexa_config`
- `nexa_logs`
- `nexa_audit`

## Exports

- `validateSource(source)`
- `checkRateLimit(source, eventName)`
- `reject(source, eventName, reason, severity)`
- `report(entry)`
- `isBanned(source)`
- `recent(limit)`

## Events

- `nexa:security:internal:rateLimitExceeded`
- `nexa:security:internal:securityRejected`

## Callbacks

Keine.

## Datenbanktabellen

Keine Datenbankschreibvorgaenge in Phase 2. `security_events`, `rate_limit_events`, `bans` und `warns` werden ab Phase 3 angebunden.

## Permissions

Keine direkten Permission-Entscheidungen.

## Config-Werte

- `defaultLimit`
- `limits`
- `maxBuckets`
- `severities`

## Testhinweise

Rate-Limits arbeiten pro Source und Eventname im laufenden Serverprozess.
