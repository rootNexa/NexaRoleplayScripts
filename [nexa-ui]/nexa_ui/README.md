# nexa_ui

Zentrales NEXA Design-System fuer Phase 5A.

## Zweck

`nexa_ui` stellt wiederverwendbare UI-Grundlagen bereit:

- Design-Tokens und responsives NUI-Layout
- Notifications
- Confirm-Dialoge
- einfache Menues
- Context-Menues
- deutsche Locale
- clientseitige Exports fuer UI-Hilfen

## Grenzen

- Kein HUD.
- Kein Tablet.
- Kein Handy.
- Kein MDT.
- Keine Banking-, Polizei-, EMS-, Fahrzeug-, Housing- oder Gameplay-UI.
- Keine Geld-, Item-, Job-, Fraktions- oder Adminlogik.
- UI zeigt Daten an und sendet hoechstens UI-Auswahlen; kritische Entscheidungen bleiben serverseitig.

## Abhaengigkeiten

- `nexa_config`
- `nexa_locales`

## Exports

Client:

- `open(payload)`
- `close()`
- `notify(payload)`
- `confirm(payload, callback)`
- `menu(payload)`
- `registerContext(context)`
- `showContext(id)`
- `hideContext(force)`
- `getOpenContextMenu()`
- `getTheme()`
- `getLocale()`

## Events

Client:

- `nexa:ui:client:open`
- `nexa:ui:client:close`
- `nexa:ui:client:notify`
- `nexa:ui:client:confirm`
- `nexa:ui:client:menu`

Es gibt keine oeffentlichen Client-zu-Server-Schreibevents.

## Datenbanktabellen

Keine.

## Permissions

Keine. Sichtbarkeit im UI ist Komfort und niemals autoritativ.

## Testhinweise

Der Phase-5A-Grenztest prueft Resource-Struktur, Startreihenfolge, Exports, NUI-Dateien, deutsche Texte und ausgeschlossene Systeme.
