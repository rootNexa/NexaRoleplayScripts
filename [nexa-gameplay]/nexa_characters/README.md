# nexa_characters

Serverseitige Character-Domain fuer Nexa Roleplay.

## Zweck

- Charakterliste eines Accounts
- Charaktererstellung
- Charakterauswahl
- Charakteraktualisierung
- Soft-Delete
- aktiver Charakter je Session
- Character-Lifecycle
- Validierung und Audit-Logs

Nicht enthalten:

- Account-Aufloesung
- Spawn
- Kleidung
- Inventar
- Geld
- Jobs
- UI

## Abhaengigkeiten

- `nexa-core`
- `nexa_identity`

Alle Datenbankzugriffe laufen ueber `exports['nexa-core']:GetCoreObject().Database`.

## Character-Modell

Pflichtfelder:

- Vorname
- Nachname
- Geburtsdatum
- Geschlecht
- Groesse
- Gewicht

Technische Felder:

- `id`
- `account_id`
- `slot`
- `status`
- `version`
- `last_selected_at`
- `created_at`
- `updated_at`
- `deleted_at`

## Status

- `active`
- `inactive`
- `deleted`
- `blocked`
- `pending_review`

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

Account-ID wird immer serverseitig ueber `nexa_identity` aufgeloest. Clients duerfen keine Account-ID vorgeben.

## Callbacks

- `nexa:characters:cb:list`
- `nexa:characters:cb:create`
- `nexa:characters:cb:select`
- `nexa:identity:cb:status`

Callbacks nutzen das Core-Callback-System und geben `{ ok = true, data = ... }` oder `{ ok = false, error = ... }` zurueck.

## Sicherheitsregeln

- Character-ID wird gegen Accountbesitz geprueft.
- Eine Session darf nur einen aktiven Charakter besitzen.
- Ein Charakter darf nicht gleichzeitig in mehreren Sessions aktiv sein.
- Soft-Delete ist Standard.
- Admin-Mutationen benoetigen Permissions.
- Protected Fields wie `account_id`, `player_id`, `created_at` und `deleted_at` werden nicht aus Clientpayloads uebernommen.

## Migration

Die Resource erweitert die bestehende Tabelle `nexa_characters` append-only um Account-, Slot-, Status- und Profilfelder. Die bestehende `player_id`-Spalte bleibt als Legacy-Kompatibilitaet erhalten, bis Core-Character-Logik vollstaendig migriert ist.
