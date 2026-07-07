# nexa_lspd

Phase-8B-Resource fuer die LSPD-Fachanbindung auf Basis des gemeinsamen Fraktions-Cores.

## Umfang

- LSPD-Duty ueber `nexa_api.faction`
- LSPD-Raenge und Mitgliedschaften ueber bestehende Fraktionsdaten
- Callsigns ueber `nexa_api.faction`
- einfache Dienstverwaltung fuer den eigenen Dienststatus
- Dispatch-Lesezugriff ueber die bestehende Dispatch-API
- Basis-Aktenzugriff ueber vorhandenes `nexa_mdt`, nur wenn verfuegbar
- serverseitige LSPD-Permissions
- Audit/Logging
- Rate-Limits
- Featureflag
- minimale `ox_lib`-Interaktionen

## Grenzen

- LSPD nutzt ausschliesslich den vorhandenen Faction Core.
- Nur LSPD wird hier implementiert.
- Keine BCSO-, SAHP- oder FIB-Unterstuetzung.
- Kein Jail-System.
- Kein Evidence-Gameplay.
- Keine Bodycam- oder Dashcam-Logik.
- Keine komplexe Strafverfolgung.
- Keine neuen MDT-Grossfeatures.
- Keine Fahrzeug-Sonderlogik.
- Keine direkten Client-DB-Zugriffe.
- Keine direkte DB-Manipulation aus `nexa_lspd`.
- Keine Geldaenderungen ausserhalb von `nexa_api.account`.
- Client entscheidet Rechte, Duty und Aktenzugriff niemals final.
