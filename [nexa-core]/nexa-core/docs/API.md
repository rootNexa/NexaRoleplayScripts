# Nexa Core API

Status: Foundation 0.1.0

`nexa-core` ist die zentrale Grundlage des Nexa Frameworks. Diese Resource verwaltet aktuell Player-Sessions, Identifier, Character-Grunddaten, Permissions, Callbacks, Events, Exports und zentrale Datenbankzugriffe.

Diese API beschreibt nur Funktionen, die bereits existieren. Gameplay-Systeme wie Jobs, Fraktionen, Housing, Fahrzeuge oder Crime sind nicht Teil dieses Vertrags.

## Grundprinzipien

- Der Server ist autoritativ.
- Der Core meldet Bereitschaft erst im Lifecycle-Zustand `ready`.
- Core-Exports, Core-Callbacks und Core-Net-Events sind vor `ready` geschuetzt.
- Clients duerfen Aktionen anfragen, aber keine vertrauenswuerdigen Daten festlegen.
- Datenbankzugriffe laufen innerhalb des Framework-Fundaments ueber `Nexa.Database`.
- Permissions werden serverseitig entschieden.
- Character-Auswahl prueft immer, ob der Character zum verbundenen Player gehoert.
- Exports sind fuer serverseitige Resource-zu-Resource-Kommunikation gedacht.
- Client-Callbacks liefern nur Daten, die fuer den jeweiligen Spieler freigegeben sind.

## Player und Character

Ein Player steht fuer Verbindung, Account-Identifier und Session.

Wichtige Felder:

- `id`: interne `nexa_players.id`
- `source`: aktuelle FiveM-Source
- `identifier`: primaerer Identifier, bevorzugt `license`
- `name`: Anzeigename aus der Verbindung
- `activeCharacterId`: aktuell ausgewaehlter Character oder `nil`
- `loaded`: Session-Status

Ein Character steht fuer eine RP-Figur und gehoert genau einem Player.

Wichtige Felder:

- `id`: interne `nexa_characters.id`
- `playerId`: Besitzer aus `nexa_players.id`
- `firstName`
- `lastName`
- `birthdate`
- `gender`
- `metadata`
- `createdAt`
- `updatedAt`

## Response-Format

Callbacks verwenden ein einheitliches Response-Objekt:

```lua
{
    success = true,
    code = 'OK',
    message = 'Session geladen.',
    data = {},
    meta = nil
}
```

Fehlerbeispiel:

```lua
{
    success = false,
    code = 'NOT_FOUND',
    message = 'Spieler nicht geladen.',
    data = nil,
    meta = nil
}
```

Exports geben aktuell direkte Werte zurueck. Bei Operationen, die fehlschlagen koennen, ist das Muster:

```lua
local result, err = exports['nexa-core']:CreateCharacter(source, data)
```

`result` ist bei Erfolg gesetzt. `err` ist bei Fehler ein stabiler Fehlercode.

## Fehlercodes

Aktuell verwendete Fehlercodes:

- `OK`
- `INVALID_INPUT`
- `NOT_FOUND`
- `NO_PERMISSION`
- `DATABASE_ERROR`
- `SECURITY_REJECTED`
- `CHARACTER_NOT_LOADED`
- `INTERNAL_ERROR`
- `PLAYER_NOT_FOUND`
- `CHARACTER_LIMIT_REACHED`
- `RATE_LIMITED`

Clients erhalten keine technischen Datenbankdetails. Technische Fehler werden serverseitig geloggt.

## Lifecycle

Intern verwaltet `nexa-core` die Zustaende `created`, `initializing`, `initialized`, `starting`, `ready`, `stopping`, `stopped` und `failed`.

Interne Lifecycle-Funktionen:

- `Nexa.Lifecycle.GetState()`
- `Nexa.Lifecycle.IsReady()`
- `Nexa.Lifecycle.RegisterLifecycleHook(stage, callback)`
- `Nexa.Lifecycle.GetStartTimestamp()`
- `Nexa.Lifecycle.GetFailureReason()`

