# Core Migration Plan

Stand: 2026-07-10

Dieses Dokument listet die bei der Repository-Analyse gefundenen Altbestaende und beschreibt, ob sie erhalten, migriert, ersetzt oder entfernt werden sollen. Ziel ist ein reines Nexa-Framework ohne QBCore, Qbox, ESX, ox_lib und ox_inventory. `oxmysql` bleibt vorerst als Datenbankgrundlage erlaubt.

## Entscheidungsregeln

- **Erhalten:** Nexa-eigene Foundation, die bereits ohne Fremdframework arbeitet.
- **Migrieren:** Fachlogik bleibt erhalten, aber UI, Callback, Permission, Inventory oder Framework-Anbindung wird auf Nexa-Systeme umgestellt.
- **Ersetzen:** Fremdframework-Komponente wird durch eine vorhandene Nexa-Resource ersetzt.
- **Entfernen:** Kompatibilitaets- oder Legacy-Code ohne Zielnutzen wird nach Migration der Nutzer geloescht.

## Gefundene Altbestaende

| Fundstelle | Aktueller Zweck | Problem | Empfohlene Massnahme | Risiko | Reihenfolge |
| --- | --- | --- | --- | --- | --- |
| `[nexa-core]/nexa_bootstrap/shared/constants.lua` und `fxmanifest.lua` | Bootstrap prueft Required Resources und Produktionseinstellungen. | Required Resources enthalten `ox_lib`, `qbx_core`, `ox_inventory` und `ox_target`. Dadurch blockiert der Bootstrap die Zielarchitektur. | Required-Liste auf Nexa Foundation reduzieren: `oxmysql`, `nexa-lib`, `nexa-core`, `nexa_config`, `nexa_locales`, `nexa_audit`, `nexa_logs`, `nexa_featureflags`, `nexa_permissions`, `nexa_api`, `nexa_security`, spaeter `nexa_ui` je nach Startgruppe. | Hoch, weil falsche Required Resources den Serverstart abbrechen koennen. | 1 |
| `[compat]/nexa_qbox_compat` | Uebergangsbridge fuer Qbox/QBCore-Events, DB-Kompatibilitaet und Legacy-Verbraucher. | Haelt `ox_lib`, Qbox/QBCore-Ereignisse und Kompatibilitaetsmodell im System. | Nur behalten, solange konkrete Legacy-Verbraucher existieren. Danach vollstaendig entfernen. Vorher alle Nutzer auf Nexa-APIs migrieren. | Hoch bei frueher Entfernung, mittel bei Beibehaltung wegen falscher Architektur-Signale. | 6 |
| `[nexa-gameplay]/nexa_identity` | Legacy Identity-/Spawn-/PlayerLoaded-Flows. | Abhaengigkeit zu `ox_lib` und `qbx_core`; triggert `QBCore:Server:OnPlayerLoaded` und `QBCore:Client:OnPlayerLoaded`. Dupliziert Teile von `[nexa-core]/nexa-identity`. | Identity-Flows auf `nexa-core`, `[nexa-core]/nexa-identity`, `nexa-character` und `nexa-spawn` vereinheitlichen. QBCore-Events entfernen. | Hoch, weil Character-/Spawn-Lifecycle betroffen ist. | 2 |
| `[nexa-gameplay]/nexa_jobs_core` | Altes Jobsystem. | Abhaengigkeit zu `ox_lib` und `qbx_core`; widerspricht generischer JobsCreator-Architektur. | Verbraucher auf `nexa_jobscreator` Organizations, Grades, Members, Duty und Modules migrieren. Danach Resource entfernen oder als reine Datenmigration stilllegen. | Hoch, falls alte Ressourcen Jobs direkt erwarten. | 3 |
| `[nexa-admin]/nexa_admin` | Admin-Menues, Aktionen und Serververwaltung. | Nutzt `ox_lib`, `lib.notify`, Context, InputDialog und `lib.callback`. | UI auf `nexa_ui` Context/Input/Notify migrieren, Callbacks auf `nexa_api`, Permissions auf `nexa_permissions`. | Mittel bis hoch wegen Admin-Berechtigungen. | 4 |
| `[nexa-admin]/nexa_devtools` | Nexa Devtools. | Keine harte Fremdframework-Abhaengigkeit gefunden; nutzt Nexa Foundation. | Erhalten. Bei Bedarf als Diagnosewerkzeug fuer Migrationen ausbauen. | Niedrig. | Erhalten |
| `[nexa-core]/nexa_anticheat` | Anti-Cheat und Sicherheitsvalidierungen. | Manifest nutzt `ox_lib`; Inventory-Modul prueft `ox_inventory` und exportiert `validateOxInventoryAccess`. `esx:` erscheint als verdachtiges Eventmuster, nicht als Runtime-Abhaengigkeit. | ox_lib entfernen, Inventory-Pruefung auf `nexa_inventory` umstellen und Exportnamen langfristig neutralisieren. ESX-Muster als Detection Pattern behalten, wenn es rein defensiv ist. | Hoch wegen Sicherheitswirkung. | 5 |
| `[nexa-gameplay]/nexa_banking` | Banking-Foundation. | Nutzt `ox_lib` und alte Callback-/Notify-Patterns. | Callbacks auf `nexa_api`, UI/Notify auf `nexa_ui`, Permission/Security ueber Nexa. | Mittel. | 4 |
| `[nexa-gameplay]/nexa_business` | Business-System. | Nutzt `ox_lib` und haengt an `nexa_jobs_core`. | Auf `nexa_jobscreator` Organisationen und Module migrieren. | Hoch wegen Jobs-/Business-Verknuepfung. | 5 |
| `[nexa-gameplay]/nexa_dispatch` | Dispatch-System. | Nutzt `ox_lib`. | Als generisches Dispatch-Modul an `nexa_jobscreator` und `nexa_mdt` anbinden; UI/Callbacks migrieren. | Mittel. | 5 |
| `[nexa-gameplay]/nexa_documents` | Dokumente. | Nutzt `ox_lib` und `ox_inventory`. | Dokumentdefinitionen mit `nexa_items` verbinden, Instanzen in `nexa_inventory`, UI auf `nexa_ui`. | Hoch wegen Item-/Dokumentinstanzen. | 5 |
| `[nexa-gameplay]/nexa_licenses` | Lizenzen. | Nutzt `ox_lib` und haengt an `nexa_documents`. | Lizenzen als `nexa_items`/Document-/License-Typen modellieren und Dokument-APIs migrieren. | Mittel. | 5 |
| `[nexa-criminal]/nexa_illegal_core` | Criminal-Basis. | Nutzt `ox_lib`. | Callbacks und UI auf Nexa portieren, Security/Permissions beibehalten. | Mittel. | 4 |
| `[nexa-criminal]/nexa_blackmarket` | Blackmarket-System. | Nutzt `ox_lib`. | Auf `nexa_shops` Shoptyp `blackmarket`, `nexa_items` und `nexa_inventory` ausrichten. | Mittel. | 5 |
| `[nexa-criminal]/nexa_chopshop` | Chopshop-System. | Nutzt `ox_lib`. | Callbacks/UI migrieren; Vehicle- und Reward-Flows auf Nexa-Domaenen ausrichten. | Mittel. | 5 |
| `[nexa-criminal]/nexa_drugs` | Drogen-System. | Nutzt `ox_lib`. | Drogen als `nexa_items` Itemtyp `drug`, Produktion/Crafting spaeter ueber eigene Module. | Mittel. | 5 |
| `[nexa-criminal]/nexa_evidence` | Evidence-System. | Nutzt `ox_lib` und `ox_inventory`. | Evidence Storage auf `nexa_inventory` owner_type `evidence` migrieren; UI/Callbacks auf Nexa. | Hoch wegen Beweismittel-Integritaet. | 5 |
| `[nexa-criminal]/nexa_moneywash` | Moneywash-System. | Nutzt `ox_lib`. | UI/Callbacks migrieren und Economy-Anbindung klaeren. | Mittel. | 5 |
| `[nexa-housing]/nexa_housing` | Housing und Storage. | Nutzt `ox_lib`, `ox_inventory` und Inventory-Stash-Aufrufe. | Storage auf `nexa_inventory` owner_type `storage` oder `container`; UI/Callbacks auf Nexa. | Hoch wegen Storage-Daten. | 5 |
| `[nexa-housing]/nexa_furniture` | Furniture-System. | Nutzt `ox_lib`; README referenziert ox_inventory. | UI/Callbacks migrieren; Furniture Items spaeter ueber `nexa_items`. | Mittel. | 5 |
| `[nexa-ui]/nexa_phone` | Phone UI. | Nutzt noch `ox_lib`, `lib.print`, Callback/Notify-Patterns. | Notify auf `nexa_ui`, Callbacks auf `nexa_api`, Logging auf `print` oder `nexa_logs`; keine ox_lib-Initialisierung. | Mittel. | 4 |
| `[nexa-ui]/nexa_tablet` | Tablet UI. | Nutzt noch `ox_lib` und Callback/UI-Patterns. | Wie Phone migrieren; gemeinsame UI-Konventionen mit `nexa_ui`. | Mittel. | 4 |
| `[nexa-ui]/README.md` | UI-Dokumentation. | Erwaehnt alte minimale ox_lib-Interaktionen fuer Phone/Tablet. | Nach Portierung von Phone/Tablet aktualisieren. | Niedrig. | 7 |
| `[nexa-vehicles]/nexa_fuel` | Fuel-System. | Nutzt `ox_lib`. | Callback/Notify migrieren; Item-/Shop-Anbindung ueber `nexa_items`/`nexa_shops`. | Mittel. | 5 |
| `[nexa-vehicles]/nexa_garage` | Garage-System. | Nutzt `ox_lib`. | Callback/Notify migrieren; Organization-Garagen ueber `nexa_jobscreator` Module anbinden. | Mittel. | 5 |
| `[nexa-vehicles]/nexa_impound` | Impound-System. | Nutzt `ox_lib`. | Callback/Notify migrieren; Police/Government-Zugriffe ueber Organisationsmodule und Permissions. | Mittel. | 5 |
| `[nexa-vehicles]/nexa_vehicledealer` | Vehicle Dealer. | Nutzt `ox_lib`. | Shop-/Economy-Verbindung mit `nexa_shops`; UI/Callbacks migrieren. | Mittel. | 5 |
| `[nexa-vehicles]/nexa_vehiclekeys` | Vehicle Keys. | Nutzt `ox_lib`. | Keys als `nexa_items` Itemtyp `key` und Instanzen in `nexa_inventory` modellieren. | Hoch wegen Besitz-/Zugriffslogik. | 5 |
| `database/migrations/20260707_1200_create_qbox_vehicle_inventory_compat.sql` | Qbox/Vehicle/Inventory-Kompatibilitaet. | Dokumentiert und erzeugt Legacy-Kompatibilitaetsstrukturen. | Nicht fuer neue Installationen erweitern. Nach Migration archivieren oder in Legacy-Migration verschieben. | Mittel. | 7 |
| `database/README.md` | Datenbankdokumentation. | Erwaehnt ox_inventory als Item-/Inventory-Grundlage. | Nach `nexa_inventory`-Ausbau aktualisieren. | Niedrig. | 7 |
| Direkte `MySQL.*`-Aufrufe in mehreren Resources | Resource-lokale DB-Operationen. | Uneinheitliche Fehlerbehandlung, Migrationen und Response-Formate. | Kurzfristig fuer eigene Domaenen erlaubt. Mittelfristig gemeinsame Nexa-DB-Konvention oder exportierte DB-API definieren. | Mittel. | 8 |
| Geloeschte feste Faction-Resources in Arbeitskopie | Ehemalige feste Ressourcen `nexa_lspd`, `nexa_ems`, `nexa_government`, `nexa_weazel`. | Arbeitskopie enthaelt unstaged Deletes. Architekturziel ersetzt sie durch generische Organisationen, aber der aktuelle Git-Zustand braucht separaten Entscheidungs-Commit. | In separatem Cleanup pruefen und committen, nicht mit Core-Analyse vermischen. | Mittel, weil Startconfigs oder Docs noch auf alte Resources zeigen koennten. | Separat |

