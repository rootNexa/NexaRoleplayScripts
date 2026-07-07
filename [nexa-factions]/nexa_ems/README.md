# nexa_ems

Phase-8C-Resource fuer die EMS-Fachanbindung auf Basis des gemeinsamen Fraktions-Cores.

## Umfang

- EMS-Duty ueber `nexa_api.faction`
- EMS-Raenge und Mitgliedschaften ueber bestehende Fraktionsdaten
- Callsigns ueber `nexa_api.faction`
- einfache Patientenakten ueber `nexa_api.ems` und `ems_records`
- einfache Behandlungen ueber `nexa_api.ems` und `medical_treatments`
- einfache medizinische Rechnungen ueber `nexa_api.account`
- serverseitige EMS-Permissions
- Audit/Logging
- Rate-Limits
- Featureflag
- minimale `ox_lib`-Interaktionen

## Grenzen

- EMS nutzt ausschliesslich den vorhandenen Faction Core.
- Nur EMS wird in Phase 8C neu implementiert.
- Kein komplexes Krankenhaus-System.
- Kein echtes Revive- oder Death-System.
- Keine Medikamente als Itemsystem.
- Keine Fahrzeug-Sonderlogik.
- Kein Polizei-Gameplay.
- Kein Government- oder Weazel-Gameplay.
- Keine direkten Client-DB-Zugriffe.
- Keine direkte DB-Manipulation aus `nexa_ems`.
- Keine Geldaenderungen ausserhalb von `nexa_api.account`.
- Keine Itemlogik ausserhalb von `ox_inventory`.
- Client entscheidet Behandlung, Rechnung, Rechte und Duty niemals final.
