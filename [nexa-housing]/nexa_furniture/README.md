# nexa_furniture

Phase 7D Furniture foundation fuer Property Units.

## Umfang

- Moebel laden, platzieren, speichern und entfernen
- serverseitige Besitzer-/Mieterpruefung ueber `nexa_api.property`
- serverseitige Positions- und Rotationsvalidierung mit verpflichtenden Property-Bounds
- Audit und technische Logs fuer schreibende Aktionen
- Rate-Limits ueber `nexa_security`
- minimale ox_lib-Callbacks und Client-Exports

## Grenzen

- keine Doorlock-Vollintegration
- keine komplexen Interiors
- keine Polizei-, EMS- oder illegalen Systeme
- keine grosse UI und keine NUI
- keine Item-Logik; Inventory bleibt bei `ox_inventory`

Der Client trifft keine finale Entscheidung ueber Besitz, Zugriff, Position oder Persistenz.
