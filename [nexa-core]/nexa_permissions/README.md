# nexa_permissions

Eigenes Rollen- und Rechtesystem fuer Nexa Framework.

## Zweck

- Rollen verwalten
- Permission-Regeln auswerten
- Rollenvererbung aufloesen
- Spieler oder Identifier Rollen zuweisen
- Character-Zuweisungen im Datenmodell vorbereiten
- Permission-Cache pro Spieler bereitstellen

## Abhaengigkeiten

- `nexa-lib`
- `nexa-core`
- `oxmysql`

`oxmysql` wird hier direkt genutzt, weil `nexa-core` aktuell keine Datenbank-API exportiert. Alle Player-, Identifier- und Character-Kontexte werden ueber `nexa-core` Exports gelesen.

## Migration

Importiere vor dem Start:

```sql
server/resources/[nexa-core]/nexa_permissions/sql/001_permissions_roles.sql
```

Die Foundation-Tabelle `nexa_permissions` bleibt unveraendert. Die neue Resource nutzt eigene Rollen-Tabellen und zerstoert keine bestehenden Daten.

## Exports

- `Has(source, permission)`
- `HasAny(source, permissions)`
- `HasAll(source, permissions)`
- `GetRoles(source)`
- `AssignRoleToPlayer(sourceOrIdentifier, roleName)`
- `RemoveRoleFromPlayer(sourceOrIdentifier, roleName)`
- `ReloadPermissions()`
- `GetPermissionCache(source)`

Alle Exports geben das Nexa Response-Format zurueck:

```lua
{
    ok = true,
    data = {},
    error = nil
}
```

oder:

```lua
{
    ok = false,
    data = nil,
    error = {
        code = 'ERROR_CODE',
        message = 'Readable message.',
        details = {}
    }
}
```

## Permission-Regeln

Unterstuetzt werden exakte Regeln und Wildcards:

- `nexa.admin`
- `nexa.admin.*`
- `jobs.police.*`
- `jobs.police.manage`

Exakte Regeln erhalten bei gleicher Rollen-Prioritaet Vorrang vor Wildcards. Bei Konflikten gewinnt die Regel aus der Rolle mit der hoeheren Priority. Regeln koennen erlauben oder verweigern.

## Default-Rollen

Beim Start werden diese Rollen sichergestellt:

- `user`
- `admin`

Jeder Spieler erhaelt im Cache die Rolle `user`. Die Rolle `admin` wird nur angelegt, aber niemandem automatisch zugewiesen.

## Development Commands

Nur im Development-Modus oder fuer Serverkonsole:

- `/nexaperms`
- `/nexahas <permission>`
- `/nexaroles`
- `/nexaassignrole <serverId|identifier> <role>`
- `/nexareloadperms`

## Integration

`nexa-core` bleibt unabhaengig. `nexa-core:HasPermission` wird nicht hart auf diese Resource delegiert, damit die Foundation ohne zyklische Dependency starten kann. Neue Ressourcen sollen direkt `exports['nexa_permissions']:Has(source, permission)` nutzen.
