# nexa_hud

Read-only HUD fuer Phase 5B.

## Zweck

`nexa_hud` zeigt kompakte Spielerinformationen an:

- Statusanzeige
- Job-/Business-Anzeige
- Geldanzeige nur lesend
- Voice-/Funk-Anzeige ohne eigenes Funksystem
- Fahrzeuganzeige ohne Fahrzeuglogik
- HUD-Sichtbarkeit
- deutsche, lore-friendly Texte

## Grenzen

- Keine Handy-, Tablet- oder MDT-Funktionen.
- Keine Banking-UI.
- Keine Fahrzeug-Systeme.
- Kein Funk-System.
- Keine Polizei-/EMS-UI.
- Keine Admin-UI.
- Keine neuen Gameplay-Systeme.
- Keine Geld-, Item-, Job-, Fraktions- oder Adminlogik.
- Keine direkten Datenbankzugriffe.

## Abhaengigkeiten

- `ox_lib`
- `nexa_ui`
- `nexa_api`

## Datenquellen

Serverseitige HUD-Daten werden ausschliesslich read-only ueber bestehende `nexa_api`-Exports gelesen:

- `character.getActive`
- `account.list`
- `job.getCharacter`
- `business.list`

Lokale Anzeigen wie Gesundheit, Schutz und Fahrzeugtempo kommen aus FiveM-Client-Natives und sind nur Darstellung.

## Events

Client:

- `nexa:hud:client:updateStatus`
- `nexa:hud:client:setVisible`
- `nexa:hud:client:updateVoice`
- `nexa:hud:client:updateRadio`

Es gibt keine oeffentlichen Server-Schreibevents.

## Callback

- `nexa:hud:cb:getSnapshot`

Der Callback liefert nur Anzeige-Snapshots und fuehrt keine kritischen Aktionen aus.

## Exports

Client:

- `setVisible(visible)`
- `isVisible()`
- `refresh()`

## Testhinweise

Der Phase-5B-Grenztest prueft Struktur, NUI, `nexa_ui`-Abhaengigkeit, read-only API-Nutzung, ausgeschlossene Systeme, fehlende DB-Zugriffe und Startreihenfolge.
