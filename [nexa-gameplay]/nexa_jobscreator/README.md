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

Alle API-Antworten enthalten `ok`, `success`, `code`, `message`, `data` und `meta`.

## Callbacks

Die Callbacks werden ueber `nexa_api` registriert:

- `nexa:jobscreator:cb:createOrganization`
- `nexa:jobscreator:cb:getOrganization`
- `nexa:jobscreator:cb:listOrganizations`
- `nexa:jobscreator:cb:setOrganizationEnabled`

## Organisation Payload

`CreateOrganization(payload)` erwartet:

- `name`: Pflicht, String, kleingeschriebener Slug mit Buchstaben, Zahlen, `_` oder `-`
- `label`: Pflicht, String
- `organization_type`: Pflicht, `police`, `ems`, `government`, `gang`, `business` oder `media`
- `mdt_type`: Pflicht, `police`, `ems`, `government`, `gang`, `business`, `media` oder `none`
- `enabled`: optional, boolean
