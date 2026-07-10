# Nexa Core Overview

Stand: 2026-07-10

Dieses Dokument beschreibt den aktuell vorgefundenen Core- und Foundation-Zustand des Nexa-Roleplay-Repositories. Grundlage sind die vorhandenen README-Dateien, `fxmanifest.lua`-Dateien, Start-Konfigurationen, Core-Quelltexte und Repository-Suchen nach Framework-, Datenbank-, Event-, Export- und Permission-Mustern.

## Zielbild

Nexa Roleplay ist ein eigenes FiveM-Framework. Externe Frameworks wie QBCore, Qbox, ESX, ox_lib und ox_inventory sollen nicht Teil der Zielarchitektur sein. Als technische externe Grundlage bleibt aktuell `oxmysql` fuer MariaDB-Zugriff erhalten.

Der Core soll die serverautoritative Basis liefern, auf der Gameplay-, UI-, Admin- und Welt-Ressourcen arbeiten koennen, ohne eigene Framework-Bridges oder Fremdabhaengigkeiten einzubauen.

## Zweck von nexa_core

`[nexa-core]/nexa-core` ist die zentrale Laufzeitbasis fuer Spieler-, Identifier- und Charakterzustand. Die Resource stellt aktuell folgende Kernfunktionen bereit:

- Player-Session anhand von `source` und FiveM-Identifiern registrieren.
- Primaeren Identifier nach `Nexa.Config.identifierPriority` ermitteln.
- Spieler in `nexa_players` anlegen oder aktualisieren.
- Charaktere laden, erstellen, auswaehlen und aktualisieren.
- Charakterbesitz serverseitig pruefen.
- Core-Callbacks und Core-Events bereitstellen.
- Einfache Permission-Fallbacks ueber ACE und `nexa_permissions`-Tabelle anbieten.
- Eine interne `Nexa.Database`-Abstraktion ueber `oxmysql` kapseln.

`nexa_core` ist damit Session- und Character-Core, nicht Gameplay-Core.

## Verantwortlichkeiten

`nexa_core` verantwortet:

- **Identifier:** Einsammeln von `license`, `license2`, `fivem`, `discord`, `steam` und weiteren FiveM-Identifiern ueber `GetPlayerIdentifiers`.
- **Session:** Zuordnung `source -> player`, `identifier -> player`, aktiver Charakter pro Spieler.
- **Character Ownership:** Alle Charakterzugriffe laufen ueber `player_id`; Auswahl und Updates pruefen den Besitzer.
- **Lifecycle Events:** Laden, Auswaehlen und Entladen von Spielern und Charakteren.
- **Core API:** Server-Exports fuer Player, Character, Identifier, Permission und Character-Verwaltung.
- **Core Callback-Kanal:** Server-Callbacks fuer Core-nahe Client-Abfragen.
- **Audit Hooks:** Sicherheitsrelevante Ablehnungen werden an `nexa_audit` weitergereicht, wenn vorhanden.
- **Datenbankzugriff:** Interner Wrapper `Nexa.Database` ueber `MySQL.query`, `insert`, `update`, `transaction` und `scalar`.

## Ausgeschlossene Verantwortlichkeiten

`nexa_core` soll ausdruecklich nicht verantwortlich sein fuer:

- Jobs, Fraktionen, Organisationen oder Duty-Logik.
- Inventory, Items, Shops, Crafting, Loot oder Drops.
- Economy, Banking, Billing oder Business-Logik.
- MDT, Dispatch, Phone, Tablet, HUD oder andere UI.
- Housing, Vehicles, Criminal-Systeme oder World-Features.
- Admin-Menues, Devtools oder Ingame-Editoren.
- QBCore-, Qbox-, ESX-, ox_lib- oder ox_inventory-Kompatibilitaet.
- Clientseitig vertrauenswuerdige Gameplay-Entscheidungen.

Diese Grenzen sind wichtig, damit `nexa_core` stabil bleibt und neue Systeme wie `nexa_jobscreator`, `nexa_items`, `nexa_inventory` und `nexa_shops` eigene Domaenen sauber besitzen koennen.

## Core Lifecycle

