# [nexa-factions]

Resource-Gruppe fuer offizielle Fraktionen.

Nach ADR-004 sind dauerhaft nur LSPD, EMS, Government und Weazel News als offizielle Fraktionen vorgesehen. Government ist ausschliesslich fuer Administratoren vorgesehen.

Phase 8A fuegt mit `nexa_factions_core` nur gemeinsame Kernlogik hinzu:

- Fraktionsdefinitionen
- Fraktionsraenge
- Mitgliedschaften
- Callsigns
- Duty-System
- Fraktions-Permissions
- Fraktionskonten ueber `nexa_api.account`

Nicht enthalten sind fachspezifische Polizei-, EMS-, Government- oder Weazel-Features.

Phase 8B fuegt mit `nexa_lspd` ausschliesslich eine duenne LSPD-Fachanbindung hinzu:

- Duty und Callsigns ueber `nexa_api.faction`
- Dispatch-Lesezugriff ueber `nexa_api.dispatch`
- Basis-Aktenzugriff nur ueber vorhandenes `nexa_mdt`

Nicht enthalten sind Jail, Evidence-Gameplay, Bodycam/Dashcam, komplexe Strafverfolgung oder neue MDT-Grossfeatures.

Phase 8C fuegt mit `nexa_ems` ausschliesslich eine duenne EMS-Fachanbindung hinzu:

- Duty und Callsigns ueber `nexa_api.faction`
- EMS-Raenge und Berechtigungen ueber den Faction Core
- einfache Patientenakten und Behandlungen ueber `nexa_api.ems`
- medizinische Rechnungen nur ueber `nexa_api.account`

Nicht enthalten sind komplexe Krankenhaus-Systeme, Revive-/Death-Systeme, Medikamente als Itemsystem, Fahrzeuge, Polizei-Gameplay, Government oder Weazel.

Phase 8D fuegt mit `nexa_government` ausschliesslich eine duenne Government-Verwaltungsanbindung hinzu:

- Duty und Callsigns ueber `nexa_api.faction`
- Government-Raenge und Verwaltungs-Permissions ueber den Faction Core
- einfache Dokumentverwaltung nur ueber vorhandene `nexa_documents`/`nexa_api.document` APIs
- einfache Lizenzverwaltung nur ueber vorhandene `nexa_licenses`/`nexa_api.license` APIs
- Gebuehren und Rechnungen nur ueber `nexa_api.account`

Nicht enthalten sind komplexe Gesetzessysteme, Steuersysteme, Gerichtssysteme, Wahlen, Polizei-/EMS-Gameplay oder Weazel.

Phase 8E fuegt mit `nexa_weazel` ausschliesslich eine duenne Weazel-Presseanbindung hinzu:

- Duty und Callsigns ueber `nexa_api.faction`
- Weazel-Raenge und Reporter-Permissions ueber den Faction Core
- Presseausweise nur ueber vorhandene `nexa_documents`/`nexa_api.document` APIs
- einfache News-/Ankuendigungsbasis servervalidiert, auditierbar und ohne Persistenz

Nicht enthalten sind Kamera-Systeme, Livestream-Systeme, komplexe Social-Media-Systeme, Fahrzeuge, Government, Polizei- oder EMS-Gameplay.
