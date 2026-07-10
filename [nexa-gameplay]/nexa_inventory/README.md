# nexa_inventory

Server-authoritative Nexa inventory foundation.

## Scope

`nexa_inventory` owns inventories, slots, item instances, stack amounts, weight, quickslots, containers, drops, locks, transfers and audit. It does not own item definitions; `nexa_items` remains the preferred definition source.

No UI, no drag and drop, no item use, no shops, no crafting and no weapon gameplay are implemented in this chapter.

## Defaults

- Character inventory: 30 slots.
- Character carrying capacity: 30,000 grams.
- Quickslots: 5.
- Drop lifetime: 300 seconds.
- Container nesting: forbidden.

## Tables

Migration `060_inventory_foundation` creates:

- `nexa_inventories`
- `nexa_inventory_items`
- `nexa_inventory_quickslots`
- `nexa_inventory_audit`

Legacy tables `inventories` and `inventory_items` are not deleted or migrated automatically.

## Item Definitions

When `nexa_items` is started, item definitions are resolved through `exports.nexa_items:GetItem(name)`.

If `nexa_items` is unavailable, a tiny internal transition catalog is available for `water`, `bread` and `radio`. This fallback is documented migration debt and must not grow into a second item system.

## Exports

- `GetInventory(inventoryIdOrType, ownerType, ownerId)`
- `GetCharacterInventory(characterIdOrSource)`
- `GetItem(inventoryId, slot)` or `GetItem(inventoryItemId)`
- `GetItems(inventoryId)`
- `HasItem(inventoryId, itemName, amount)`
- `CanCarry(inventoryId, itemName, amount, metadata)`
- `AddItem(inventoryId, itemName, amount, metadata, context)`
- `RemoveItem(inventoryId, itemReference, amount, context)`
- `MoveItem(inventoryId, fromSlot, toSlot, amount, context)`
- `TransferItem(sourceInventoryId, targetInventoryId, itemReference, amount, context)`
- `GetWeight(inventoryId)`
- `GetLimits(inventoryId)`
- `AssignQuickslot(characterId, quickslot, itemReference, context)`
- `ClearQuickslot(characterId, quickslot, context)`
- `CreateContainer(itemInstance, definition, context)`
- `CreateDrop(sourceInventoryId, itemReference, amount, position, context)`

Legacy foundation exports remain as delegating compatibility:

- `CreateInventory`
- `ListInventoryItems`
- `SetItemAmount`
- `ClearInventory`

## Security

Clients do not create items, choose authoritative amounts, define weights, set arbitrary metadata, or open foreign inventories by ID. Network callbacks bind to the actual FiveM source and resolve the active character server-side.

Mutations require a context with reason/correlation data and write audit entries to `nexa_inventory_audit`.

## Runtime Tests

Development-only runtime tests live in `[nexa-tests]/nexa-inventory-runtime-tests`.

Command:

```text
nexa_test_inventory_runtime [suite]
```

Live FXServer suites are documented as open unless actually executed in a running server.
