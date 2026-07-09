# nexa_factions_core

Phase-8A-Resource fuer gemeinsame Kernlogik offizieller Fraktionen.

## Umfang

- offizielle Fraktionsdefinitionen ueber bestehende Seeds
- Fraktionsraenge
- Fraktionsmitgliedschaften
- Callsigns
- Fraktionsdienst ueber `duty_sessions`
- serverseitige Fraktions-Permissions
- Fraktionskonten ueber `nexa_api.account`
- Audit/Logging
- Rate-Limits
- Featureflag
- minimale NexaUI-Interaktionen

## Grenzen

- Nur LSPD, EMS, Government und Weazel sind offizielle Fraktionen.
- Government ist ausschliesslich fuer Administration vorgesehen.
- Keine LSPD-spezifischen Polizeifunktionen.
- Keine EMS-spezifische Medizinlogik.
- Keine Government-Verwaltungslogik.
- Keine Weazel-News-Funktionen.
- Keine Crime-Systeme.
- Kein grosses UI-System.
- Keine direkten Client-DB-Zugriffe.
- Keine Geldaenderungen ausserhalb von `nexa_api.account`.
