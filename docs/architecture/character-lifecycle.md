# Character Lifecycle

Stand: 2026-07-10

## Zustaende

- `not_selected`
- `selecting`
- `selected`
- `loading`
- `active`
- `unloading`
- `released`

## Auswahl

1. Client fragt Auswahl an.
2. Server ermittelt Source.
3. `nexa_identity` liefert Account-ID.
4. Character wird geladen.
5. `account_id` wird gegen den Account geprueft.
6. Status wird geprueft.
7. parallele Auswahl wird blockiert.
8. vorheriger aktiver Character wird freigegeben.
9. neuer Character wird aktiv.
10. `nexa:internal:characters:selected` wird emittiert.

## Release

Ein Character wird freigegeben bei:

- Spielerdisconnect
- Resource-Stop
- Character-Delete
- spaeterem Character-Wechsel

`nexa:internal:characters:released` informiert interne Systeme.

## Race Conditions

`selectionLocks[source]` verhindert parallele Auswahl pro Source. `activeSourceByCharacterId` verhindert, dass derselbe Character gleichzeitig in mehreren Sessions aktiv ist.
