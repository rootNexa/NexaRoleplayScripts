# Identity and Character Migration Plan

Stand: 2026-07-10

Dieses Dokument beschreibt den Migrationspfad fuer Kapitel 02. Es basiert auf `identity-character-current-state.md` und `core-domain-boundary-review.md`.

## Zielbild

Abhaengigkeitsrichtung:

```text
nexa_identity -> nexa_core
nexa_characters -> nexa_core
nexa_characters -> nexa_identity
```

Nicht erlaubt:

```text
nexa_core -> nexa_identity
nexa_core -> nexa_characters
```

Der Core darf ohne Identity- und Character-Domain starten. Alte Core-Character-Exports duerfen nur als kontrollierte, deprecated Kompatibilitaetsflaeche bleiben.

## Migrationsprinzipien

- Migrationen sind append-only.
- Keine angewendete Core-Migration wird veraendert.
- Clientdaten fuer Account-ID oder Source werden nie vertraut.
- Character-ID wird immer gegen den serverseitig aufgeloesten Account geprueft.
- IP ist nie primaerer Account-Identifier.
- Keine Hardware-ID.
- Keine automatische harte Sperre nur anhand schwacher Signale.
- Keine QBCore/Qbox/ESX/ox_lib Rueckkehr.
- Direkte `oxmysql`-Nutzung in neuen Kapitel-02-Resources ist verboten; Datenbankzugriffe laufen ueber den Core-Datenbanklayer.

## Phase A: Dokumentation und Grenzziehung

Status: dieses Dokument.

Aufgaben:

1. Ist-Zustand dokumentieren.
2. Bestehende Aufrufer und Altlasten erfassen.
3. Zielbesitzer fuer jede Funktion festlegen.
4. Risiken und Teststrategie dokumentieren.

Commit:

```text
docs(identity): define account and character boundaries
```

## Phase B: Account- und Identifier-Modell

Neue Tabellen, append-only:

- `nexa_accounts`
- `nexa_account_identifiers`
- `nexa_account_status_history`
- optional `nexa_account_review_signals`

Kompatibilitaet:

- Bestehende `nexa_players`-Daten werden nicht geloescht.
- Neue Account-Tabelle kann initial dieselbe License wie `nexa_players.identifier` verwenden.
- Fremdschluessel zu `nexa_players` werden nicht erzwungen, bis die Migration stabil ist.

Risiken:

- bestehende Permissions referenzieren `nexa_players.id`
- Audit referenziert `player_id`
- Character-Tabelle referenziert `player_id`

Strategie:

- `nexa_accounts.id` wird neue Account-ID.
- Uebergangsweise kann ein Account `legacy_player_id` oder Mapping-Metadaten halten.
- Permissions-Migration wird spaeter geplant, damit Account- und Character-Permissions sauber getrennt bleiben.

## Phase C: `nexa_identity`

Resource-Aufgabe:

- Account-Aufloesung aus Session-Identifiern
- Account-Erstellung
- Identifier-Refresh
- Accountstatus
- Multi-Account-Risikohinweise
- Account-Cache
- interne Identity-Events

Mindest-Exports:

- `GetAccount`
- `GetAccountId`
- `GetAccountStatus`
- `IsAccountReady`

Interne APIs:

- `Identity.ResolveAccount(session)`
- `Identity.GetAccountById(accountId)`
- `Identity.GetAccountBySource(source)`
- `Identity.GetAccountIdentifiers(accountId)`
- `Identity.IsAccountActive(accountId)`
- `Identity.SetAccountStatus(accountId, status, reason, actor)`
- `Identity.RefreshIdentifiers(accountId, identifiers)`
- `Identity.Invalidate(accountId)`

Kompatibilitaet:

- `nexa-core` bleibt Besitzer der Session.
- Identity reagiert auf `nexa:internal:session:created` und `nexa:internal:session:removed`.
- Keine Core-Abhaengigkeit auf Identity.

## Phase D: Multi-Account-Modell

Signale:

- stark: gleiche License, bekannte Sperrumgehung
- mittel: gleiche Discord-ID, gleiche FiveM-ID, gleiche Steam-ID
- schwach: wiederholt gleiche IP, schneller Accountwechsel
- kein verwertbares Signal: Namensaehnlichkeit allein

Entscheidungen:

- gleiche IP alleine sperrt nie automatisch
- fehlender Discord sperrt nie automatisch
- unsichere Faelle setzen `pending_review`
- alle Entscheidungen werden auditiert und maskieren Identifier

## Phase E: `nexa_characters`

Resource-Aufgabe:

- Characterliste fuer Account
- Character-Erstellung
- Character-Auswahl
- Character-Update
- Soft-Delete
- aktiver Character je Session
- Character-Lifecycle
- Validierung und Audit

Neue Felder gegenueber Core-Ist:

