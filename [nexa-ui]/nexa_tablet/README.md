# nexa_tablet

Phase-5C-Resource fuer eine reine Tablet UI-Shell.

## Umfang

- Tablet-Grundstruktur mit NUI-App-Shell
- Navigation fuer Apps und Info
- serverseitig gefilterte, deaktivierte Platzhalter fuer Dienst, Firmen und Gruppen
- Zugriffskontrolle ueber `nexa_permissions`
- Nutzung von `nexa_ui` fuer Design-System und Locale-Hilfen
- minimale `ox_lib`-Nutzung fuer Callback und Hinweis

## Grenzen

- Das Tablet ist nur UI-Shell und App-Container.
- Apps bleiben deaktivierte, dokumentierte Eintraege.
- Apps werden nur angezeigt, wenn die Permission serverseitig erfolgreich geprueft wurde.
- Keine kritischen Entscheidungen im Client.
- Keine Geld-, Item-, Job-, Fraktions- oder Adminlogik.
- Keine direkten Datenbankzugriffe.
- Keine Handy-, MDT-, Banking-, Polizei-/EMS-, Fahrzeug-, Housing- oder Admin-UI.
- Keine neuen Gameplay-Systeme.