Die aktuell dokumentierte Foundation-Startreihenfolge steht in `docs/START_GROUPS.md`, `server/foundation.dev.cfg` und `server/resources.dev.cfg.example`:

```cfg
ensure oxmysql
ensure chat
ensure nexa-lib
ensure nexa-core
ensure nexa-character
ensure nexa-identity
ensure nexa-spawn
ensure nexa_config
ensure nexa_locales
ensure nexa_audit
ensure nexa_logs
ensure nexa_featureflags
ensure nexa_permissions
ensure nexa_api
ensure nexa_security
ensure nexa-core-test
ensure nexa-character-test
```

Zur Laufzeit ist der Core-Lifecycle:

1. `oxmysql` wird gestartet.
2. `nexa-core` initialisiert Config, Constants, Datenbank, Permissions, Player, Characters, Callbacks, Events und Exports.
3. Beim Spielerbeitritt sammelt `nexa-core` Identifier, ermittelt den Primaer-Identifier und erstellt oder aktualisiert `nexa_players`.
4. Der Client kann vorhandene Charaktere abfragen.
5. Die Charakterauswahl laeuft serverseitig ueber `nexa:core:server:selectCharacter` oder den Export `SelectCharacter`.
6. Bei Auswahl wird der aktive Charakter gecacht und `nexa:core:client:characterSelected` gesendet.
7. Beim Disconnect oder Unload wird der Charakterzustand entfernt und `nexa:core:client:characterUnloaded` gesendet.

`nexa_api` sitzt als spaetere API-Fassade ueber dem Core und sollte fuer neue Resources die bevorzugte Integrationsschicht sein.

## Oeffentliche API-Grenzen

### nexa-core Exports

`[nexa-core]/nexa-core/server/exports.lua` und `fxmanifest.lua` stellen bereit:

- `GetCoreObject`
- `GetPlayer`
- `GetCharacter`
- `ListCharacters`
- `HasPermission`
- `GetIdentifier`
- `CreateCharacter`
- `SelectCharacter`
- `UpdateCharacter`

Diese Exports sind Core-nah. Neue Domaenen sollten sie nicht direkt fuer komplexe Gameplay-Flows missbrauchen, sondern ueber `nexa_api`, `nexa_permissions` oder spezialisierte Domain-Resources arbeiten.

### nexa_api Exports

`[nexa-core]/nexa_api` bietet die bevorzugte Foundation-API:

- Registry und Resource Contracts.
- Server- und Client-Callbacks mit eindeutiger Request-ID und Timeout.
- Permission-Bridge zu `nexa_permissions` und `nexa-core`.
- Core-Bridges fuer Player, Character und Identifier.

Wichtige Exports:

- `GetApi`
- `RegisterServerCallback`
- `TriggerServerCallback`
- `RegisterClientCallback`
- `TriggerClientCallback`
- `HasPermission`
- `RequirePermission`
- `GetPlayer`
- `GetCharacter`
- `GetIdentifier`

Callbacknamen folgen im modernen Code dem Muster `nexa:<resource>:cb:<action>`.

### nexa_permissions Exports

`[nexa-core]/nexa_permissions` ist das aktuelle Rollen-/Regel-System:

- `Has`
- `HasAny`
- `HasAll`
- `GetRoles`
- `AssignRoleToPlayer`
- `RemoveRoleFromPlayer`
- `ReloadPermissions`
- `GetPermissionCache`

Neue Ressourcen sollten Permission-Checks bevorzugt ueber `nexa_api:HasPermission` oder direkt ueber `nexa_permissions:Has` abwickeln.

### nexa_ui Exports

`[nexa-ui]/nexa_ui` ist die aktuelle UI-Basis ohne ox_lib:

- `open`
- `close`
- `notify`
- `menu`
- `getTheme`
- `getLocale`
- `registerContext`
- `showContext`
- `hideContext`
- `getOpenContextMenu`
- `inputDialog`
- `closeInputDialog`

Neue Client-UI soll diese Exports nutzen statt `lib.notify`, `lib.registerContext`, `lib.showContext` oder `lib.inputDialog`.

## Sicherheitsmodell

