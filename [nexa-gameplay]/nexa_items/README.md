# nexa_items

Foundation fuer ein generisches Nexa Item-System und das spaetere Nexa Item Studio.

## Ziel

`nexa_items` ist die zentrale Grundlage fuer ingame erstellbare und bearbeitbare Items. Admins sollen spaeter Items erstellen, konfigurieren, deaktivieren und fuer andere Nexa-Systeme bereitstellen koennen.

Diese Resource baut noch kein Inventory, keine Item-Benutzung, keine Waffenlogik und keine Animationen. Sie stellt das serverseitige Datenmodell, Validierung, Exports und Nexa-Callbacks bereit.

## Item Studio UI Foundation

Phase 1 enthaelt eine clientseitige Admin-UI-Foundation ueber NexaUI Context, NexaUI Input und NexaUI Notify. Die UI ist bewusst nur eine Bedienoberflaeche ohne Speicherung und ohne Backend-Mutationen.

Commands:

- `/itemstudio`
- `/nexaitems`

Vorhandene Bereiche:

- Sidebar mit Dashboard, Items, Kategorien, Import, Export und Settings
- Itemliste mit Suche, Kategoriebaum und Toolbar
- Toolbar mit Neu, Bearbeiten, Duplizieren, Aktivieren, Deaktivieren, Loeschen, Import und Export
- Editor-Tabs fuer Allgemein, Typ, Metadata, Use Config und Preview
- Rechte Editor als Vorbereitung fuer spaetere Admin-Permissions
- Preview mit Bild, Name, Beschreibung, Stack, Gewicht und Seltenheit

## Nicht Enthalten

- keine persistente UI-Speicherung
- kein Inventory
- keine Item-Benutzung
- keine Waffenlogik
- keine Animationen
- keine QBCore/Qbox/ESX-Bridges
- keine externe UI-Bibliothek

## Item Types

Erlaubte `item_type` Werte:

- `food`
- `drink`
- `weapon`
- `armor`
- `medical`
- `tool`
- `document`
- `license`
- `key`
- `drug`
- `material`
- `container`
- `custom`

Der Typ beschreibt die fachliche Kategorie. Er aktiviert noch keine Benutzung und keine Speziallogik. Spaetere Systeme duerfen anhand von `item_type`, `usable`, `metadata_json` und `use_config_json` entscheiden, welche Features verfuegbar sind.

## Tabelle

`items`

- `id`
- `name`
- `label`
- `description`
- `item_type`
- `image_url`
- `weight`
- `stackable`
- `max_stack`
- `usable`
- `tradable`
- `droppable`
- `enabled`
- `metadata_json`
- `use_config_json`
- `created_at`
- `updated_at`

## JSON Felder

`metadata_json` speichert statische Item-Eigenschaften.

Beispiele:

- Naehrwerte fuer Essen
- Kaliber oder Kategorie fuer Waffen
- Schutzwert fuer Armor
- Dokumenttemplate fuer Dokumente
- Container-Groesse
- Custom Tags fuer Serverlogik

`use_config_json` speichert spaetere Benutzungsregeln.

Beispiele:

- Dauer der Benutzung
- Animation-Key
- Effektwerte
- Cooldown
- Verbrauch nach Benutzung
- serverseitiger Handler-Key

Die Resource fuehrt diese Effekte noch nicht aus. Sie speichert nur die Konfiguration.

## Server Exports

- `CreateItem(payload)`
- `GetItem(idOrName)`
- `ListItems(filter)`
- `UpdateItem(idOrName, payload)`
- `SetItemEnabled(idOrName, enabled)`
- `DeleteItem(idOrName)`

Alle Antworten enthalten `ok`, `success`, `code`, `message`, `data` und `meta`.

## Callbacks

Die Callbacks werden ueber `nexa_api` registriert:

- `nexa:items:cb:createItem`
- `nexa:items:cb:getItem`
- `nexa:items:cb:listItems`
- `nexa:items:cb:updateItem`
- `nexa:items:cb:setItemEnabled`
- `nexa:items:cb:deleteItem`

## Permission Vorbereitung

Mutierende Callback-Aktionen koennen ueber `NexaItemsConfig.requireAdminPermissionForMutations` abgesichert werden. Die vorbereitete Permission ist:

- `nexa.items.manage`

Direkte Server-Exports bleiben serverseitige Integrationspunkte und muessen von aufrufenden Ressourcen verantwortungsvoll genutzt werden.

## Payload

`CreateItem(payload)` erwartet:

- `name`: Pflicht, String-Slug
- `label`: Pflicht, String
- `item_type`: Pflicht, erlaubter Item Type
- `description`: optional, String
- `image_url`: optional, String
- `weight`: optional, Zahl >= 0
- `stackable`: optional, boolean
- `max_stack`: optional, Zahl >= 1
- `usable`: optional, boolean
- `tradable`: optional, boolean
- `droppable`: optional, boolean
- `enabled`: optional, boolean
- `metadata`: optional, Tabelle, wird als JSON gespeichert
- `use_config`: optional, Tabelle, wird als JSON gespeichert

`UpdateItem(idOrName, payload)` akzeptiert dieselben bekannten Felder als optionale Aenderungen.

## Beispiele

### Food

- `name`: `sandwich`
- `label`: `Sandwich`
- `item_type`: `food`
- `weight`: `250`
- `stackable`: `true`
- `max_stack`: `10`
- `usable`: `true`
- `metadata`: Hungerwert, Verderblichkeit, Kategorie
- `use_config`: Nutzungsdauer, Animation-Key, Effekt

### Drink

- `name`: `water_bottle`
- `label`: `Wasserflasche`
- `item_type`: `drink`
- `weight`: `500`
- `stackable`: `true`
- `max_stack`: `12`
- `usable`: `true`
- `metadata`: Durstwert, Flaschenart
- `use_config`: Trinkdauer, Animation-Key, Verbrauch

### Weapon

- `name`: `weapon_pistol`
- `label`: `Pistole`
- `item_type`: `weapon`
- `weight`: `1200`
- `stackable`: `false`
- `max_stack`: `1`
- `usable`: `false`
- `metadata`: Waffenkategorie, Kaliber, Seriennummer-Regel
- `use_config`: spaeterer Handler-Key fuer Waffenlogik

### Armor

- `name`: `light_armor`
- `label`: `Leichte Schutzweste`
- `item_type`: `armor`
- `weight`: `2200`
- `stackable`: `false`
- `max_stack`: `1`
- `usable`: `true`
- `metadata`: Schutzwert, Haltbarkeit
- `use_config`: Anlegezeit, Armor-Effekt, Verbrauchsregel

### Custom

- `name`: `event_token`
- `label`: `Event Token`
- `item_type`: `custom`
- `weight`: `0`
- `stackable`: `true`
- `max_stack`: `99`
- `usable`: `false`
- `metadata`: Event-ID, Gueltigkeit, Custom Tags
- `use_config`: optionaler spaeterer Handler-Key
