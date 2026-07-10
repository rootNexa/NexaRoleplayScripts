# Inventory Domain Boundary

## `nexa_items`

`nexa_items` definiert Itemarten: Name, Label, Typ, Gewicht, Stackbarkeit, Stacklimit, Nutzbarkeit, Metadaten und Use-Config.

## `nexa_inventory`

`nexa_inventory` besitzt Iteminstanzen und Besitz: Inventory, Slot, Menge, Metadaten, Instanz-ID, Gewicht, Quickslots, Locks, Transfers, Container und Drops.

## Regeln

- Itemgewicht kommt aus `nexa_items` oder aus einem dokumentierten internen Uebergangskatalog.
- Clients duerfen keine Itemdefinitionen, Gewichte, Mengen, Slots oder Metadaten autoritativ setzen.
- Character-Inventare werden erst nach gameplay-ready geladen.
- `nexa-core`, `nexa_characters` und `nexa_playerstate` haengen nicht von `nexa_inventory` ab.
