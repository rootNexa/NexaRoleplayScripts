# nexa-core-test

Development-only Test-Resource fuer das Nexa Framework Fundament.

Diese Resource prueft serverseitig, ob `nexa-core` gestartet ist und ob die vorhandenen Foundation-Exports erreichbar sind. Sie erstellt keine Characters, schreibt keine Daten und greift nicht direkt auf die Datenbank zu.

## Zweck

- Resource-State von `nexa-core` pruefen
- Foundation-Exports defensiv aufrufen
- Logs fuer echte FXServer-Sessions erzeugen
- Player-Session, Identifier, aktiven Character und Permission-Check sichtbar machen

## Ensure-Reihenfolge

Die Resource ist nicht fuer Production gedacht. Fuer Development kann sie nach `nexa-core` gestartet werden:

```cfg
ensure oxmysql
ensure ox_lib
ensure ox_inventory
ensure nexa-core
ensure nexa-core-test
```

Die produktive Startreihenfolge muss nicht dauerhaft geaendert werden. Fuer einen manuellen Test reicht ein temporaerer Eintrag oder ein Start ueber die Serverkonsole nach `nexa-core`.

## Gepruefte Exports

- `exports['nexa-core']:GetCoreObject()`
- `exports['nexa-core']:GetIdentifier(source)`
- `exports['nexa-core']:GetPlayer(source)`
- `exports['nexa-core']:GetCharacter(source)`
- `exports['nexa-core']:HasPermission(source, 'nexa.admin')`

`CreateCharacter` und `SelectCharacter` werden bewusst nicht automatisch ausgefuehrt, weil diese Funktionen Daten veraendern koennen oder einen bestehenden Character-Kontext benoetigen.

## Erwartete Logs

Beim Start:

```text
[nexa-core-test] [info] Checking nexa-core resource state.
[nexa-core-test] [info] GetCoreObject ok
```

Wenn kein Spieler online ist:

```text
[nexa-core-test] [info] No players online; player export checks skipped.
```

Nach Spielerbeitritt oder `/nexacoretest`:

```text
[nexa-core-test] [info] Running player export checks.
[nexa-core-test] [info] GetIdentifier ok
[nexa-core-test] [info] GetPlayer ok
[nexa-core-test] [info] GetCharacter ok
[nexa-core-test] [info] HasPermission ok
```

`GetCharacter` darf `nil` liefern, wenn noch kein Character ausgewaehlt ist. `HasPermission` darf `false` liefern, wenn die Permission nicht gesetzt ist.

## Command

`/nexacoretest` fuehrt nur Log-Pruefungen aus.

- Konsole: prueft Resource-State und alle online Spieler.
- Spieler: benoetigt serverseitig `nexa.admin`; prueft dann nur die eigene Source.

## Sicherheitsregeln

- Keine Client-Daten werden als vertrauenswuerdig behandelt.
- Keine direkten Datenbankzugriffe.
- Keine automatischen Character-Erstellungen.
- Keine Datenmutationen.
- Nur fuer Development verwenden.
