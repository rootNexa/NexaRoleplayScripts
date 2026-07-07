# nexa_garage

Phase-6A-Resource fuer Garagen von eigenen Charakterfahrzeugen.

## Umfang

- Garagenliste
- Fahrzeug einparken
- Fahrzeug ausparken
- Besitzpruefung ueber `nexa_api`
- Statuspruefung ueber `vehicles` und `vehicle_garage_states`
- Dupe-Schutz ueber serverseitige Locks und atomare Statuswechsel
- Restart-Sicherheit ueber persistente Garagenstatus-Tabelle und Start-Abgleich
- serverseitige Validierung
- Rate-Limits
- Audit/Logging
- minimale `ox_lib`-Interaktionen

## Grenzen

- Client entscheidet niemals Fahrzeugbesitz.
- Fahrzeugstatus wird serverseitig geprueft.
- Keine Fahrzeugschluessel-Implementierung.
- Kein Fahrzeughaendler.
- Kein Kraftstoffsystem.
- Kein Impound-System.
- Keine Polizei-/EMS-Fahrzeuge.
- Kein Housing.
- Keine illegalen Systeme.
- Kein grosses UI-System.
- Keine direkten Client-DB-Zugriffe.
