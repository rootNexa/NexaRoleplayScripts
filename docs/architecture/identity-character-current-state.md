# Identity and Character Current State

Stand: 2026-07-10

Dieses Dokument beschreibt den Ist-Zustand fuer Kapitel 02: Accounts, Identitaet und Charaktere. Es ist bewusst eine Bestandsaufnahme vor der Migration.

## Kurzbefund

Der aktuelle Stand enthaelt drei relevante Schichten:

- `[nexa-core]/nexa-core`: besitzt technische Sessions, Player-Registrierung, Identifier-Erfassung, Account-aehnliche Tabelle `nexa_players` und die eigentliche Character-Fachlogik.
- `[nexa-core]/nexa-character`: ist aktuell ein Wrapper um `nexa-core` Character-Exports. Die Resource validiert teilweise Eingaben und stellt eigene Exports/Events bereit, speichert aber nicht selbst.
- `[nexa-core]/nexa-identity`: ist aktuell ein minimaler NUI-Character-Flow und ruft `nexa-character` auf.

Zusätzlich existiert `[nexa-gameplay]/nexa_identity`. Diese Resource ist nicht Teil der aktuell sauberen Foundation und enthaelt noch verbotene Altlasten:

- Dependency `ox_lib`
- Dependency `oxmysql`
- Dependency `qbx_core`
- `@ox_lib/init.lua`
- `lib.callback.register(...)`
- Client-Code mit `TriggerServerEvent('QBCore:Server:OnPlayerLoaded')`

Diese Gameplay-Identity darf fuer Kapitel 02 nicht als Zielgrundlage uebernommen werden, bevor sie vollstaendig bereinigt oder ersetzt wurde.

## Startreihenfolge

`server/foundation.dev.cfg` startet aktuell:

