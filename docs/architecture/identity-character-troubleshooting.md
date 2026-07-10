# Identity and Character Troubleshooting

Stand: 2026-07-10

## Account ist nicht bereit

Pruefen:

- laeuft `nexa-core`?
- laeuft `nexa_identity` nach `nexa-core`?
- besitzt die Session `license` oder `license2`?
- existiert ein `nexa_accounts`-Datensatz?

## Character kann nicht erstellt werden

Pruefen:

- ist `nexa_identity` ready?
- existiert `legacy_player_id` fuer den Account?
- ist das Slotlimit erreicht?
- sind Vorname, Nachname, Geburtsdatum, Groesse und Gewicht gueltig?

## Character kann nicht ausgewaehlt werden

Pruefen:

- gehoert `characterId` zum Account?
- ist der Character `blocked` oder `deleted`?
- ist derselbe Character bereits in einer anderen Session aktiv?
- laeuft noch eine Auswahl fuer dieselbe Source?

## Alte Core-Exports warnen

Warnung:

```text
Deprecated Core character export used.
```

Massnahme:

- auf `nexa_characters` oder `nexa_api` migrieren
- Aufrufer aus dem Log entfernen
- Core-Export erst spaeter entfernen
