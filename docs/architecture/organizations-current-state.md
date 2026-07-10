# Organizations Current State

Vor Kapitel 09 existiert `nexa_jobscreator` als Foundation fuer erstellbare Organisationen. Die Resource besitzt bereits Tabellen fuer Organisationen, Grades, Members und Module, nutzt aber noch `oxmysql` direkt und bildet Duty, Hierarchie, Einladungen, Owner-Rang-Schutz, Organisationspermissions und Jobs-Lifecycle nicht vollstaendig ab.

Feste Fraktionsresources wie LSPD, EMS, Government und Weazel sind im Arbeitsbaum bereits geloescht, werden aber in diesem Kapitel nicht veraendert, gestaged oder committed.

## Gefundene Quellen

- `nexa_jobscreator`: Organisationen, Grades, Members, Modules, einfache Duty-Flags.
- `nexa_jobs_core`: Legacy-Jobkern mit Framework-Migrationsbedarf.
- Faction-Ressourcen: als Zielarchitektur ersetzt durch generische Organisationen.
- `nexa_mdt`: generisches MDT vorbereitet, police-spezifische Funktionen nur noch als Modulidee.
- `nexa_economy`: neue Konto- und Ledger-Foundation fuer Organisationskonten.
- `nexa_inventory`: kuenftige Grundlage fuer Organisationslager.

## Probleme

- Doppelte Datenmodelle fuer Organisation, Grade und Member sind moeglich.
- Legacy-Ressourcen enthalten noch alte Jobbegriffe, feste Fraktionsannahmen und direkte Integrationen.
- Duty ist bislang nicht als eigene serverautoritative Session modelliert.
- Clientpayloads duerfen in der neuen Architektur keine Organisation, Rang, Character oder Duty autoritativ bestimmen.

## Entscheidung

`nexa_organizations` wird neue autoritative Domain fuer Organisationen, Ranks, Memberships, Module, Storage/Garage-Registrierung und Organisationsaudit. `nexa_jobs` wird neue autoritative Runtime-Domain fuer aktive Jobzuordnung und Duty.