```cfg
ensure oxmysql
ensure chat
ensure nexa-lib
ensure nexa-core
ensure nexa_identity
ensure nexa_characters
ensure nexa_playerstate
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

Die Core-Abhaengigkeitsrichtung ist aktuell nicht sauber getrennt, weil Character-Fachlogik im Core liegt und `nexa-character` nur an den Core delegiert.

## Account- und Identifier-Logik

### Aktueller Besitzer

`[nexa-core]/nexa-core/server/sessions.lua`:

- erstellt Runtime-Sessions
- liest FiveM-Identifier
- normalisiert Identifier
- verwirft IP-Identifier fuer die permanente Identifierliste
- verlangt `license` oder `license2`
- maskiert IP und Identifier fuer Logs

`[nexa-core]/nexa-core/server/players.lua`:

- erstellt/aktualisiert `nexa_players`
- verwendet `session.license` als primaeren Identifier
- setzt `identifier_type`
- speichert `display_name`
- haelt `bySource` und `byIdentifier`
- setzt `activeCharacterId`

### Datenmodell

Core-Migration `001_foundation` erstellt:

- `nexa_players`
  - `id`
  - `identifier`
  - `identifier_type`
  - `display_name`
  - `last_seen_at`
  - `created_at`
  - `updated_at`
- `nexa_characters`
- `nexa_permissions`
- `nexa_audit_log`

Es gibt noch kein getrenntes Account-/Identifier-Modell. `nexa_players` ist derzeit Account-aehnlich, aber fachlich mit Verbindung, Account und Character-Auswahl vermischt.

## Session-Logik

`Nexa.Sessions` ist in Kapitel 01 bereits technisch sauber angelegt:

- Zustaende: `connecting`, `authenticated`, `active`, `dropping`, `closed`, `rejected`
- Source-Bindung
- Session-ID
- License-Pflicht
- Reconnect-Behandlung
- IP nur maskiert in Session-Metadaten
- EventBus-Events `nexa:internal:session:created` und `nexa:internal:session:removed`

Offen ist die Trennung von Session und Account: `Players.Register` erzeugt direkt den Account-aehnlichen Datensatz und verbindet ihn mit der Session.

## Character-Logik im Core

`[nexa-core]/nexa-core/server/characters.lua` besitzt derzeit:

- `Nexa.Characters.List(source)`
- `Nexa.Characters.Create(source, data)`
- `Nexa.Characters.GetByIdForPlayer(playerId, characterId)`
- `Nexa.Characters.Select(source, characterId)`
- `Nexa.Characters.Update(source, data)`
- `Nexa.Characters.GetActive(source)`
- `Nexa.Characters.Unload(source)`
- `Nexa.Characters.activeBySource`

Sicherheitspositiv:

- Character-Auswahl prueft `WHERE id = ? AND player_id = ?`.
- Client kann keine `player_id` fuer Create setzen.
- fehlgeschlagene Select-/Update-Versuche werden auditiert.

Migrationsproblem:

- Core validiert Character-Felder.
- Core schreibt `nexa_characters`.
- Core verwaltet aktiven Character.
- Core sendet Character-Clientevents.
- Core besitzt damit Character-Fachlogik, die in Kapitel 02 in `nexa_characters` gehoert.

## Core-Exports

| Export | Aktueller Besitzer | Aktuelle Aufrufer | Gewuenschter Besitzer | Migrationsrisiko | Kompatibilitaetsstrategie | Teststrategie |
| --- | --- | --- | --- | --- | --- | --- |
| `GetPlayer` | `nexa-core` | `nexa_api`, `nexa_permissions`, Tests, Gameplay-Resources indirekt | `nexa-core` | niedrig | behalten | invalid source, ready-state, public payload |
| `GetCharacter` | `nexa-core` | `nexa_api`, `nexa_permissions`, `nexa-character`, `nexa_hud`, Tests | `nexa_characters`, Core nur temporaer Facade | mittel | kompatibel erhalten, deprecaten | kein Character, aktiver Character, Restart |
| `ListCharacters` | `nexa-core` | `nexa-character`, Core-Callbacks, Tests | `nexa_characters` | mittel | erst in `nexa-character` implementieren, Core spaeter Facade oder deprecated | leere Liste, Ownership, DB-Fehler |
| `CreateCharacter` | `nexa-core` | `nexa-character`, `nexa-identity`, Tests | `nexa_characters` | hoch | neue Resource wird Owner; alter Export bleibt kompatibel bis Verbraucher migriert sind | Pflichtfelder, Limits, verbotene Felder |
| `SelectCharacter` | `nexa-core` | `nexa-character`, `nexa-identity`, Core-NetEvent, Tests | `nexa_characters` | hoch | neue Resource prueft Accountbesitz; Core-NetEvent deprecaten | fremde ID, doppelte Auswahl, activeBySource |
| `UpdateCharacter` | `nexa-core` | `nexa-character`, Tests | `nexa_characters` | hoch | nur gezielt mit Permission fuer Adminpfade | protected fields, Ownership, Audit |

## Interne APIs

### `Nexa.Players`

Aktuell:

- Session plus Account-aehnliche Registrierung
- DB-Zugriff auf `nexa_players`
- aktive Character-ID am Player-Objekt
- Permission-Load
- Audit `player.session_started` und `player.session_ended`

Soll:

- rein technische Verbindung/Player-Fassade bleiben
- Account-Aufloesung an `nexa_identity` abgeben
- `activeCharacterId` nicht dauerhaft als Core-Fachzustand fuehren

### `Nexa.Characters`

Aktuell:

- vollstaendige Character-Domain im Core

Soll:

- aus Core verschwinden oder nur noch als interne Kompatibilitaetsbruecke existieren
- Fachlogik in `nexa_characters`

## Vorhandene Character-Events

Core:

- `nexa:core:client:characterSelected`
- `nexa:core:client:characterUnloaded`
- `nexa:core:server:selectCharacter`
- `nexa:core:cb:getCharacters`

`nexa-character`:

- `nexa-character:server:list`
- `nexa-character:server:create`
- `nexa-character:server:select`
- `nexa-character:server:update`
- `nexa-character:client:charactersLoaded`
- `nexa-character:client:characterSelected`
- `nexa-character:client:characterUpdated`

`nexa-identity`:

- `nexa-identity:server:requestFlow`
- `nexa-identity:server:createCharacter`
- `nexa-identity:server:selectCharacter`
- `nexa-identity:client:open`
- `nexa-identity:client:close`
- `nexa-identity:client:error`
- `nexa-identity:client:selected`

Altresource `[nexa-gameplay]/nexa_identity`:

- `nexa:identity:server:requestCreateCharacter`
- `nexa:identity:server:requestSelectCharacter`
- `nexa:identity:server:requestDeleteCharacter`
- `nexa:identity:cb:listCharacters`
- `nexa:identity:cb:createCharacter`
- `nexa:identity:cb:selectCharacter`
- `nexa:identity:cb:deleteCharacter`
- `nexa:identity:cb:getActiveCharacter`

## Vorhandene UI und Spawn-Verknuepfung

- `[nexa-core]/nexa-identity` besitzt eine NUI fuer minimalen Character-Flow.
- `[nexa-gameplay]/nexa_identity` besitzt groessere Client-/Event-Logik, ist aber wegen Altlasten nicht sauber.
- `[nexa-gameplay]/nexa-spawn` existiert separat und fragt Spawn serverseitig an.
- In `[nexa-gameplay]/nexa_identity/client/events.lua` existiert ein QBCore-Event-Aufruf, der entfernt werden muss, bevor diese Resource wieder Teil der Zielarchitektur sein darf.

## Datenbankzugriffe

Kapitel-02-relevant:

- Core nutzt `Nexa.Database` fuer `nexa_players` und `nexa_characters`.
- `nexa-character` nutzt keine eigene Datenbank.
- `[nexa-gameplay]/nexa_identity` haengt laut Manifest direkt an `oxmysql`, die konkret gelesenen Serverdateien delegieren aber an `nexa_api` und enthalten `lib.callback`.

Repositoryweit existieren noch direkte `MySQL.*`-Zugriffe ausserhalb des Core-Layers, unter anderem in:

- `[nexa-gameplay]/nexa_items`
- `[nexa-gameplay]/nexa_inventory`
- `[nexa-gameplay]/nexa_shops`
- `[nexa-gameplay]/nexa_jobscreator`
- `[nexa-core]/nexa_permissions`
- `[nexa-core]/nexa_anticheat`

Diese sind nicht alle Kapitel-02-blockierend, aber sie verletzen die langfristige Regel "oxmysql nur ueber Core-Datenbanklayer" und muessen in spaeteren Kapiteln migriert werden.

## Abhaengigkeiten anderer Resources

Bekannte direkte Character-Abhaengigkeiten:

- `nexa_api` ruft `exports['nexa-core']:GetCharacter(source)`.
- `nexa_permissions` ruft `GetCharacter`, um characterbezogene Permissions einzubeziehen.
- `nexa_hud` nutzt `exports.nexa_api:GetCharacter(source)` fuer den HUD-Snapshot.
- `[standalone]/nexa-core-test` prueft `GetCharacter`.
- `[standalone]/nexa-character-test` prueft `nexa-character` Exports.
- Gameplay-Validatoren in Jobs, Dispatch, Banking, Documents, Licenses und Business akzeptieren `characterId`-Felder, pruefen aber nicht zwingend die neue Account-/Character-Domain.

## Risiken

| Risiko | Schwere | Begruendung |
| --- | --- | --- |
| Core bleibt Character-Domain-Owner | hoch | widerspricht Kapitel-02-Ziel und erzeugt spaetere Zyklen |
| Zwei Identity-Resources mit unterschiedlichem Zustand | hoch | Namenskonflikte, Altlasten, falscher Start |
| `[nexa-gameplay]/nexa_identity` enthaelt QBCore/qbx/ox_lib | hoch | harte Architekturverletzung |
| `nexa-character` ist nur Wrapper | mittel | Verbraucher glauben, Character-Domain sei ausgelagert, ist sie aber nicht |
| Account == `nexa_players` | mittel | keine getrennten Identifier, Status, Review, Ban/Suspend-Modell |
| direkte `MySQL.*`-Zugriffe in Foundations | mittel | langfristig gegen Core-DB-Regel |

## Phase-1-Entscheidung

Fuer Kapitel 02 wird keine kuenstlich neue Doppelstruktur erstellt. Die vorhandenen sauberen Namespaces sollen umbenannt bzw. weiterentwickelt werden:

- `nexa-core` bleibt technische Foundation.
- `nexa_identity` soll die neue Account-/Identity-Domain werden. Der alte `[nexa-gameplay]/nexa_identity`-Stand ist wegen Altlasten nicht direkt tragfaehig.
- `nexa_characters` soll die Character-Domain werden. Die bestehende Resource `[nexa-core]/nexa-character` ist als Migrationsbasis brauchbar, muss aber vom Core-Wrapper zur echten Domain-Resource werden.

Die konkrete Resource-Benennung muss in Phase 2/3 so gewaehlt werden, dass bestehende Startdateien und Verbraucher nicht unerwartet brechen.