## Ressourcen, die erhalten bleiben

- `[nexa-core]/nexa-core`
- `[nexa-core]/nexa_api`
- `[nexa-core]/nexa_permissions`
- `[nexa-core]/nexa_config`
- `[nexa-core]/nexa_locales`
- `[nexa-core]/nexa_audit`
- `[nexa-core]/nexa_logs`
- `[nexa-core]/nexa_featureflags`
- `[nexa-core]/nexa_security`
- `[nexa-ui]/nexa_ui`
- `[nexa-ui]/nexa_hud`
- `[nexa-ui]/nexa_mdt`
- `[nexa-world]/nexa_blips`
- `[nexa-world]/nexa_zones`
- `[nexa-world]/nexa_worldstates`
- `[nexa-world]/nexa_maps`
- `[nexa-world]/nexa_interiors`
- `[nexa-world]/nexa_npcs`
- `[nexa-factions]/nexa_factions_core`
- `[nexa-gameplay]/nexa_jobscreator`
- `[nexa-gameplay]/nexa_items`
- `[nexa-gameplay]/nexa_inventory`
- `[nexa-gameplay]/nexa_shops`

Diese Ressourcen sind entweder bereits Nexa-native oder als neue Foundation angelegt. Einzelne direkte `oxmysql`-Nutzungen sind in Domain-DB-Modulen derzeit akzeptiert.

