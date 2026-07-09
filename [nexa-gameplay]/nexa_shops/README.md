# nexa_shops

Foundation fuer ein generisches Nexa Shop-System und das spaetere Nexa Shop Studio.

## Ziel

`nexa_shops` ist die zentrale Backend-Grundlage fuer ingame erstellbare und bearbeitbare Shops. Admins sollen spaeter Shops erstellen, konfigurieren, deaktivieren und mit Items aus `nexa_items` verknuepfen koennen.

Diese Resource baut noch keine UI, kein Kaufsystem, keine NPCs, keine Marker, keine Blips und keine Inventory-Integration. Sie stellt nur Datenmodell, Validierung, Exports und Nexa-Callbacks bereit.

## Shoptypen

Erlaubte `shop_type` Werte:

- `general`
- `food`
- `weapon`
- `medical`
- `mechanic`
- `clothing`
- `blackmarket`
- `job`
- `organization`
- `custom`

Der Typ beschreibt die fachliche Kategorie. Er aktiviert noch keine Kauf- oder Weltlogik.

## Tabellen

`shops`

- `id`
- `name`
- `label`
- `shop_type`
- `enabled`
- `owner_organization_id`
- `location_json`
- `blip_json`
- `npc_json`
- `metadata_json`
- `created_at`
- `updated_at`

`shop_items`

- `id`
- `shop_id`
- `item_name`
- `price`
- `currency_item`
- `stock`
- `max_stock`
- `buyable`
- `sellable`
- `enabled`
- `metadata_json`
- `created_at`
- `updated_at`

## Verbindung zu nexa_items

Shop Items referenzieren Items ueber `item_name`. Wenn `nexa_items` gestartet ist, prueft `nexa_shops` beim Hinzufuegen oder Aendern eines Shop Items, ob das Item existiert.

Diese Resource erzeugt keine Items selbst. Items werden im spaeteren Nexa Item Studio gepflegt und von Shops nur verwendet.

## Server Exports

- `CreateShop(payload)`
- `GetShop(idOrName)`
- `ListShops(filter)`
- `UpdateShop(idOrName, payload)`
- `SetShopEnabled(idOrName, enabled)`
- `DeleteShop(idOrName)`
- `AddShopItem(payload)`
- `ListShopItems(shopIdOrName)`
- `UpdateShopItem(id, payload)`
- `RemoveShopItem(id)`

Alle Antworten enthalten `ok`, `success`, `code`, `message`, `data` und `meta`.

## Callbacks

Die Callbacks werden ueber `nexa_api` registriert:

- `nexa:shops:cb:createShop`
- `nexa:shops:cb:getShop`
- `nexa:shops:cb:listShops`
- `nexa:shops:cb:updateShop`
- `nexa:shops:cb:setShopEnabled`
- `nexa:shops:cb:deleteShop`
- `nexa:shops:cb:addShopItem`
- `nexa:shops:cb:listShopItems`
- `nexa:shops:cb:updateShopItem`
- `nexa:shops:cb:removeShopItem`

## Shop Payload

`CreateShop(payload)` erwartet:

- `name`: Pflicht, String-Slug
- `label`: Pflicht, String
- `shop_type`: Pflicht, erlaubter Shoptyp
- `enabled`: optional, boolean
- `owner_organization_id`: optional, Zahl
- `location`: optional, Tabelle, wird als JSON gespeichert
- `blip`: optional, Tabelle, wird als JSON gespeichert
- `npc`: optional, Tabelle, wird als JSON gespeichert
- `metadata`: optional, Tabelle, wird als JSON gespeichert

`UpdateShop(idOrName, payload)` akzeptiert dieselben bekannten Felder als optionale Aenderungen.

## Shop Item Payload

`AddShopItem(payload)` erwartet:

- `shop_id` oder `shop_name`: Pflicht
- `item_name`: Pflicht, Item-Slug aus `nexa_items`
- `price`: optional, Zahl >= 0
- `currency_item`: optional, Item-Slug fuer alternative Waehrung
- `stock`: optional, Zahl >= 0 oder nicht gesetzt
- `max_stock`: optional, Zahl >= 0 oder nicht gesetzt
- `buyable`: optional, boolean
- `sellable`: optional, boolean
- `enabled`: optional, boolean
- `metadata`: optional, Tabelle, wird als JSON gespeichert

`UpdateShopItem(id, payload)` akzeptiert dieselben bekannten Felder als optionale Aenderungen.

## Spaetere Module

### NPC Shop

Shops koennen spaeter NPC-Konfigurationen nutzen. `npc_json` speichert nur Daten wie Modell, Position, Heading, Scenario und Interaktionsoptionen.

### Marker Shop

Marker-Shops koennen spaeter ueber `location_json` Position, Radius und Interaktionsregeln erhalten.

### Organization Shop

Organisationseigene Shops koennen ueber `owner_organization_id` an JobsCreator-Organisationen gebunden werden.

### Blackmarket

Blackmarket-Shops sind Shoptypen mit eigener Permission-, Reputation-, Location- und Stock-Logik. Diese Foundation speichert nur Typ und Daten.

### Job Shop

Job-Shops koennen spaeter auf Organisation, Rang oder Permission pruefen.

### Buy/Sell

`buyable` steuert, ob Spieler ein Item kaufen duerfen. `sellable` steuert, ob Spieler ein Item an den Shop verkaufen duerfen. Die eigentliche Transaktion wird spaeter separat umgesetzt.

### Stock

`stock` und `max_stock` bereiten begrenzte Shopbestaende vor. `nil` bedeutet aktuell unbegrenzt beziehungsweise nicht verwaltet.
