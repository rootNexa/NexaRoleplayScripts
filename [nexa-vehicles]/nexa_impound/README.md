# nexa_impound

Verwahrung/Impound fuer Fahrzeuge.

## Zweck

- Fahrzeug verwahren
- Fahrzeug freigeben
- Impound-Status lesen
- Gebuehren serverseitig pruefen
- Besitz-/Zugriffspruefung ueber `nexa_api.vehicle`
- Behoerden-/Admin-Zugriff als vorbereitete Permission-Grundlage
- Zahlung ausschliesslich ueber `nexa_api.account`
- `vehicle_history`
- Audit/Logging
- Rate-Limits
- minimale ox_lib-Interaktionen

## Abhaengigkeiten

- `ox_lib`
- `nexa_api`
- `nexa_security`
- `nexa_permissions`
- `nexa_audit`
- `nexa_logs`

## Callbacks

- `nexa:impound:cb:getStatus`
- `nexa:impound:cb:impoundVehicle`
- `nexa:impound:cb:releaseVehicle`

## Regeln

Der Client entscheidet nie final ueber den Impound-Status. Verwahren und Freigeben werden in `nexa_api.vehicle` serverseitig validiert. Freigaben mit Gebuehr laufen atomar ueber `nexa_api.account`, damit es keine Zahlung ohne Statusaenderung und keine Freigabe ohne Zahlung gibt.

## Tabellen

- `vehicles`
- `vehicle_garage_states`
- `vehicle_fines`
- `vehicle_history`
- `accounts`
- `bank_transactions`
- `economy_ledger`
- `audit_events`

## Permissions

- `impound.status`
- `impound.create`
- `impound.release`
- `impound.manage`
- `impound.audit`
- `admin.impound`

## Testhinweise

Phase-6E-Grenzen werden ueber `tools/windows/Test-Phase6EImpound.ps1` geprueft.
