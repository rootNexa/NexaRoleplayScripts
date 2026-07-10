# Vehicles Current State

Vor Großprompt 11 existieren mehrere Legacy-Fahrzeugresources (`nexa_fuel`, `nexa_garage`, `nexa_impound`, `nexa_vehicledealer`, `nexa_vehiclekeys`) im Fahrzeugbereich. Diese sind als Migrationsquellen zu behandeln, nicht als Zielarchitektur.

Bekannte Risiken: feste Legacy-Abhaengigkeiten, moegliche direkte Entity-/Net-ID-Vertrauensannahmen, alte Garage-/Impound-Zustaende, dezentrale Plate-/Owner-Logik und unsichere Clientpayloads.

Neue Ziel-Domains: `nexa_vehicles`, `nexa_vehiclekeys`, `nexa_garages`, `nexa_impound`.
