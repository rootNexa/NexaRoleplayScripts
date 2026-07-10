# Inventory Current State

Stand: 2026-07-10

`[nexa-gameplay]/nexa_inventory` existiert bereits als fruehe Backend-Foundation. Die Resource nutzt noch direkte `oxmysql`-Imports (`@oxmysql/lib/MySQL.lua`) und Tabellen ohne Nexa-Prefix (`inventories`, `inventory_items`). Vorhanden sind einfache Exports fuer `CreateInventory`, `GetInventory`, `ListInventoryItems`, `AddItem`, `RemoveItem`, `SetItemAmount`, `MoveItem` und `ClearInventory`.

## Befund

- Kein serverautoritatives Character-Inventory-Lifecycle nach `nexa_playerstate`.
- Keine Slotsicherheit gegen doppelte Slotbelegung.
- Keine Gewichtskontrolle.
- Keine Iteminstanz-IDs.
- Keine Quickslots.
- Keine Container- oder Drop-Grundlage.
- Keine Transaktionslocks.
- Mutierende Callbacks sind admin-geschuetzt, aber fachlich noch nicht gameplay-ready.
- Direkte SQL-Aufrufe liegen in `server/database.lua`.
- `nexa_items` existiert und liefert Itemdefinitionen (`weight`, `stackable`, `max_stack`, `usable`).

## Risiken

- Duplikation durch parallele Mutationen.
- Lost Updates bei Transfers.
- Unsichere freie Inventory-ID-Nutzung in Client-Callbacks.
- Gewicht/Slotlimit werden nicht erzwungen.
- Alte Tabellen koennen nicht als Kapitel-06-Zielmodell gelten.

## Ziel

`nexa_inventory` wird auf `nexa-core` Database/Migrationen umgestellt und besitzt danach die Domaene Inventare, Slots, Iteminstanzen, Gewicht, Locks, Transfers, Quickslots, Container-Grundlage und Drops. `nexa_items` bleibt die Itemdefinitionsquelle.
