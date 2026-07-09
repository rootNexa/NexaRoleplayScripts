# nexa_inventory

Foundation fuer ein serverautoratives Nexa Inventar-System.

## Ziel

`nexa_inventory` verwaltet Inventare und Inventar-Items als Backend-Grundlage. Die Resource ist bewusst klein gehalten und nutzt `nexa_items` als Quelle fuer Item-Definitionen.

Diese Phase baut noch keine UI, kein Drag and Drop, keinen Shop-Kauf, kein Crafting, kein Loot, kein Drop-System und keine Item-Benutzung. Mutationen laufen serverseitig ueber Exports und Nexa-Callbacks.

## Grenzen

- keine UI
- kein Inventory-Frontend
- kein Drag and Drop
- kein Shop-Kauf
- kein Crafting
- kein Loot
- kein Drop-System
- keine Item-Benutzung
- keine QBCore/Qbox/ESX-Bridges
- keine fremde Inventory-Resource

## Owner Types

Erlaubte `owner_type` Werte:

- `player`
- `character`
- `vehicle`
- `organization`
- `storage`
- `shop`
- `drop`
- `container`
- `custom`

Der Owner beschreibt, wem oder welchem System ein Inventar gehoert. Fuer Spielerinventare soll langfristig `character` bevorzugt werden, damit Inventare sauber an Charaktere statt an technische Player-Sessions gebunden sind.

## Tabellen

`inventories`

- `id`
- `owner_type`
- `owner_id`
- `label`
- `max_weight`
- `max_slots`
- `metadata_json`
- `created_at`
- `updated_at`

`inventory_items`

- `id`
- `inventory_id`
- `item_name`
- `slot`
- `amount`
- `metadata_json`
- `created_at`
- `updated_at`

## Item-Quelle

`item_name` wird gegen `nexa_items:GetItem(item_name)` geprueft, falls `nexa_items` gestartet ist. Damit bleibt `nexa_items` die zentrale Quelle fuer Item-Definitionen, waehrend `nexa_inventory` nur Besitz, Menge, Slot und Instanz-Metadaten speichert.

## JSON Felder

`inventories.metadata_json` speichert Inventar-Eigenschaften.

Beispiele:

- Storage-Typ
- Zugriffskontext
- Organisationsbezug
- Fahrzeugdaten
- Custom Flags

`inventory_items.metadata_json` speichert Instanzdaten eines Items.

Beispiele:

- Seriennummer
- Haltbarkeit
- Qualitaet
- Besitzer
- Dokumentdaten
- Custom JSON

## Server Exports

- `GetInventory(ownerType, ownerId)`
- `CreateInventory(payload)`
- `ListInventoryItems(inventoryId)`
- `AddItem(payload)`
- `RemoveItem(payload)`
- `SetItemAmount(inventoryItemId, amount)`
- `MoveItem(payload)`
- `ClearInventory(inventoryId)`

Alle Antworten enthalten `ok`, `success`, `code`, `message`, `data` und `meta`.

## Callbacks

Die Callbacks werden ueber `nexa_api` registriert:

- `nexa:inventory:cb:getInventory`
- `nexa:inventory:cb:listItems`
- `nexa:inventory:cb:addItem`
- `nexa:inventory:cb:removeItem`
- `nexa:inventory:cb:moveItem`

Clients duerfen damit keine vertrauenswuerdigen Aenderungen erzwingen. Spaetere Gameplay-Ressourcen muessen serverseitig entscheiden, ob eine Mutation erlaubt ist.

## Payloads

`CreateInventory(payload)` erwartet:

- `owner_type`: Pflicht, erlaubter Owner Type
- `owner_id`: Pflicht, String
- `label`: optional, String
- `max_weight`: optional, Zahl >= 0
- `max_slots`: optional, Zahl >= 0
- `metadata`: optional, Tabelle, wird als JSON gespeichert

`AddItem(payload)` erwartet:

- `inventory_id`: Pflicht
- `item_name`: Pflicht, wird gegen `nexa_items` geprueft, falls verfuegbar
- `slot`: optional, Zahl >= 1
- `amount`: optional, Zahl >= 1
- `metadata`: optional, Tabelle, wird als JSON gespeichert

`RemoveItem(payload)` erwartet:

- `inventory_item_id` oder `id`: Pflicht
- `amount`: Pflicht, Zahl >= 1

`MoveItem(payload)` erwartet:

- `inventory_item_id` oder `id`: Pflicht
- `target_inventory_id` oder `inventory_id`: Pflicht
- `slot`: optional, Zahl >= 1

## Permission Vorbereitung

Mutierende Callback-Aktionen koennen ueber `NexaInventoryConfig.requireAdminPermissionForMutations` abgesichert werden. Die vorbereitete Permission ist:

- `nexa.inventory.manage`

Direkte Server-Exports bleiben serverseitige Integrationspunkte und muessen von aufrufenden Ressourcen verantwortungsvoll genutzt werden.