- `account_id`
- `slot`
- `status`
- `height`
- `weight`
- `nationality`
- `backstory`
- `phone_number`
- `version`
- `last_selected_at`

Kompatibilitaet:

- alte `nexa_characters.player_id` wird nicht sofort entfernt
- neue Migration fuegt Zielspalten hinzu oder erstellt eine neue Tabelle, ohne vorhandene Daten zu loeschen
- Wrapper-Exports behalten Rueckgabeformate, solange Verbraucher migriert werden

## Phase F: Core-Character-APIs migrieren

Core-Funktionen:

- `GetCharacter`
- `ListCharacters`
- `CreateCharacter`
- `SelectCharacter`
- `UpdateCharacter`
- `Nexa.Characters.*`
- Core-NetEvent `nexa:core:server:selectCharacter`
- Core-Callback `nexa:core:cb:getCharacters`

Strategie:

1. Fachlogik aus `nexa-core/server/characters.lua` in `nexa_characters` verschieben.
2. `nexa-core` darf nicht auf `nexa_characters` dependieren.
3. Alte Core-Exports bleiben zunaechst deprecated und nutzen nur noch lokale Legacy-Logik oder geben kontrollierte Hinweise, bis alle Verbraucher migriert sind.
4. Neue Verbraucher nutzen `nexa_characters` oder `nexa_api`-Facades.
5. Deprecation-Warnungen rate-limited pro invoking resource loggen.
6. Entfernen erst nach dokumentiertem Kompatibilitaetsschnitt.

## Funktion fuer Funktion

| Funktion | Aktueller Zweck | Problem | Ziel | Reihenfolge |
| --- | --- | --- | --- | --- |
| `Nexa.Players.Register` | Session plus `nexa_players` erstellen | vermischt Session und Account | Session bleibt Core, Account in Identity | zuerst Identity parallel einfuehren |
| `Nexa.Players.GetIdentifier` | primaere License liefern | Account-Identifier nicht getrennt | Identity liefert Account-ID und Identifierliste | nach Identity-Exports |
| `Nexa.Characters.List` | Liste aus Core-Tabelle | Domain im Core | `nexa_characters:ListCharacters` | Character-Repo bauen |
| `Nexa.Characters.Create` | Character erstellen | Domain, Validierung, Limit im Core | `nexa_characters:CreateCharacter` | neue Validierung und Migration |
| `Nexa.Characters.Select` | aktiven Character setzen | Lifecycle im Core | `nexa_characters:SelectCharacter` | Active-Session-Map migrieren |
| `Nexa.Characters.Update` | Character aendern | Admin-/Spielerrechte nicht getrennt | `nexa_characters:UpdateCharacter` | Permissions/Audit ergaenzen |
| `Nexa.Characters.Unload` | activeBySource loeschen | Character-Lifecycle im Core | `nexa_characters:Release` | Disconnect-Hook in Character-Resource |

## Teststrategie

Statisch:

- forbidden framework search
- direkte `oxmysql`-Suche in neuen Resources
- Hardware-ID-Suche
- IP-als-Primary-Identifier-Suche
- Client-Account-ID-Trust-Suche
- Client-Character-ID-Trust-Suche
- Callback-Registrierung und Payload-Validation
- `git diff --check`

Runtime-nah:

- Identity account resolve
- missing license
- banned/suspended/disabled Account
- identifier refresh
- review signal without hard ban
- character list/create/select/update/delete
- old Core-Export-Kompatibilitaet
- restart cleanup

FXServer-Runtime:

- bleibt offen, falls `FXServer.exe` lokal nicht verfuegbar ist
- keine Runtime-Ergebnisse werden gefaelscht
- Harness- oder manuelle Schritte muessen dokumentiert werden

## Bekannte Blocker und Risiken

| Thema | Risiko | Massnahme |
| --- | --- | --- |
| `[nexa-gameplay]/nexa_identity` Altlasten | hoch | nicht als Zielbasis verwenden, erst entfernen oder ersetzen |
| Core-Character-Exports aktiv genutzt | hoch | Kompatibilitaet halten, erst Verbraucher migrieren |
| `nexa_permissions` nutzt Character-Kontext | mittel | nach Character-Owner anpassen |
| `nexa_hud` liest Character ueber API | mittel | API-Facade auf neuen Owner umstellen |
| direkte DB-Zugriffe in anderen Foundations | mittel | ausserhalb Kapitel 02 separat migrieren |
| bestehende `nexa_players` Foreign Keys | mittel | append-only Mapping, keine harte Entfernung |

## Definition fuer Abschluss von Phase 1

Phase 1 ist abgeschlossen, wenn:

- Ist-Zustand dokumentiert ist.
- Migration pro Funktion beschrieben ist.
- Altlasten benannt sind.
- keine produktive Migration ohne Analyse erfolgt ist.
- vorbestehende Faction-Deletes unberuehrt bleiben.