Diese Funktionen sind bewusst interne Core-Schnittstellen und noch keine eigenstaendig versionierten Public Exports. `GetCoreObject()` kann sie fuer Core-nahe Diagnose sichtbar machen.

Wenn der Core nicht `ready` ist, geben geschuetzte Exports keine fachlichen Daten zurueck. Schreibende Exports liefern dann `nil, 'CORE_NOT_READY'`; Permission-Checks liefern `false`.

## Exports

### `GetPlayer(source)`

Gibt die oeffentlichen Session-Daten eines geladenen Players zurueck.

Parameter:

- `source` (`number|string`): FiveM-Source

Rueckgabe:

- Player-Tabelle oder `nil`

Beispiel:

```lua
local player = exports['nexa-core']:GetPlayer(source)

if not player then
    return
end

print(player.identifier)
```

Fehlerverhalten:

- `nil`, wenn fuer die Source keine Nexa-Session geladen ist.

Sicherheit:

- Die Rueckgabe enthaelt keine komplette Identifier-Liste und keine sensiblen internen Caches.

### `GetCharacter(source)`

Gibt den aktuell ausgewaehlten Character eines Spielers zurueck.

Parameter:

- `source` (`number|string`): FiveM-Source

Rueckgabe:

- Character-Tabelle oder `nil`

Beispiel:

```lua
local character = exports['nexa-core']:GetCharacter(source)

if not character then
    return false, 'CHARACTER_NOT_LOADED'
end

return character.id
```

Fehlerverhalten:

- `nil`, wenn kein Character ausgewaehlt ist oder keine Session existiert.

Sicherheit:

- Andere Resources duerfen daraus keine Ownership fuer fremde Objekte ableiten, ohne eigene serverseitige Pruefung.

### `HasPermission(source, permission)`

Prueft serverseitig, ob ein Spieler eine Permission besitzt.

Parameter:

- `source` (`number|string`): FiveM-Source
- `permission` (`string`): Permission im Format `domain.action`

Rueckgabe:

- `true` oder `false`

Beispiel:

```lua
if not exports['nexa-core']:HasPermission(source, 'admin.core.status') then
    return false, 'NO_PERMISSION'
end
```

Fehlerverhalten:

- `false`, wenn die Session fehlt.
- `false`, wenn die Permission ungueltig formatiert ist.
- `false`, wenn keine Permission gesetzt ist.

Sicherheit:

- Permission-Entscheidungen duerfen nicht vom Client uebernommen werden.
- Sichtbare UI-Rechte sind nur Komfort, keine Autoritaet.

### `GetIdentifier(source)`

Gibt den primaeren Framework-Identifier einer geladenen Session zurueck.

Parameter:

- `source` (`number|string`): FiveM-Source

Rueckgabe:

- Identifier-String oder `nil`

Beispiel:

```lua
local identifier = exports['nexa-core']:GetIdentifier(source)

if not identifier then
    return false, 'PLAYER_NOT_FOUND'
end
```

Fehlerverhalten:

- `nil`, wenn keine Nexa-Session geladen ist.

Sicherheit:

- Der Identifier wird serverseitig aus FiveM-Identifiern ermittelt.
- Clients duerfen Identifier nicht selbst liefern.

### `CreateCharacter(source, data)`

Erstellt einen Character fuer den geladenen Player.

Parameter:

- `source` (`number|string`): FiveM-Source
- `data` (`table`):
  - `firstName` oder `first_name` (`string`)
  - `lastName` oder `last_name` (`string`)
  - `birthdate` (`YYYY-MM-DD`)
  - `gender` (`male`, `female`, `diverse`, `unknown`)
  - `metadata` (`table`, optional)

Rueckgabe:

- Erfolg: `character, nil`
- Fehler: `nil, errorCode`

