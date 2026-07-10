# Character Architecture

Stand: 2026-07-10

`nexa_characters` ist die serverseitige Character-Domain.

## Verantwortlichkeiten

- Charakterliste eines Accounts
- Charaktererstellung
- Charakterauswahl
- Charakteraktualisierung
- Soft-Delete
- aktiver Charakter je Session
- Character-Lifecycle
- Validierung
- Audit

## Nicht verantwortlich

- Account-Aufloesung
- Spawn
- Kleidung
- Inventar
- Geld
- Jobs
- UI

## Datenmodell

Die bestehende Tabelle `nexa_characters` wird append-only erweitert.

Neue oder fachlich relevante Felder:

- `account_id`
- `slot`
- `status`
- `height`
- `weight`
- `nationality`
- `backstory`
- `phone_number`
- `version`
- `last_selected_at`
- `deleted_at`

`player_id` bleibt vorerst als Legacy-Kompatibilitaet zu `nexa_players`.

## Exports

- `ListCharacters(source)`
- `GetCharacter(characterId)`
- `GetActiveCharacter(source)`
- `CreateCharacter(source, payload)`
- `SelectCharacter(source, characterId)`
- `UpdateCharacter(source, characterId, changes)`
- `DeleteCharacter(source, characterId, reason)`
- `BlockCharacter(source, characterId, reason)`
- `RestoreCharacter(source, characterId)`

## Callbacks

- `nexa:characters:cb:list`
- `nexa:characters:cb:create`
- `nexa:characters:cb:select`
- `nexa:identity:cb:status`

Callbacks nutzen das Core-Callback-System.

## Grenzen

Account-ID wird immer serverseitig ueber `nexa_identity` abgeleitet. Der Client darf weder Account-ID noch Source als vertrauenswuerdige Fachinformation liefern.
