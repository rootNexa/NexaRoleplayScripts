# nexa_fuel

Kraftstoffsystem fuer Phase 6D.

## Zweck

- Tankstellen-Konfiguration
- Tankstand lesen und schreiben ueber `nexa_api.vehicle`
- Bezahltes Tanken ausschliesslich ueber `nexa_api.account`
- Verbrauchslogik als servervalidierte Grundlage
- serverseitige Tankstellen-Distanzpruefung
- keine Tick-Writes in die Datenbank
- Audit/Logging und Rate-Limits

## Abhaengigkeiten

- `ox_lib`
- `nexa_api`
- `nexa_security`
- `nexa_audit`
- `nexa_logs`

## Callbacks

- `nexa:fuel:cb:getStations`
- `nexa:fuel:cb:getFuel`
- `nexa:fuel:cb:purchaseFuel`
- `nexa:fuel:cb:reportConsumption`

## API-Nutzung

- `vehicle.getFuel`
- `vehicle.purchaseFuel`
- `vehicle.consumeFuel`
- interner Zahlungsrahmen `account.fuelPurchase`

Der Client sendet nur Anfragewerte wie Fahrzeug-ID, Tankstelle, Literwunsch und Konto-Referenz. Preis, Zahlung, Entfernung zur Tankstelle, finaler Tankstand und Persistenz entscheidet der Server.

## Datenbank

- `vehicles.fuel_level`
- `vehicle_history`
- `economy_ledger`
- `bank_transactions`

## Grenzen

Nicht enthalten sind Impound, Fahrzeughaendler, Polizei-/EMS-Fahrzeuge, Tuning, illegale Systeme und grosse UI-Systeme.
