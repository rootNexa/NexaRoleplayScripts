# nexa_jobscreator

Foundation fuer ingame erstellbare Jobs, Gangs, Fraktionen und Organisationen.

## Zielarchitektur

Nexa Roleplay soll keine festen Hauptsysteme wie `nexa_lspd`, `nexa_ems`, `nexa_government` oder `nexa_weazel` benoetigen. Organisationen werden spaeter ingame erstellt und bekommen:

- `organization_type`
- `mdt_type`
- Grade/Raenge
- Mitglieder
- optionale Callsigns und Duty-Status

`nexa_mdt` kann anhand von `mdt_type` passende Module anzeigen, zum Beispiel `police`, `ems`, `government`, `gang`, `business` oder `media`.

## Enthalten

- idempotente Datenbank-Foundation fuer `organizations`
- idempotente Datenbank-Foundation fuer `organization_grades`
- idempotente Datenbank-Foundation fuer `organization_members`
- Typ-Konstanten fuer `police`, `ems`, `government`, `gang`, `business`, `media`
- minimale Status- und Schema-Exports
- serverseitige Organisations-API fuer Erstellen, Laden, Listen und Aktivieren/Deaktivieren
- serverseitige Grade- und Member-API fuer Organisationsstruktur und Duty-Status

## Nicht Enthalten

- keine UI
- keine Admin-Menues
- keine Legacy-Framework-Bridges
- keine externe UI-Bibliothek
- keine festen LSPD/EMS/Government/Weazel-Systeme
- keine Gameplay-Entscheidungen

## Tabellen

`organizations`

- `id`
- `name`
- `label`
- `organization_type`
- `mdt_type`
- `enabled`
- `created_at`
- `updated_at`

`organization_grades`

- `id`
- `organization_id`
- `name`
- `label`
- `level`
- `permissions`

`organization_members`

- `id`
- `organization_id`
- `character_id`
- `grade_id`
- `callsign`
- `is_on_duty`
- `joined_at`

## Server Exports

- `CreateOrganization(payload)`
- `GetOrganization(id)`
- `ListOrganizations(filter)`
- `SetOrganizationEnabled(id, enabled)`
- `CreateGrade(payload)`
- `ListGrades(organizationId)`
- `UpdateGrade(id, payload)`
- `DeleteGrade(id)`
- `AddMember(payload)`
- `ListMembers(organizationId)`
- `UpdateMember(id, payload)`
- `RemoveMember(id)`
- `SetDuty(memberId, isOnDuty)`

Alle API-Antworten enthalten `ok`, `success`, `code`, `message`, `data` und `meta`.

## Callbacks

Die Callbacks werden ueber `nexa_api` registriert:

- `nexa:jobscreator:cb:createOrganization`
- `nexa:jobscreator:cb:getOrganization`
- `nexa:jobscreator:cb:listOrganizations`
- `nexa:jobscreator:cb:setOrganizationEnabled`
- `nexa:jobscreator:cb:createGrade`
- `nexa:jobscreator:cb:listGrades`
- `nexa:jobscreator:cb:updateGrade`
- `nexa:jobscreator:cb:deleteGrade`
- `nexa:jobscreator:cb:addMember`
- `nexa:jobscreator:cb:listMembers`
- `nexa:jobscreator:cb:updateMember`
- `nexa:jobscreator:cb:removeMember`
- `nexa:jobscreator:cb:setDuty`

## Organisation Payload

`CreateOrganization(payload)` erwartet:

- `name`: Pflicht, String, kleingeschriebener Slug mit Buchstaben, Zahlen, `_` oder `-`
- `label`: Pflicht, String
- `organization_type`: Pflicht, `police`, `ems`, `government`, `gang`, `business` oder `media`
- `mdt_type`: Pflicht, `police`, `ems`, `government`, `gang`, `business`, `media` oder `none`
- `enabled`: optional, boolean

## Grade Payloads

`CreateGrade(payload)` erwartet:

- `organization_id`: Pflicht, ID einer existierenden Organisation
- `name`: Pflicht, String-Slug
- `label`: Pflicht, String
- `level`: Pflicht, Zahl
- `permissions`: optional, Tabelle fuer JSON-Rechte

`UpdateGrade(id, payload)` akzeptiert `name`, `label`, `level` und `permissions` als optionale Aenderungen.

## Member Payloads

`AddMember(payload)` erwartet:

- `organization_id`: Pflicht, ID einer existierenden Organisation
- `character_id`: Pflicht
- `grade_id`: optional, muss zur Organisation gehoeren
- `callsign`: optional, String
- `is_on_duty`: optional, boolean

`UpdateMember(id, payload)` akzeptiert `grade_id`, `callsign` und `is_on_duty` als optionale Aenderungen.

`SetDuty(memberId, isOnDuty)` setzt nur den Duty-Status eines Mitglieds.
