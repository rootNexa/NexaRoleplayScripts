# Organizations Architecture

`nexa_organizations` ist die serverautoritative Domain fuer Jobs, Fraktionen, Gangs, Unternehmen und staatliche Organisationen. Die Resource ersetzt feste Fraktionsressourcen langfristig durch konfigurierbare Organisationen.

## Verantwortlichkeiten

- Organisationstypen registrieren.
- Organisationen erstellen, aktivieren, suspendieren, archivieren und soft-loeschen.
- Ranks mit Hierarchie und Permissions verwalten.
- Memberships und Invitations verwalten.
- Organisationskonto ueber `nexa_economy` referenzieren.
- Storage- und Garage-Definitionen ueber `nexa_inventory` bzw. spaetere Vehicle-Domain vorbereiten.
- Module registrieren und organisationsbezogen aktivieren.
- Creator-Domain ohne NUI bereitstellen.
- Audit schreiben.

## Ausgeschlossen

Duty-Runtime, Source-State und Disconnect-Cleanup gehoeren zu `nexa_jobs`. UI, MDT, Dispatch, Payroll, Armory-Logik und Fahrzeugspawns sind spaetere Module.
