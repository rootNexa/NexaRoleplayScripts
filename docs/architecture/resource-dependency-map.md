# Resource Dependency Map

Stand: 2026-07-10

Dieses Dokument bildet die relevanten Ressourcen, direkten Abhaengigkeiten, indirekten Foundation-Abhaengigkeiten, Startreihenfolge und unerlaubten Framework-Abhaengigkeiten im aktuellen Repository ab.

## Methodik

Analysiert wurden:

- `README.md`
- `docs/START_GROUPS.md`
- `server/foundation.dev.cfg`
- `server/resources.dev.cfg.example`
- alle auffindbaren `fxmanifest.lua`
- Core-READMEs und API-Dokumente
- Suchen nach `qbx`, `qb-core`, `qbcore`, `QBCore`, `es_extended`, `ESX`, `ox_lib`, `@ox_lib`, `lib.`, `ox_inventory`, `RegisterNetEvent`, `AddEventHandler`, `exports`, ACE- und Identifier-Mustern

Der vendored/infrastrukturartige Ordner `[ox]/oxmysql` wird als erlaubte externe DB-Grundlage behandelt. Andere ox-, Qbox-, QBCore- oder ESX-Bezuege gelten als Migrationsthema, sofern sie nicht rein defensives Anti-Cheat-Pattern sind.

## Foundation Startreihenfolge

Aktuell dokumentiert fuer den Foundation-Dev-Stack:

