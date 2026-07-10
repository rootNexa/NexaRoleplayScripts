# Inventory Migration Plan

## Reihenfolge

1. Architekturgrenzen dokumentieren.
2. `nexa_inventory` von direktem `oxmysql` loesen.
3. Neue append-only Migration `060_inventory_foundation` fuer `nexa_*` Tabellen einfuehren.
4. Character-Inventar-Lifecycle an `nexa:player:ready` und `nexa:player:unloading` anbinden.
5. Slots, Gewicht und Iteminstanzen erzwingen.
6. Lock- und Transaktionsmodell fuer Mutationen verwenden.
7. Quickslots, Container-Grundlage und Drops hinzufuegen.
8. Legacy-Exports kontrolliert weiterfuehren, aber auf sichere Implementierung delegieren.
9. Runtime-Testresource und statische Validatoren hinzufuegen.

## Legacy-Daten

Alte Tabellen `inventories` und `inventory_items` werden nicht automatisch geloescht oder migriert. Eine spaetere Datenmigration muss Backup, Mapping und Validierung separat liefern.

## Entfernungskriterien

Alte APIs duerfen erst entfernt werden, wenn alle Aufrufer auf die neuen Exports/Callbacks migriert sind und keine Resource mehr direkte Legacy-Tabellen erwartet.
