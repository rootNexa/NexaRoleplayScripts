# nexa_vehicledealer

Minimaler Fahrzeughaendler fuer Phase 6C.

## Umgesetzt

- Fahrzeugkatalog aus serverseitiger Resource-Config
- Fahrzeugkauf ueber `nexa_api.vehicle.purchaseDealer`
- Zahlung ausschliesslich ueber den internen `nexa_api.account`-Kaufrahmen
- atomare Anlage von `vehicles`, `vehicle_garage_states`, Owner-Key in `vehicle_keys`, `vehicle_history` und Ledger
- Uebergabe an Garage mit Status `stored`
- automatische Schluesselvergabe als Owner-Key
- serverseitige Preis-, Katalog-, Account- und Besitzvalidierung
- Rate-Limits ueber `nexa_security`
- Audit/Logging ueber `nexa_audit` und `nexa_logs`
- Fahrzeugverkauf nur als nicht-mutierende Vorbereitung
- minimale ox_lib-Callbacks und Benachrichtigungen

## Grenzen

- Der Client sendet nie Preis, Modell oder Garage fuer den Kauf.
- Parallele Kaufrequests werden pro Source, Haendler und Katalogeintrag kurz gelockt.
- Fahrzeug, Garage-State, Owner-Key, History und Zahlung entstehen in einer Datenbanktransaktion.
- Fehler im Fahrzeugteil rollen die Zahlung zurueck.

## Ausgeschlossen

- Kraftstoff
- Impound
- Polizei-/EMS-Fahrzeuge
- Tuning
- Leasing oder Finanzierung
- illegale Fahrzeugkaeufe
- grosse UI-Systeme
