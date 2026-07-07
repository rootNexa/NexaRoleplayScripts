# nexa_identity

Phase-4A-Resource fuer Charakterverwaltung und RP-Identitaet.

## Zweck

- Charaktererstellung
- Charakterauswahl
- aktive Identitaet
- Spawn-Pipeline nach Charakterauswahl
- Soft-Delete-Lebenszyklus

## Abhaengigkeiten

- `ox_lib`
- `oxmysql`
- `qbx_core`
- `nexa_api`
- `nexa_security`
- `nexa_logs`

## Callbacks

- `nexa:identity:cb:listCharacters`
- `nexa:identity:cb:createCharacter`
- `nexa:identity:cb:selectCharacter`
- `nexa:identity:cb:deleteCharacter`
- `nexa:identity:cb:getActiveCharacter`

Alle Callbacks verwenden das Nexa-Standardformat `success`, `code`, `message`, `data`, `meta`, `audit_id`.

## Events

- `nexa:identity:server:requestOpenManager`
- `nexa:identity:server:requestCreateCharacter`
- `nexa:identity:server:requestSelectCharacter`
- `nexa:identity:server:requestDeleteCharacter`
- `nexa:identity:client:openManager`
- `nexa:identity:client:spawnPrepared`

## Datenbanktabellen

Die Resource nutzt ausschliesslich vorhandene Tabellen:

- `players`
- `player_identifiers`
- `characters`
- `character_status`
- `character_metadata`
- `phone_numbers`

## Grenzen

Nicht enthalten sind Dokumente, Lizenzen, Banking, Jobs, Businesses, Dispatch, Fahrzeuge, Housing, Polizei und EMS.
