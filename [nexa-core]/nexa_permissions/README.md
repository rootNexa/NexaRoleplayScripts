# nexa_permissions

Zentrales Rechtesystem.

## Zweck

- Permission-Namen validieren
- ACE-Rechte auswerten
- Session-Rechte fuer Core-Integration verwalten
- Rechteaenderungen auditieren

## Abhaengigkeiten

- `ox_lib`
- `oxmysql`
- `qbx_core`
- `nexa_config`
- `nexa_audit`
- `nexa_logs`

`nexa_permissions` haengt bewusst nicht von `nexa_api` ab.

## Exports

- `has(source, permission)`
- `hasAny(source, permissions)`
- `getRoles(source)`
- `assignRole(source, permission)`
- `removeRole(source, permission)`

## Events und Callbacks

Keine oeffentlichen Events oder Callbacks.

## Datenbanktabellen

Keine Datenbankschreibvorgaenge in Phase 2. `permission_roles`, `role_permissions`, `player_roles`, `character_permissions`, `faction_members`, `faction_grades`, `job_grades` und `business_members` werden ab Phase 3 angebunden.

## Permissions

ACE-Format:

```text
nexa.<domain>.<action>
```

Beispiel: `nexa.admin.kick`

## Config-Werte

- `acePrefix`
- `domains`
- `sessionAssignmentsEnabled`

## Testhinweise

Die Resource kann ohne `nexa_api` starten und verhindert damit den dokumentierten Core-Zyklus.
