# Organization Data Model

Kapitel 09 fuehrt append-only Migration `090_organizations_foundation` ein.

Tabellen:

- `nexa_organizations`
- `nexa_organization_ranks`
- `nexa_organization_members`
- `nexa_organization_invitations`
- `nexa_job_duty_sessions`
- `nexa_organization_audit`
- `nexa_organization_modules`
- `nexa_organization_storages`
- `nexa_organization_garages`

Wichtige Constraints:

- eindeutiger Organisationsname
- nur eine aktive Membership pro Character
- eindeutige Rank-Position pro Organisation
- mindestens 5 und maximal 15 Ranks bei Aktivierung
- genau ein Owner-Rank
- keine doppelte aktive Einladung
- optimistische Versionierung
