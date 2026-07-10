# nexa_items

Server-authoritative item registry and Item Studio foundation.

## Scope

`nexa_items` owns item definitions, item types, metadata schemas, weights, stack rules, durability config, expiration config, action handler references, asset references, versions and audit.

`nexa_inventory` owns concrete item instances, slots, amounts and transfers.

## Tables

Migration `070_item_registry_foundation` creates:

- `nexa_item_definitions`
- `nexa_item_definition_versions`
- `nexa_item_actions`
- `nexa_item_assets`
- `nexa_item_audit`

Legacy table `items` is not deleted automatically.

## Item Names

Names must be lowercase and may contain numbers and underscores. Leading/trailing underscores and double underscores are invalid.

Valid examples:

- `water`
- `bread`
- `radio`
- `weapon_pistol`
- `black_money`

## Item Types

Registered by default:

- `generic`
- `food`
- `drink`
- `medical`
- `weapon`
- `ammunition`
- `document`
- `key`
- `container`
- `currency`
- `material`
- `tool`
- `radio`
- `consumable`

## Status

- `draft`
- `published`
- `disabled`
- `deprecated`
- `deleted`

Only `published` definitions are normal gameplay definitions. `deleted` is a soft-delete state.

## Exports

- `CreateItem(payload)`
- `GetItem(name)`
- `ListItems(filter)`
- `UpdateItem(name, payload)`
- `SetItemEnabled(name, enabled)`
- `DeleteItem(name)`
- `PublishItem(name, context)`
- `DeprecateItem(name, context)`
- `GetItemDefinition(name)`
- `ItemExists(name)`
- `GetItemWeight(name)`
- `GetMaxStack(name)`
- `IsStackable(name)`
- `ValidateMetadata(name, metadata)`
- `CanUse(name)`
- `CanQuickslot(name)`
- `CanDrop(name)`
- `CanTrade(name)`
- `IsContainer(name)`
- `GetClientDefinition(name)`
- `GetClientCatalog(filters)`
- `RegisterItemType(definition)`
- `RegisterActionHandler(name, definition)`

Legacy exports delegate to the central registry.

## Actions

Item actions never execute free event names from the database. Database rows reference registered handler names only. Dynamic Lua execution from stored configuration is forbidden.

## Assets

Asset references allow local NUI/web references and controlled HTTPS URLs. HTTP, data URLs, `file://`, `javascript:`, localhost and private network hosts are rejected.

## Bootstrap Definitions

The old Inventory transition catalog is migrated into registry-owned built-in definitions if missing:

- `water`
- `bread`
- `radio`
