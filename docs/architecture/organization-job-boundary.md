# Organization Job Boundary

`nexa_organizations` beschreibt die Fachstruktur. `nexa_jobs` beschreibt den aktiven Runtime-Zustand eines Spielers.

## Organizations

- Organisationstypen.
- Organisationen und Status.
- Ranks und Rangpermissions.
- Memberships und Invitations.
- Module, Economy-Konto, Storage- und Garage-Registrierung.
- Organisationsaudit.

## Jobs

- Source- und Character-gebundener Job-State.
- Duty-Session.
- Runtime-Events.
- Disconnect- und Stop-Cleanup.

## Abhaengigkeiten

`nexa_jobs` darf `nexa_organizations` lesen. `nexa_organizations` darf nicht von `nexa_jobs` abhaengen. Core, Characters und Economy duerfen keine Reverse-Dependency auf Jobs oder Organizations erhalten.