Beispiel:

```lua
local character, err = exports['nexa-core']:CreateCharacter(source, {
    firstName = 'Mara',
    lastName = 'Keller',
    birthdate = '1996-04-12',
    gender = 'female'
})

if not character then
    return false, err
end
```

Fehlerverhalten:

- `PLAYER_NOT_FOUND`: keine geladene Session.
- `DATABASE_ERROR`: Character-Liste oder Insert konnte nicht ausgefuehrt werden.
- `CHARACTER_LIMIT_REACHED`: maximales Character-Limit erreicht.
- `INVALID_INPUT`: Payload ist ungueltig.

Sicherheit:

- `player_id` wird nie aus Client-Daten gelesen.
- Character wird immer fuer den serverseitig geladenen Player erstellt.
- Namen, Geburtsdatum und Gender werden serverseitig validiert.

### `SelectCharacter(source, characterId)`

Waehlt einen vorhandenen Character fuer eine Player-Session aus.

Parameter:

- `source` (`number|string`): FiveM-Source
- `characterId` (`number|string`): `nexa_characters.id`

Rueckgabe:

- Erfolg: `character, nil`
- Fehler: `nil, errorCode`

Beispiel:

```lua
local character, err = exports['nexa-core']:SelectCharacter(source, characterId)

if not character then
    return false, err
end
```

Fehlerverhalten:

- `INVALID_INPUT`: Source oder Character-ID ungueltig.
- `NOT_FOUND`: Character existiert nicht oder gehoert nicht zum Player.

Sicherheit:

- Ownership wird ueber `WHERE id = ? AND player_id = ?` geprueft.
- Ein Spieler kann keinen fremden Character auswaehlen, auch wenn er dessen ID kennt.
- Fehlgeschlagene Ownership-Versuche werden auditierbar erfasst.

## Callbacks

Aktuell registrierte Callbacks:

- `nexa:core:cb:getSession`
- `nexa:core:cb:getCharacters`

Callbacks sind rate-limited und geben immer das Response-Format zurueck.

Beispiel:

```lua
NexaClient.Callbacks.Trigger('nexa:core:cb:getSession', nil, function(response)
    if response.success then
        local player = response.data.player
    end
end)
```

## Events

Aktuell vorhandene Foundation-Events:

- Client: `nexa:core:client:playerLoaded`
- Client: `nexa:core:client:characterSelected`
- Client: `nexa:core:client:characterUnloaded`
- Server: `nexa:core:server:selectCharacter`

Serverevents pruefen, ob die Source eine geladene Nexa-Session besitzt. Kritische Daten werden serverseitig neu aufgeloest.

## Datenbankvertrag

Foundation-Tabellen:

- `nexa_players`
- `nexa_characters`
- `nexa_permissions`
- `nexa_audit_log`

Die Migration liegt in:

```text
server/resources/[nexa-core]/nexa-core/sql/001_foundation.sql
```

Andere Resources sollen diese Tabellen nicht direkt manipulieren, wenn ein Nexa-Core-Export oder eine spaetere Nexa-API dafuer existiert.

## Beispiel fuer spaetere Resources

```lua
local player = exports['nexa-core']:GetPlayer(source)

if not player then
    return false, 'PLAYER_NOT_FOUND'
end

local character = exports['nexa-core']:GetCharacter(source)

if not character then
    return false, 'CHARACTER_NOT_LOADED'
end

if not exports['nexa-core']:HasPermission(source, 'example.use') then
    return false, 'NO_PERMISSION'
end

return true, {
    playerId = player.id,
    characterId = character.id
}
```

## Nicht Teil dieses Vertrags

Noch nicht vorhanden und deshalb nicht dokumentiert:

- Geldsystem
- Inventar-Bridge
- Jobs
- Fraktionen
- Fahrzeuge
- Housing
- Crime-Systeme
- Admin-Aktionen
- komplexe UI-Flows
