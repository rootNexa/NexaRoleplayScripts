# nexa_weazel

Phase 8E Weazel ist eine duenne Presse-Resource fuer die offizielle Weazel-News-Fraktion.

- Weazel nutzt ausschliesslich den vorhandenen Faction Core fuer Duty, Raenge, Mitgliedschaften, Callsigns und Faction-Permissions.
- Presseausweise laufen nur ueber die bestehende `nexa_documents`/`nexa_api.document` API.
- News und Ankuendigungen sind eine einfache servervalidierte Grundlage ohne Persistenz und ohne grosses UI-System.
- Weazel schreibt Audit-/Log-Eintraege fuer Presseausweise und Ankuendigungen.
- Der Client zeigt nur minimale `ox_lib`-Interaktionen an und entscheidet keine Rechte final.

Nicht enthalten sind Kamera-Systeme, Livestream-Systeme, komplexe Social-Media-Systeme, Fahrzeuge, Government, Polizei- oder EMS-Gameplay.

`nexa_weazel` enthaelt keine direkten Datenbankwrites.
