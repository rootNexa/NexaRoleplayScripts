# nexa_devtools

Development-only Diagnosewerkzeuge fuer Nexa Roleplay.

Phase 11F umfasst:

- harte Production-Sperre
- Environment-Pruefung ueber `nexa_config` und `nexa:environment`
- keine Registrierung von Commands in Production
- sichere Dev-only Diagnosecommands
- Audit und Logging fuer Start, Blockaden und Diagnosezugriffe

Erlaubte Dev-Commands:

- `nexa_devtools_status`
- `nexa_devtools_ping`
- `nexa_devtools_contracts`

Nicht enthalten:

- Anticheat
- Live-Admin-Abuse-Tools
- Echtgeld-, Item- oder Money-Testcommands
- Ban-, Kick-, Teleport-, Heal-, Revive- oder Godmode-Commands

`nexa_devtools` darf in Production niemals gestartet werden und bleibt in `server.cfg` auskommentiert.