## Migrationsreihenfolge

1. **Bootstrap bereinigen**
   - `nexa_bootstrap` darf keine nicht mehr gewollten Fremdframeworks erzwingen.
   - Ziel: Server kann ohne `ox_lib`, `qbx_core`, `ox_inventory`, `ox_target` starten.

2. **Identity und Spawn vereinheitlichen**
   - Legacy `[nexa-gameplay]/nexa_identity` gegen `[nexa-core]/nexa-identity`, `nexa-character` und `nexa-spawn` abgleichen.
   - QBCore PlayerLoaded-Events entfernen.

3. **Jobs und Organisationen migrieren**
   - `nexa_jobs_core` durch `nexa_jobscreator` ersetzen.
   - Alte feste Job-/Faction-Annahmen auf Organisationstyp, MDT-Type, Grades, Members und Modules abbilden.

4. **ox_lib UI-/Callback-Nutzer portieren**
   - Admin, Phone, Tablet, Banking, Illegal Core und weitere Ressourcen auf `nexa_ui` und `nexa_api`.
   - Muster: `lib.notify` -> `exports.nexa_ui:notify`, `lib.callback` -> `exports.nexa_api`, Context/Input -> `nexa_ui`.

5. **Inventory-Migration**
   - `ox_inventory`-Abhaengigkeiten in Evidence, Documents, Housing, Anticheat und Datenbank-Dokumentation auf `nexa_inventory` und `nexa_items` umstellen.

