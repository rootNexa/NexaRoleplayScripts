# [nexa-vehicles]

Resource-Gruppe fuer Fahrzeugfunktionen.

## Phase 6A

Umgesetzt ist:

- `nexa_garage`
- Garagenliste
- Fahrzeug einparken
- Fahrzeug ausparken
- Besitz- und Statuspruefung serverseitig ueber `nexa_api`
- Dupe-Schutz ueber serverseitige Locks und atomare Statuswechsel
- Restart-Sicherheit ueber `vehicle_garage_states` und Start-Abgleich
- Rate-Limits
- Audit/Logging

Weiterhin ausgeschlossen:

- Fahrzeughaendler
- Kraftstoff
- Impound
- Polizei-/EMS-Fahrzeuge
- Housing
- illegale Systeme
- grosse UI-Systeme

## Phase 6B

Umgesetzt ist:

- `nexa_vehiclekeys`
- Schluessel pruefen
- Schluessel vergeben
- temporaere Schluessel mit Ablauf und Cleanup
- Schluessel entziehen
- Lock/Unlock-Grundlogik
- serverseitige Besitz- und Zugriffspruefung ueber `nexa_api.vehicle`
- Rate-Limits
- Audit/Logging

Weiterhin ausgeschlossen:

- Fahrzeughaendler
- Kraftstoff
- Impound
- Polizei-/EMS-Fahrzeuge
- Hotwire
- Diebstahl-/Crime-Systeme
- grosse UI-Systeme

## Phase 6C

Umgesetzt ist:

- `nexa_vehicledealer`
- Fahrzeugkatalog
- Fahrzeugkauf
- Fahrzeugverkauf als nicht-mutierende Vorbereitung
- Uebergabe an Garage
- automatische Schluesselvergabe ueber `nexa_api.vehicle`
- Zahlung ausschliesslich ueber `nexa_api.account`
- `vehicle_history`
- Audit/Logging
- Rate-Limits
- serverseitige Validierung
- API-Contracts in `nexa_api`
- Seeds fuer Haendlerdaten, Permissions und Featureflags
- minimale ox_lib-Interaktionen

Weiterhin ausgeschlossen:

- Kraftstoff
- Impound
- Polizei-/EMS-Fahrzeuge
- Tuning
- Leasing/Finanzierung
- illegale Fahrzeugkaeufe
- grosse UI-Systeme

## Phase 6D

Umgesetzt ist:

- `nexa_fuel`
- Tankstellen-Konfiguration
- Tankstand lesen/schreiben ueber `nexa_api.vehicle`
- Verbrauchslogik als vorbereitete/servervalidierte Grundlage
- serverseitige Tankstellen-Distanzpruefung
- Bezahlung ausschliesslich ueber `nexa_api.account`
- `vehicle_history`
- Audit/Logging
- Rate-Limits
- API-Contracts in `nexa_api`
- Seeds fuer Featureflags, Permissions und Fuel-Konfiguration
- minimale ox_lib-Interaktionen

Weiterhin ausgeschlossen:

- Impound
- Polizei-/EMS-Fahrzeuge
- Tuning
- illegale Systeme
- grosse UI-Systeme

## Phase 6E

Umgesetzt ist:

- `nexa_impound`
- Fahrzeug verwahren
- Fahrzeug freigeben
- Impound-Status
- Gebuehren ueber `vehicle_fines`
- Besitz-/Zugriffspruefung serverseitig ueber `nexa_api.vehicle`
- Behoerden-/Admin-Zugriff als vorbereitete Permission-Grundlage
- Zahlung ausschliesslich ueber `nexa_api.account`
- `vehicle_history`
- Audit/Logging
- Rate-Limits
- API-Contracts in `nexa_api`
- Seeds fuer Featureflags/Permissions
- minimale ox_lib-Interaktionen

Weiterhin ausgeschlossen:

- Polizei-Gameplay
- EMS-Gameplay
- Abschleppjob
- Fahrzeughaendler-Aenderungen
- Kraftstoff-Aenderungen
- Tuning
- illegale Systeme
- grosse UI-Systeme