Nexa ist serverautoritativ auszubauen. Der aktuelle Core liefert dafuer bereits wichtige Grundlagen:

- `source` wird serverseitig als fluechtige Verbindung behandelt.
- Der dauerhafte Spielerbezug kommt aus serverseitig gelesenen Identifiern.
- Charakterzugriffe werden ueber `player_id` und Besitzpruefung abgesichert.
- Clientdaten werden nicht als autoritative Identitaet oder Permission akzeptiert.
- Core-Callbacks haben Request-IDs, Pending-Status, Timeout und Cooldown.
- `nexa_security` stellt Rate-Limits, Source-Validierung, Rejects, Reports, Ban-Status und Recent-Reports bereit.
- `nexa_permissions` prueft Rollen, Regeln, Wildcards und ACE-Fallbacks.
- Sicherheitsrelevante Ereignisse sollen an `nexa_audit` und `nexa_logs` gehen.

Wichtig: Einige Legacy-Ressourcen nutzen noch ox_lib-Callbacks, direkte Events oder QBCore-Kompatibilitaetsereignisse. Diese muessen auf `nexa_api` und serverseitige Validierung migriert werden.

## Datenbankmodell

### Core Tabellen

Die Core-Dokumentation nennt:

- `nexa_players`
- `nexa_characters`
- `nexa_permissions`
- `nexa_audit_log`

`nexa-core` kapselt DB-Zugriffe intern ueber `Nexa.Database`. Diese Abstraktion ist aktuell nicht als allgemeiner Cross-Resource-DB-Service exportiert.

### Permission Tabellen

`nexa_permissions` besitzt eigene Tabellen und nutzt direkt `oxmysql`, weil die Core-DB-Abstraktion nicht allgemein exportiert ist:

- `nexa_permission_roles`
- `nexa_permission_role_rules`
- `nexa_permission_assignments`

### Moderne Domain Tabellen

Neue Foundations besitzen resource-lokale Datenbankmodule und idempotente Migrationen:

- `nexa_jobscreator`: `organizations`, `organization_grades`, `organization_members`, `organization_modules`
- `nexa_items`: `items`
- `nexa_inventory`: `inventories`, `inventory_items`
- `nexa_shops`: `shops`, `shop_items`

Diese direkte Nutzung von `oxmysql` ist derzeit akzeptabel, wenn die Resource ihre eigene Domaene besitzt. Langfristig sollte eine gemeinsame Nexa-DB-Konvention entstehen, damit Logging, Fehlerformat, Transaktionen und Migrationen einheitlicher werden.

## Eventmodell

Aktuelle Muster:

- Core Client Events: `nexa:core:client:playerLoaded`, `nexa:core:client:characterSelected`, `nexa:core:client:characterUnloaded`
- Core Server Events: `nexa:core:server:selectCharacter`
- Moderne Callbacks: `nexa:<resource>:cb:<action>`
- Resource Events: `nexa:<domain>:<side>:<action>` oder Konstanten in `shared/constants.lua`
- NUI Callbacks in UI-Ressourcen fuer lokale Browserinteraktion

Unerwuenschte Altlasten:

- `QBCore:Server:OnPlayerLoaded`
- `QBCore:Client:OnPlayerLoaded`
- Qbox Spawn-/Apartment-Events in der Kompatibilitaetsresource
- ox_lib Callback-Registrierung und Await-Calls

## Abhaengigkeitsregeln

Zielregeln fuer neue und migrierte Ressourcen:

- Extern erlaubt: `oxmysql` fuer DB, bis eine eigene Nexa-DB-Schicht existiert.
- Extern nicht erlaubt: `ox_lib`, `ox_inventory`, `qbx_core`, `qb-core`, `QBCore`, `es_extended`, `ESX`.
- Client UI: ueber `nexa_ui`.
- Callbacks: ueber `nexa_api`.
- Permissions: ueber `nexa_permissions` oder `nexa_api`.
- Logging/Audit: ueber `nexa_logs` und `nexa_audit`.
- Feature Flags: ueber `nexa_featureflags`.
- Security Checks: ueber `nexa_security`.
- Domain-Zustand bleibt in der jeweiligen Domain-Resource.

## Namenskonventionen