6. **Qbox/QBCore-Kompatibilitaet entfernen**
   - `[compat]/nexa_qbox_compat` entfernen, sobald keine Nutzer mehr existieren.
   - Qbox/QBCore-Events und Compatibility Views nicht weiter pflegen.

7. **Dokumentation und Datenbank-Altlasten bereinigen**
   - READMEs aktualisieren.
   - Legacy-Migrationen kennzeichnen oder archivieren.
   - Startgruppen auf Zielzustand bringen.

8. **DB-Konvention vereinheitlichen**
   - Gemeinsame Migration-/Response-/Fehlerkonvention definieren.
   - Optional zentrale DB-API oder Library entwickeln, ohne Domain-Besitz zu vermischen.

## Risiken

- **Startabbruch durch Bootstrap:** Solange `nexa_bootstrap` alte Required Resources erwartet, kann ein ox_lib-/Qbox-freier Server trotz migrierter Resources fehlschlagen.
- **Doppelter Identity-Pfad:** `[nexa-core]/nexa-identity` und `[nexa-gameplay]/nexa_identity` muessen sauber getrennt oder zusammengefuehrt werden.
- **Legacy Event Consumers:** Entfernen von QBCore/Qbox-Events kann unbekannte alte Verbraucher brechen.
- **Inventory-Datenverlust:** ox_inventory-Stashes duerfen erst ersetzt werden, wenn Datenmigration und Besitzmodell fuer `nexa_inventory` feststehen.
- **Permission-Split:** `nexa-core` besitzt einfache Permissions, `nexa_permissions` besitzt Rollen/Regeln. Neue Ressourcen sollten nicht beide Modelle direkt mischen.
- **Response-Format-Split:** `nexa_api` dokumentiert `ok/data/error`, neue Domain-APIs nutzen `success/code/message/data/meta`.
- **Arbeitskopien-Deletes:** Die geloeschten festen Faction-Resources muessen separat bewertet werden, damit kein unbeabsichtigter Cleanup in Architektur-Commits landet.

## Zielzustand

Nach Abschluss der Migration gilt:

- Kein Resource-Manifest ausser `[ox]/oxmysql` referenziert unerwuenschte Fremdframeworks.
- `rg "ox_lib|@ox_lib|lib\\."` findet in Nexa-Resources keine produktive Abhaengigkeit.
- `rg "qbx_core|qb-core|QBCore|es_extended|ESX"` findet keine Runtime-Abhaengigkeit ausser erlaubten defensiven Detection-Patterns.
- Alle UI-Beduerfnisse laufen ueber `nexa_ui`.
- Alle Cross-Resource-Callbacks laufen ueber `nexa_api`.
- Alle Rechte laufen ueber `nexa_permissions` oder `nexa_api`.
- Alle Item-/Inventory-Flows laufen ueber `nexa_items` und `nexa_inventory`.
- Jobs, Fraktionen, Gangs, Businesses und Organisationen laufen generisch ueber `nexa_jobscreator`.
