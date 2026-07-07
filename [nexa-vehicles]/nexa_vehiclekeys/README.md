# nexa_vehiclekeys

## Zweck

`nexa_vehiclekeys` kapselt Fahrzeugschluessel-Interaktionen fuer Spieler und ruft fuer alle kritischen Entscheidungen `nexa_api.vehicle` auf.

## Umfang Phase 6B

- Schluessel pruefen
- Schluessel vergeben
- temporaere Schluessel mit Ablauf
- Schluessel entziehen
- Lock/Unlock-Grundlogik
- serverseitige Besitz- und Zugriffspruefung
- Rate-Limits
- Audit/Logging

## Nicht enthalten

- Fahrzeughaendler
- Kraftstoff
- Impound
- Polizei-/EMS-Fahrzeuge
- Hotwire
- Diebstahl-/Crime-Systeme
- grosse UI-Systeme

## Abhaengigkeiten

- `ox_lib`
- `nexa_api`
- `nexa_security`
- `nexa_audit`
- `nexa_logs`

## Callbacks

- `nexa:vehiclekeys:cb:hasKey`
- `nexa:vehiclekeys:cb:grantKey`
- `nexa:vehiclekeys:cb:grantTemporaryKey`
- `nexa:vehiclekeys:cb:revokeKey`
- `nexa:vehiclekeys:cb:toggleLock`

## Datenbank

Die Resource nutzt keine direkten Datenbankzugriffe. Persistenz liegt in `nexa_api.vehicle` ueber:

- `vehicle_keys`
- `vehicle_history`
- `vehicles.metadata` fuer den Schlossstatus

Temporaere Schluessel werden mit `expires_at` gespeichert und beim Start sowie bei Schluesselpruefungen serverseitig bereinigt.

## Sicherheitsgrenzen

- Der Client entscheidet niemals ueber Schluesselbesitz.
- Lock/Unlock wird immer serverseitig ueber `vehicle.toggleLock` validiert.
- Es gibt keine Client-DB-Zugriffe.
- Es gibt keine Fahrzeugdupes, keine Spawnlogik und keine Haendler-/Fuel-/Impound-Logik.
