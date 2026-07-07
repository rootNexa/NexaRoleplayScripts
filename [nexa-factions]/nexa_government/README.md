# nexa_government

Phase 8D Government ist eine duenne Verwaltungsresource fuer die offizielle Government-Fraktion.

- Government nutzt ausschliesslich den vorhandenen Faction Core fuer Duty, Raenge, Mitgliedschaften, Callsigns und Faction-Permissions.
- Dokumente laufen nur ueber die bestehenden `nexa_documents`/`nexa_api.document` APIs.
- Lizenzen laufen nur ueber die bestehenden `nexa_licenses`/`nexa_api.license` APIs.
- Gebuehren und Rechnungen laufen nur ueber `nexa_api.account`.
- Government schreibt Audit-/Log-Eintraege fuer administrative Aktionen.
- Der Client zeigt nur minimale `ox_lib`-Interaktionen an und entscheidet keine Rechte oder Verwaltungsaktionen final.

Nicht enthalten sind komplexe Gesetzessysteme, Steuern, Gerichte, Wahlen, Polizei-/EMS-Gameplay und Weazel-Features.

`nexa_government` enthaelt keine direkten Datenbankwrites und keine eigenen Geldwrites.