Vorgefundene Konventionen:

- Resource-Namen: `nexa_*`, teilweise `nexa-core`, `nexa-character`, `nexa-spawn`.
- Config-Tabellen: `Nexa<Resource>Config`, zum Beispiel `NexaItemsConfig`.
- Konstanten: `NEXA_*`, zum Beispiel `NEXA_INVENTORY_OWNER_TYPES`.
- Server Exports: PascalCase fuer Domain-APIs, zum Beispiel `CreateItem`, `GetInventory`, `AssignModule`.
- Client/UI Exports: niedrigere camelCase-API, zum Beispiel `notify`, `registerContext`, `inputDialog`.
- Callbacknamen: `nexa:<resource>:cb:<action>`.
- DB JSON-Spalten: `*_json`.
- Response-Objekte: moderne Domain-APIs nutzen `success`, `code`, `message`, `data`, `meta`; `nexa_api` selbst dokumentiert intern `ok`, `data`, `error`.

Die Response-Formate sollten mittelfristig vereinheitlicht werden.

## Git- und Repository-Struktur

Das Repository ist nach Resource-Gruppen strukturiert:

- `[cfx]`
- `[compat]`
- `[nexa-admin]`
- `[nexa-core]`
- `[nexa-criminal]`
- `[nexa-factions]`
- `[nexa-gameplay]`
- `[nexa-housing]`
- `[nexa-ui]`
- `[nexa-vehicles]`
- `[nexa-world]`
- `[ox]`
- `[standalone]`
- `database`
- `docs`
- `server`

Die aktuelle Arbeitskopie enthaelt bereits nicht von dieser Analyse erzeugte geloeschte Dateien unter festen Faction-Resources (`nexa_ems`, `nexa_government`, `nexa_lspd`, `nexa_weazel`). Diese Analyse behandelt sie als vorhandenen Arbeitskopienzustand und aendert sie nicht.

## Bestehende Tests und Validierung

Vorgefunden wurden:

- `[standalone]/nexa-core-test`
- `[standalone]/nexa-character-test`
- `[nexa-core]/nexa-lib/shared/validate.lua`
- Dokumentierte Foundation-Startdateien unter `server/`

Es wurde kein allgemeiner lokaler Test-Runner wie `package.json`, PowerShell-Testscript oder Shell-Testscript fuer das gesamte Repository gefunden. Die Standalone-Testresources benoetigen FXServer-Laufzeit und koennen lokal in dieser Analyse nicht sinnvoll ausgefuehrt werden.

## Aktueller Bewertungsstand

Erhalten bleiben:

- `nexa-core` als Session-/Identifier-/Character-Core.
- `nexa_api` als Callback-, Registry- und API-Fassade.
- `nexa_permissions` als Rollen-/Regel-System.
- `nexa_ui` als ox_lib-freie UI-Basis.
- Neue Foundations `nexa_jobscreator`, `nexa_items`, `nexa_inventory`, `nexa_shops`.

Migriert werden:

- Alle ox_lib-basierten UI-, Callback- und Notify-Nutzungen.
- Alle Qbox/QBCore-Kompatibilitaetsereignisse.
- Alle ox_inventory-Integrationen zu `nexa_inventory`.
- Alte feste Job-/Faction-Logik zu `nexa_jobscreator` und generischen Organisationen.

Ersetzt werden:

- `qbx_core`-Abhaengigkeiten durch `nexa-core`, `nexa_api`, `nexa_permissions` und Domain-APIs.
- `lib.callback` durch `nexa_api` Callbacks.
- `lib.notify`, `lib.registerContext`, `lib.showContext`, `lib.inputDialog` durch `nexa_ui`.
- ox_inventory Stashes/Items durch `nexa_inventory` und `nexa_items`.

Entfernt werden:

- Die Kompatibilitaetsresource `[compat]/nexa_qbox_compat`, sobald keine Runtime-Nutzer mehr existieren.
- `nexa_bootstrap`-Required-Resources fuer `ox_lib`, `qbx_core`, `ox_inventory` und `ox_target`.
- Stale Datenbank- und README-Kompatibilitaetsverweise nach abgeschlossener Migration.
