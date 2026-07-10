# Character Security

Stand: 2026-07-10

## Grundregeln

- Account-ID wird nie vom Client uebernommen.
- Character-ID wird immer gegen Accountbesitz geprueft.
- Source wird aus FiveM-Kontext bzw. serverseitigem Exportparameter verwendet.
- Protected Fields werden bei Create/Update blockiert.
- Admin-Mutationen benoetigen Permissions.
- Soft-Delete ist Standard.
- Geloeschte oder blockierte Charaktere koennen nicht ausgewaehlt werden.

## Geschuetzte Felder

- `id`
- `account_id`
- `accountId`
- `player_id`
- `playerId`
- `created_at`
- `createdAt`
- `deleted_at`
- `deletedAt`

## Permission-Beispiele

- `nexa.character.update`
- `nexa.character.delete`
- `nexa.character.block`
- `nexa.character.restore`

## Fehlercodes

- `CHARACTER_NOT_FOUND`
- `CHARACTER_LIMIT_REACHED`
- `CHARACTER_SLOT_OCCUPIED`
- `CHARACTER_INVALID_NAME`
- `CHARACTER_INVALID_BIRTHDATE`
- `CHARACTER_INVALID_HEIGHT`
- `CHARACTER_INVALID_WEIGHT`
- `CHARACTER_NOT_OWNED`
- `CHARACTER_ALREADY_ACTIVE`
- `CHARACTER_SELECTION_IN_PROGRESS`
- `CHARACTER_BLOCKED`
- `CHARACTER_DELETED`
- `CHARACTER_UPDATE_FORBIDDEN`
- `CHARACTER_DELETE_FORBIDDEN`

## Tests

Pflichttests fuer spaetere Runtime:

- fremde Character-ID
- gefaelschte Account-ID
- geschuetzte Updatefelder
- parallele Auswahl
- geloeschten Character auswaehlen
- Admin-Update ohne Permission
- Admin-Update mit Permission
