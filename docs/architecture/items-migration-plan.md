# Items Migration Plan

## Reihenfolge

1. Bestehende Item-Foundation dokumentieren.
2. `nexa_items` von direktem oxmysql loesen.
3. Append-only Migration `070_item_registry_foundation` einfuehren.
4. Itemtypen serverseitig registrieren.
5. Itemdefinitionen versionieren und soft-delete faehig machen.
6. Metadata-, Stack-, Durability-, Expiration-, Action- und Asset-Foundation implementieren.
7. Inventory-Uebergangskatalog entfernen.
8. Runtime-Harness und Validatoren ergaenzen.

## Legacy

Alte Exports bleiben delegierend erhalten. Alte Tabelle `items` wird nicht automatisch geloescht. Eine spaetere Migration kann alte Datensaetze nach `nexa_item_definitions` uebertragen.
