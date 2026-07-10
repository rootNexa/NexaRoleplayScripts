# Nexa Core Permission Foundation

Stand: 2026-07-10

`nexa-core` besitzt ein technisches Permission-Grundsystem. Es definiert keine fertige Adminpolitik und weist keine produktiven Owner-, Admin- oder Support-Rollen automatisch zu. Diese Belegung folgt spaeter ueber eine eigene Admin-, Setup- oder Konfigurationsresource.

## Rollen versus Permissions

Permissions sind die eigentliche Autoritaet. Rollen sind nur Sammlungen von Permissions.

Permissions folgen dem Muster:

```text
nexa.<bereich>.<aktion>
```

Beispiele:

- `nexa.admin.kick`
- `nexa.admin.ban`
- `nexa.admin.noclip`
- `nexa.inventory.inspect`
- `nexa.inventory.modify`
- `nexa.character.modify`
- `nexa.admin.core.status`

Vorgesehene Rollennamen fuer spaetere Belegung:

- Owner
- Co-Owner
- Head Admin
- Senior Admin
- Admin
- Trial Admin
- Head Support
- Supporter
- Support Trainee

Diese Rollen sind fachliche Vorschlaege. Der Core behandelt sie generisch.

## Account- und Character-Permissions

Das Datenmodell trennt Account- und Character-Permissions.

Subjekttypen:

- `account`: dauerhafter Spieleraccount aus `nexa_players`.
- `character`: spaeterer Charakterbezug aus `nexa_characters`.

Account-Permissions duerfen nicht heimlich als Character-Permissions gespeichert werden. Ein Check per FiveM-`source` wird im Core auf das geladene Account-Subject aufgeloest.

## Datenmodell

Migration `002_permission_foundation` erstellt:

- `nexa_permission_roles`
- `nexa_permission_role_permissions`
- `nexa_permission_role_inheritance`
- `nexa_permission_subject_roles`
- `nexa_permission_subject_permissions`

Die alte Tabelle `nexa_permissions` bleibt als Legacy-Account-Fallback erhalten. Sie wird beim Laden eines Account-Subjects eingelesen, damit bestehende Core-Daten nicht sofort migriert werden muessen.

## Vererbung

Eine Rolle kann eine oder mehrere andere Rollen erben. Geerbte Rollen werden zuerst aufgeloest, danach die Permissions der konkreten Rolle.

Zyklen in der Rollenvererbung sind ungueltig. Wird ein Zyklus erkannt, bricht die Aufloesung mit `ROLE_INHERITANCE_CYCLE` ab und die Entscheidung bleibt sicherheitshalber negativ.

## Allow und Deny

Regeln besitzen einen Effekt:

- `allow`: erlaubt eine Permission.
- `deny`: verbietet eine Permission.

Explizites `deny` gewinnt immer gegen `allow`, egal ob es direkt, ueber eine Rolle oder ueber eine Wildcard kommt.

Entscheidungsreihenfolge:

1. Permissionname validieren.
2. Subject serverseitig aufloesen.
3. Rollen und geerbte Rollen laden.
4. Direkte Subject-Permissions laden.
5. Legacy-Account-Permissions laden.
6. Deny-Regeln pruefen.
7. Allow-Regeln pruefen.
8. Optionalen ACE-Fallback pruefen.
9. Ohne Treffer ablehnen.

## Wildcards

Wildcards sind kontrolliert erlaubt und nur am Ende einer Permission gueltig.

Erlaubt:

- `nexa.admin.*`
- `nexa.inventory.*`
- `nexa.*`

Nicht erlaubt:

- `*.admin.kick`
- `nexa.*.kick`
- `nexa.admin.*.force`

Wildcards sollen sparsam eingesetzt werden. Kritische Aktionen sollten bevorzugt explizite Permissions erhalten.

## Cache und Invalidierung

Der Core cached effektive Regeln pro Subject.

Invalidierung:

- `Permissions.Invalidate(subject)` leert ein Subject.
- `Permissions.Invalidate()` leert alle Subject-Caches, Decision-Traces und den Rollen-Cache.
- Runtime-Updates wie `AssignRole`, `RemoveRole`, `Grant`, `Deny` und `Revoke` invalidieren automatisch das betroffene Subject.

## Interne API

- `Permissions.Has(subject, permission, context)`
- `Permissions.GetAll(subject)`
- `Permissions.AssignRole(subject, role)`
- `Permissions.RemoveRole(subject, role)`
- `Permissions.Grant(subject, permission)`
- `Permissions.Deny(subject, permission)`
- `Permissions.Revoke(subject, permission)`
- `Permissions.Invalidate(subject)`
- `Permissions.GetDecisionTrace(subject, permission)`

`subject` kann eine FiveM-`source` oder ein explizites Subject sein:

```lua
{ type = 'account', id = 42 }
{ type = 'character', id = 1001 }
{ source = source, type = 'account' }
```

## Decision Trace

`GetDecisionTrace` erklaert, warum eine Entscheidung zustande kam. Der Trace enthaelt:

- aufgeloestes Subject
- gepruefte Permission
- geladene Rollen
- direkte und geerbte Regeln
- matched Permission oder Wildcard
- finalen Grund, zum Beispiel `ALLOW`, `EXPLICIT_DENY`, `ACE_FALLBACK`, `NO_MATCH`, `INVALID_PERMISSION`

Der Trace ist fuer Debugging und Audit gedacht und darf nicht ungefiltert an Clients ausgegeben werden.

## ACE-Fallback

ACE ist optionaler Bootstrap-/Fallback-Mechanismus. Wenn keine Deny- oder Allow-Regel im Nexa-Modell greift, prueft der Core:

- die Permission direkt, zum Beispiel `nexa.admin.kick`
- eine ACE-Variante mit Prefix, zum Beispiel `nexa.nexa.admin.kick`

ACE ersetzt keine persistenten Rollen. Explizites Nexa-Deny hat Vorrang vor ACE-Allow.

## Audit

Runtime-Updates schreiben Audit-Ereignisse:

- `permission.allow`
- `permission.deny`
- `permission.revoke`
- `permission.role.assign`
- `permission.role.remove`

Optional kann `Permissions.Has(subject, permission, { audit = true })` auch Checks auditieren.

## Sicherheitsmodell

- Der Client darf keine Permissions behaupten.
- `source` wird serverseitig auf den geladenen Account aufgeloest.
- Character-Permissions werden getrennt von Account-Permissions gespeichert.
- Deny hat Vorrang.
- Unbekannte oder ungueltige Permissions werden abgelehnt.
- Wildcards sind nur als kontrollierte End-Wildcards erlaubt.
- Decision-Traces sind intern und duerfen keine Autorisierung auf dem Client ersetzen.