```cfg
ensure oxmysql
ensure chat
ensure nexa-lib
ensure nexa-core
ensure nexa_identity
ensure nexa_characters
ensure nexa_playerstate
ensure nexa_items
ensure nexa_inventory
ensure nexa_economy
ensure nexa_organizations
ensure nexa_jobs
ensure nexa_payroll
ensure nexa_billing
ensure nexa-character
ensure nexa-identity
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

Ziel fuer produktive Nexa-Foundation:

```cfg
ensure oxmysql
ensure chat
ensure nexa-lib
ensure nexa_config
ensure nexa_locales
ensure nexa_audit
ensure nexa_logs
ensure nexa-core
ensure nexa_identity
ensure nexa_characters
ensure nexa_playerstate
ensure nexa-character
ensure nexa-identity
ensure nexa_featureflags
ensure nexa_permissions
ensure nexa_api
ensure nexa_security
ensure nexa_ui
ensure nexa_items
ensure nexa_inventory
ensure nexa_economy
ensure nexa_organizations
ensure nexa_jobs
ensure nexa_payroll
ensure nexa_billing
ensure nexa_jobscreator
ensure nexa_shops
```

Die exakte Reihenfolge sollte vor Aenderung an `server.cfg` oder systemd separat validiert werden. Der Dev-Stack startet `nexa_playerstate` nach `nexa_characters`, danach `nexa_items` und `nexa_inventory`, und erst anschliessend die Legacy-Core-Bridge-Ressourcen. `nexa-spawn` bleibt im Repository, wird aber in der Foundation-Dev-Reihenfolge nicht mehr gestartet.

## Core und Foundation Ressourcen

| Resource | Direkte Abhaengigkeiten | Indirekte Abhaengigkeiten | Bewertung |
| --- | --- | --- | --- |
| `[ox]/oxmysql` | keine Nexa-Abhaengigkeit | MariaDB | Erlaubte externe DB-Grundlage. |
| `[cfx]/[gameplay]/chat` | CFX | keine | Foundation/Komfort. |
| `[nexa-core]/nexa-lib` | keine | keine | Erhalten als Shared Utility/Validation-Layer. |
| `[nexa-core]/nexa_config` | keine | keine | Erhalten. |
| `[nexa-core]/nexa_locales` | `nexa_config` | keine | Erhalten. |
| `[nexa-core]/nexa_audit` | `oxmysql`, `nexa_config` | MariaDB | Erhalten; direkte DB-Nutzung ist eigene Domaene. |
| `[nexa-core]/nexa_logs` | `nexa_config`, `nexa_locales`, `nexa_audit` | `oxmysql` ueber audit | Erhalten. Keine erkennbare Zyklik. |
| `[nexa-core]/nexa-core` | `oxmysql` | MariaDB | Erhalten als Session-/Identifier-/Character-Core. |
| `[nexa-core]/nexa-character` | Core-nahe Character-Foundation | `nexa-core` fachlich | Erhalten, Manifest nochmals gegen dokumentierte Startreihenfolge pruefen. |
| `[nexa-core]/nexa-identity` | `nexa-core`, `nexa-character` | `oxmysql` ueber core | Erhalten als Core-Identity-Schicht. |
| `[nexa-gameplay]/nexa_playerstate` | `nexa-core`, `nexa_identity`, `nexa_characters` | MariaDB ueber Core-Database | Neuer autoritativer Gameplay-Lifecycle- und Spawn-Owner. |
| `[nexa-gameplay]/nexa-spawn` | Core-nahe Spawn-Foundation | `nexa-core` fachlich | Deprecated Dev-Helfer; nicht parallel zu `nexa_playerstate` starten. |
| `[nexa-core]/nexa_featureflags` | `oxmysql`, `nexa_config` | MariaDB | Erhalten. |
| `[nexa-core]/nexa_permissions` | `oxmysql`, `nexa-lib`, `nexa-core` | MariaDB | Erhalten als Rollen-/Regel-System. |
| `[nexa-core]/nexa_api` | `nexa-lib`, `nexa-core` | `nexa_permissions` optional ueber exports | Erhalten als bevorzugte Callback-/API-Fassade. |
| `[nexa-core]/nexa_security` | `nexa_config`, `nexa_logs`, `nexa_audit` | audit/log stack | Erhalten. |
| `[nexa-core]/nexa_bootstrap` | `ox_lib`, `oxmysql`, `qbx_core`, Nexa Foundation | Qbox/ox stack | Migrieren: Required Resources enthalten unerlaubte Frameworks. |
| `[nexa-core]/nexa_anticheat` | `ox_lib`, `oxmysql`, Nexa Foundation | `ox_inventory` in Modulbezug | Migrieren: ox_lib entfernen, Inventory-Pruefung auf `nexa_inventory`. |

## UI Ressourcen

| Resource | Direkte Abhaengigkeiten | Indirekte Abhaengigkeiten | Bewertung |
| --- | --- | --- | --- |
| `[nexa-ui]/nexa_ui` | `nexa_config`, `nexa_locales` | keine | Erhalten. Liefert Notify, Panel, Context und InputDialog ohne ox_lib. |
| `[nexa-ui]/nexa_hud` | `nexa_ui`, `nexa_api` | `nexa-core` | Erhalten. Bereits ox_lib-frei. |
| `[nexa-ui]/nexa_mdt` | `nexa_ui`, `nexa_api`, `nexa_security`, `nexa_permissions` | `nexa-core` | Erhalten. Als generisches MDT vorbereitet. |
| `[nexa-ui]/nexa_phone` | `ox_lib`, `nexa_ui`, `nexa_api`, `nexa_security` | Nexa Foundation | Migrieren: ox_lib Callback/Notify/Print entfernen. |
| `[nexa-ui]/nexa_tablet` | `ox_lib`, `nexa_ui`, `nexa_api`, `nexa_permissions` | Nexa Foundation | Migrieren: ox_lib entfernen. |

## Gameplay Ressourcen

| Resource | Direkte Abhaengigkeiten | Indirekte Abhaengigkeiten | Bewertung |
| --- | --- | --- | --- |
| `[nexa-gameplay]/nexa_jobscreator` | `oxmysql`, `nexa_api`, `nexa_logs` | `nexa-core` | Erhalten. Neue Organisations-, Grade-, Member- und Module-Foundation. |
| `[nexa-gameplay]/nexa_items` | `nexa-core`, `nexa_permissions`, `nexa_api`, `nexa_ui` | MariaDB ueber Core-Database | Erhalten. Zentrale Item Registry und Item Studio Domain Foundation ohne direkte oxmysql-Nutzung. |
| `[nexa-gameplay]/nexa_inventory` | `nexa-core`, `nexa_identity`, `nexa_characters`, `nexa_playerstate`, `nexa_permissions`, `nexa_api`, `nexa_items` | `nexa_items` als Itemdefinitionsquelle | Erhalten. Serverautoritative Inventory-Foundation ohne direkte oxmysql-Nutzung. |
| `[nexa-gameplay]/nexa_economy` | `nexa-core`, `nexa_api`, `nexa_characters`, `nexa_playerstate`, `nexa_items`, `nexa_inventory` | `nexa_items`/`nexa_inventory` fuer Cash und Dirty Cash | Erhalten. Serverautoritative Accounts-, Ledger-, Transaction- und Cash-Integration ohne direkte oxmysql-Nutzung. |
| `[nexa-gameplay]/nexa_organizations` | `nexa-core`, `nexa_identity`, `nexa_characters`, `nexa_permissions`, `nexa_economy`, `nexa_inventory` | Core-Database, Economy und Inventory | Neu. Autoritative Organization-, Rank-, Membership-, Module-, Storage- und Garage-Foundation. |
| `[nexa-gameplay]/nexa_jobs` | `nexa-core`, `nexa_characters`, `nexa_playerstate`, `nexa_organizations`, `nexa_permissions` | Organizations als Membership-Quelle | Neu. Source-gebundener Job-Lifecycle und Duty-Foundation. |
| `[nexa-gameplay]/nexa_payroll` | `nexa-core`, `nexa_characters`, `nexa_jobs`, `nexa_organizations`, `nexa_economy`, `nexa_permissions` | Jobs-Duty, Organizations, Economy | Neu. Gehaltsrichtlinien, Perioden, Duty-Zeit, Payroll-Runs und Economy-Auszahlung. |
| `[nexa-gameplay]/nexa_billing` | `nexa-core`, `nexa_characters`, `nexa_organizations`, `nexa_economy`, `nexa_permissions`, `nexa_playerstate` | Organizations und Economy | Neu. Rechnungen, Positionen, Zahlungen, Storno, Gutschrift und Overdue-Foundation. |
| `[nexa-gameplay]/nexa_shops` | `oxmysql`, `nexa_api`, `nexa_logs` | `nexa_items` fachlich vorbereitet | Erhalten. Shop-Foundation. |
| `[nexa-gameplay]/nexa_banking` | `ox_lib`, `nexa_api`, `nexa_audit`, `nexa_security` | Nexa Foundation | Migrieren. |
| `[nexa-gameplay]/nexa_business` | `ox_lib`, `nexa_jobs_core`, `nexa_api`, `nexa_audit` | Legacy Jobs | Migrieren auf `nexa_jobscreator`. |
| `[nexa-gameplay]/nexa_dispatch` | `ox_lib`, `nexa_api`, `nexa_audit`, `nexa_security` | Nexa Foundation | Migrieren. |
| `[nexa-gameplay]/nexa_documents` | `ox_lib`, `ox_inventory`, `nexa_api`, `nexa_identity` | Legacy inventory | Migrieren auf `nexa_items`/`nexa_inventory`. |
| `[nexa-gameplay]/nexa_identity` | `ox_lib`, `oxmysql`, `qbx_core`, `nexa_api`, `nexa_security` | Qbox/legacy identity | Ersetzen durch Core-Identity-Flows. |
| `[nexa-gameplay]/nexa_jobs_core` | `ox_lib`, `qbx_core`, `nexa_api`, `nexa_audit` | Qbox/legacy jobs | Ersetzen durch `nexa_jobscreator`. |
| `[nexa-gameplay]/nexa_licenses` | `ox_lib`, `nexa_api`, `nexa_documents`, `nexa_permissions` | Documents | Migrieren auf Nexa documents/items model. |

## Factions Ressourcen

| Resource | Direkte Abhaengigkeiten | Indirekte Abhaengigkeiten | Bewertung |
| --- | --- | --- | --- |
| `[nexa-factions]/nexa_factions_core` | `nexa_api`, `nexa_ui`, `nexa_featureflags`, `nexa_audit`, `nexa_logs`, `nexa_security`, `nexa_permissions` | Nexa Foundation | Erhalten. Bereits ox_lib-frei. |
| `[nexa-factions]/nexa_lspd` | aktuell in Arbeitskopie geloescht | alte feste Police-Resource | Separat bewerten; Zielarchitektur ersetzt feste Factions durch `nexa_jobscreator`. |
| `[nexa-factions]/nexa_ems` | aktuell in Arbeitskopie geloescht | alte feste EMS-Resource | Separat bewerten. |
| `[nexa-factions]/nexa_government` | aktuell in Arbeitskopie geloescht | alte feste Government-Resource | Separat bewerten. |
| `[nexa-factions]/nexa_weazel` | aktuell in Arbeitskopie geloescht | alte feste Media-Resource | Separat bewerten. |

## Criminal Ressourcen

| Resource | Direkte Abhaengigkeiten | Indirekte Abhaengigkeiten | Bewertung |
| --- | --- | --- | --- |
| `[nexa-criminal]/nexa_illegal_core` | `ox_lib`, `nexa_api`, `nexa_security`, `nexa_permissions` | Nexa Foundation | Migrieren. |
| `[nexa-criminal]/nexa_blackmarket` | `ox_lib`, `nexa_illegal_core`, `nexa_api`, `nexa_security` | Criminal Core | Migrieren; langfristig mit `nexa_shops` verbinden. |
| `[nexa-criminal]/nexa_chopshop` | `ox_lib`, `nexa_illegal_core`, `nexa_api`, `nexa_security` | Criminal Core | Migrieren. |
| `[nexa-criminal]/nexa_drugs` | `ox_lib`, `nexa_illegal_core`, `nexa_api`, `nexa_security` | Criminal Core | Migrieren; Items als `drug`. |
| `[nexa-criminal]/nexa_evidence` | `ox_lib`, `ox_inventory`, `nexa_api`, `nexa_featureflags` | Legacy inventory | Migrieren auf `nexa_inventory` owner_type `evidence`. |
| `[nexa-criminal]/nexa_moneywash` | `ox_lib`, `nexa_illegal_core`, `nexa_api`, `nexa_security` | Criminal Core | Migrieren. |

## World Ressourcen

| Resource | Direkte Abhaengigkeiten | Indirekte Abhaengigkeiten | Bewertung |
| --- | --- | --- | --- |
| `[nexa-world]/nexa_blips` | `nexa_api`, `nexa_featureflags`, `nexa_security` | Nexa Foundation | Erhalten. Bereits ox_lib-frei. |
| `[nexa-world]/nexa_zones` | `nexa_api`, `nexa_featureflags`, `nexa_security` | Nexa Foundation | Erhalten. Eigenes Nexa-Zone-System. |
| `[nexa-world]/nexa_worldstates` | `nexa_api`, `nexa_featureflags`, `nexa_security` | Nexa Foundation | Erhalten. |
| `[nexa-world]/nexa_maps` | `nexa_api`, `nexa_featureflags`, `nexa_security` | Nexa Foundation | Erhalten. |
| `[nexa-world]/nexa_interiors` | `nexa_api`, `nexa_featureflags`, `nexa_security` | Nexa Foundation | Erhalten. |
| `[nexa-world]/nexa_npcs` | `nexa_api`, `nexa_featureflags`, `nexa_security` | Nexa Foundation | Erhalten. |

## Vehicle Ressourcen

| Resource | Direkte Abhaengigkeiten | Indirekte Abhaengigkeiten | Bewertung |
| --- | --- | --- | --- |
| `[nexa-vehicles]/nexa_fuel` | `ox_lib`, `nexa_api`, `nexa_security`, `nexa_audit` | Nexa Foundation | Migrieren. |
| `[nexa-vehicles]/nexa_garage` | `ox_lib`, `nexa_api`, `nexa_security`, `nexa_audit` | Nexa Foundation | Migrieren. |
| `[nexa-vehicles]/nexa_impound` | `ox_lib`, `nexa_api`, `nexa_security`, `nexa_audit` | Nexa Foundation | Migrieren. |
| `[nexa-vehicles]/nexa_vehicledealer` | `ox_lib`, `nexa_api`, `nexa_security`, `nexa_audit` | Nexa Foundation | Migrieren; Shop/Economy-Anbindung klaeren. |
| `[nexa-vehicles]/nexa_vehiclekeys` | `ox_lib`, `nexa_api`, `nexa_security`, `nexa_audit` | Nexa Foundation | Migrieren; Keys als Items/Inventory-Instanzen modellieren. |

## Housing Ressourcen

| Resource | Direkte Abhaengigkeiten | Indirekte Abhaengigkeiten | Bewertung |
| --- | --- | --- | --- |
| `[nexa-housing]/nexa_housing` | `ox_lib`, `ox_inventory`, `nexa_api`, `nexa_security` | Legacy inventory | Migrieren auf `nexa_inventory` Storage/Container. |
| `[nexa-housing]/nexa_furniture` | `ox_lib`, `nexa_api`, `nexa_security`, `nexa_audit` | Nexa Foundation | Migrieren. |

## Admin, Compat und Standalone

| Resource | Direkte Abhaengigkeiten | Indirekte Abhaengigkeiten | Bewertung |
| --- | --- | --- | --- |
| `[nexa-admin]/nexa_admin` | `ox_lib`, `nexa_api`, `nexa_featureflags`, `nexa_security` | Nexa Foundation | Migrieren. |
| `[nexa-admin]/nexa_devtools` | `nexa_config`, `nexa_logs`, `nexa_audit`, `nexa_api` | Nexa Foundation | Erhalten. |
| `[compat]/nexa_qbox_compat` | `oxmysql`, `ox_lib` | Qbox/QBCore Compatibility | Entfernen, sobald keine Legacy-Nutzer mehr existieren. |
| `[standalone]/nexa-core-test` | `nexa-core` fachlich | FXServer | Testresource behalten. |
| `[standalone]/nexa-character-test` | `nexa-core`, `nexa-character` | FXServer | Testresource behalten. |

## Direkte Datenbankzugriffe

Direkte `MySQL.*`-Nutzung wurde in mehreren Ressourcentypen gefunden:

- Core-nahe Ressourcen: `nexa-core`, `nexa_permissions`, `nexa_audit`, `nexa_featureflags`
- Sicherheitsressourcen: `nexa_anticheat`
- Moderne Domain-Foundations: `nexa_jobscreator`, `nexa_items`, `nexa_inventory`, `nexa_shops`
- Kompatibilitaet: `nexa_qbox_compat`
- Legacy Gameplay je nach Resource

Bewertung:

- Fuer eigene Domain-Tabellen ist direkte `oxmysql`-Nutzung aktuell akzeptabel.
- Cross-Resource-Datenzugriffe sollten ueber Exports/Callbacks erfolgen.
- Neue Ressourcen sollten nicht fremde Tabellen direkt beschreiben.
- Eine spaetere gemeinsame Nexa-DB-Konvention sollte Migrationen, JSON-Encoding, Response-Formate, Fehlerlogging und Transaktionen vereinheitlichen.

## Identifier- und Session-Logik

Primaere Identifier-Logik liegt in `[nexa-core]/nexa-core/server/players.lua`:

- `GetPlayerIdentifiers(source)`
- Prioritaet aus `Nexa.Config.identifierPriority`
- Caches `Nexa.Players.bySource` und `Nexa.Players.byIdentifier`
- DB-Tabelle `nexa_players`
- `playerDropped` entlaedt Character und Session

Character-Session-Logik liegt in `[nexa-core]/nexa-core/server/characters.lua`:

- `ListCharacters`
- `CreateCharacter`
- `SelectCharacter`
- `UpdateCharacter`
- `UnloadCharacter`
- Besitzpruefung ueber `player_id`

Neue Ressourcen sollen diese Logik nicht duplizieren.

## Permission-Systeme

Aktuell existieren zwei Ebenen:

1. `nexa-core` einfache Permission-Fallbacks ueber ACE und `nexa_permissions`-Tabelle.
2. `nexa_permissions` als Rollen-/Regel-System mit Rollen, Wildcards, Assignments, ACE-Fallbacks und Cache.

Zielregel:

- Neue Resources nutzen `nexa_api:HasPermission` oder `nexa_permissions:Has`.
- `nexa-core:HasPermission` bleibt Fallback fuer Core-nahe Pfade.
- Permissions werden serverseitig geprueft.

## Events und Exports

Wichtige Event-/Export-Muster:

- Core Events: `nexa:core:client:*`, `nexa:core:server:*`
- Moderne Callbacks: `nexa:<resource>:cb:<action>`
- UI NUI Callbacks: zum Beispiel `contextSelect`, `inputSubmit`, `inputCancel`
- Backend Exports: PascalCase Domain-APIs
- UI Exports: `notify`, `registerContext`, `inputDialog` und weitere clientseitige Helfer

Unerwuenschte Event-Muster:

- `QBCore:*`
- Qbox-spezifische Spawn-/Apartment-Events
- `lib.callback.register`
- `lib.callback.await`

## Moegliche zyklische Abhaengigkeiten

Keine harte technische Zyklik wurde in den bereits modernisierten Foundation-Ressourcen bestaetigt. Beobachtete Risikopunkte:

- `nexa_api` haengt direkt an `nexa-core`, delegiert Permissions aber optional an `nexa_permissions`. Da `nexa_permissions` nicht an `nexa_api` haengt, ist das derzeit keine Zyklik.
- `nexa_logs` haengt an `nexa_audit`; `nexa_audit` haengt nicht an `nexa_logs`. Keine Zyklik.
- `nexa_ui` haengt nur an Config/Locales; UI-Verbraucher haengen an `nexa_ui`. Keine Zyklik.
- `nexa_business` haengt an `nexa_jobs_core`. Wenn `nexa_jobs_core` entfernt wird, muss `nexa_business` vorher migriert werden.
- `nexa_documents` und `nexa_licenses` bilden eine fachliche Kette. Dokumente muessen vor Lizenzen neu modelliert werden.

## Unerlaubte Framework-Abhaengigkeiten

### qbx_core

Gefunden in:

- `[nexa-core]/nexa_bootstrap`
- `[nexa-gameplay]/nexa_jobs_core`
- `[nexa-gameplay]/nexa_identity`
- `[compat]/nexa_qbox_compat` als Kompatibilitaetszweck

Massnahme: ersetzen durch Nexa Core/API/JobsCreator/Identity.

### QBCore / qb-core

Gefunden als Runtime- oder Kompatibilitaetsereignis in:

- `[nexa-gameplay]/nexa_identity/client/events.lua`
- `[compat]/nexa_qbox_compat`

Massnahme: PlayerLoaded-/Spawn-/Identity-Flows auf Nexa Events umstellen.

### ox_lib

Gefunden in:

- `[compat]/nexa_qbox_compat`
- `[nexa-admin]/nexa_admin`
- `[nexa-core]/nexa_anticheat`
- `[nexa-core]/nexa_bootstrap`
- `[nexa-criminal]/nexa_blackmarket`
- `[nexa-criminal]/nexa_chopshop`
- `[nexa-criminal]/nexa_drugs`
- `[nexa-criminal]/nexa_evidence`
- `[nexa-criminal]/nexa_illegal_core`
- `[nexa-criminal]/nexa_moneywash`
- `[nexa-gameplay]/nexa_banking`
- `[nexa-gameplay]/nexa_business`
- `[nexa-gameplay]/nexa_dispatch`
- `[nexa-gameplay]/nexa_documents`
- `[nexa-gameplay]/nexa_identity`
- `[nexa-gameplay]/nexa_jobs_core`
- `[nexa-gameplay]/nexa_licenses`
- `[nexa-housing]/nexa_furniture`
- `[nexa-housing]/nexa_housing`
- `[nexa-ui]/nexa_phone`
- `[nexa-ui]/nexa_tablet`
- `[nexa-vehicles]/nexa_fuel`
- `[nexa-vehicles]/nexa_garage`
- `[nexa-vehicles]/nexa_impound`
- `[nexa-vehicles]/nexa_vehicledealer`
- `[nexa-vehicles]/nexa_vehiclekeys`

Massnahme: Notify/Context/Input auf `nexa_ui`, Callback auf `nexa_api`, Print auf `print` oder `nexa_logs`.

### ox_inventory

Gefunden in:

- `[nexa-core]/nexa_anticheat`
- `[nexa-criminal]/nexa_evidence`
- `[nexa-gameplay]/nexa_documents`
- `[nexa-housing]/nexa_housing`
- `database/README.md`
- `database/migrations/20260707_1200_create_qbox_vehicle_inventory_compat.sql`

Massnahme: auf `nexa_inventory` und `nexa_items` migrieren.

### ESX

Kein produktiver ESX-Framework-Pfad wurde bestaetigt. `esx:` wurde in Anti-Cheat-Konfiguration als verdachtiges Eventmuster gefunden. Das kann als defensives Detection Pattern bleiben, solange keine ESX Runtime-Abhaengigkeit entsteht.

## Validierungsressourcen

Vorgefundene Validierungs-/Testressourcen:

- `[standalone]/nexa-core-test`
- `[standalone]/nexa-character-test`
- `[nexa-core]/nexa-lib/shared/validate.lua`

Es wurde kein allgemeiner lokaler Testbefehl fuer das komplette Repository gefunden. FXServer-Starttests bleiben fuer Runtime-Validierung notwendig.

## Chapter 05 Player State

`nexa_playerstate` is the gameplay lifecycle owner.

Direct dependencies:

- `nexa-core`
- `nexa_identity`
- `nexa_characters`

Allowed downstream dependency:

- `nexa_admin -> nexa_playerstate`

Forbidden dependencies:

- `nexa-core -> nexa_playerstate`
- `nexa_identity -> nexa_playerstate`
- `nexa_characters -> nexa_playerstate`

`nexa-spawn` remains a deprecated development helper and must not be treated as the production spawn lifecycle owner.
