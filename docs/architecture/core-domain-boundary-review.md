# Core Domain Boundary Review

Stand: 2026-07-10

Dieses Dokument bewertet die aktuellen `nexa-core` Exports gegen die Zielarchitektur. Kapitel 01 bleibt Foundation. Gameplay-Domains sollen langfristig in eigene Ressourcen wandern.

## Grundsatz

`nexa-core` darf enthalten:

- Bootstrap und Lifecycle
- Logging
- validierte Konfiguration
- Datenbankabstraktion
- Migrationen
- EventBus
- Callback-System
- Module Loader
- technische Permissions
- technische Sessions
- kleiner Cache
- minimale Kompatibilitaetsfassaden fuer fruehe Foundation-Resources

`nexa-core` soll nicht dauerhaft besitzen:

- Character-Fachlogik
- Spawn- oder Kleidungssysteme
- Jobs, Fraktionen, Organisationen
- Inventory, Shops, Items
- UI
- Gameplay-Entscheidungen

## Export-Bewertung

Jede Zeile benennt den aktuellen Zweck und den future owner der jeweiligen Schnittstelle.

| Export | Current purpose | Future owner | Decision | Risk | Compatibility strategy |
| --- | --- | --- | --- | --- | --- |
| `GetCoreObject` | Diagnose und Zugriff auf interne Foundation-APIs | `nexa-core` | behalten, aber als Core-nahe Schnittstelle behandeln | mittel: zu breiter Zugriff kann Domain-Grenzen umgehen | dokumentieren, nur fuer Core-nahe Ressourcen und Tests verwenden |
| `GetPlayer` | Public Player-/Session-Daten fuer Source | `nexa-core` / spaeter Account-Facade | behalten | niedrig | Rueckgabe klein und maskiert halten |
| `GetCharacter` | aktiver Character einer Source | spaeter `nexa_characters` oder `nexa_identity` | vorerst behalten, spaeter Facade | mittel: Character-Domain liegt nicht im Core | neuen Character-Service einfuehren, Export als kompatible Weiterleitung markieren |
| `ListCharacters` | Characterliste fuer Source | spaeter `nexa_characters` | vorerst behalten, spaeter migrieren | mittel: Datenbank- und Domainlogik im Core | Aufrufverhalten stabil halten, intern spaeter an Character-Resource delegieren |
| `HasPermission` | serverseitige Permission-Pruefung | `nexa-core` | behalten | niedrig | zentrale technische Permission-API bleibt Core-Aufgabe |
| `GetIdentifier` | primary Identifier einer Source | `nexa-core` Session/Player | behalten | niedrig bis mittel: Identifier duerfen nicht unmaskiert geloggt werden | nur serverseitig verwenden, Logs maskieren |
| `CreateCharacter` | Character anlegen | spaeter `nexa_characters` | migrieren | hoch: mutierende Character-Domain im Core | nicht fuer neue Systeme verwenden; spaeter Deprecation-Hinweis und Delegation |
| `SelectCharacter` | aktiven Character setzen | spaeter `nexa_characters` / Spawn-Flow | migrieren | hoch: verbindet Session, Character und Gameplay-Flow | kompatible Weiterleitung beibehalten, neuer Character-Flow als Owner |
| `UpdateCharacter` | Characterdaten aendern | spaeter `nexa_characters` | migrieren | hoch: mutierende Character-Domain im Core | nur serverseitig, spaeter Deprecation und Delegation |

## Empfohlene Migrationsreihenfolge

1. Neue Resource `nexa_characters` oder `nexa_identity` als Character-Domain-Owner definieren.
2. Character-Datenmodell und Validierung aus `nexa-core` in die neue Resource verlagern.
3. Core-Exports `GetCharacter`, `ListCharacters`, `CreateCharacter`, `SelectCharacter`, `UpdateCharacter` als kompatible Facades bestehen lassen.
4. Neue Ressourcen gegen den Character-Owner statt gegen Core-Mutationen entwickeln.
5. Deprecation-Dokumentation fuer mutierende Core-Character-Exports veroeffentlichen.
6. Entfernen erst in einem spaeteren Major-Kompatibilitaetsschnitt.

## Runtime-Test-Strategie

Die Runtime-Abnahme testet mutierende Character-Exports nicht automatisch. Grund:

- `CreateCharacter` schreibt Daten.
- `SelectCharacter` braucht echten Session- und Character-Kontext.
- `UpdateCharacter` schreibt Daten.

Diese Exports werden in `[nexa-tests]/nexa-core-runtime-tests` als bewusst uebersprungene Domain-Grenzen ausgewiesen. Ein spaeterer isolierter Integrationstest darf sie nur gegen eine Testdatenbank und einen Testspieler pruefen.

## Risiken

| Risiko | Schwere | Bewertung |
| --- | --- | --- |
| Character-Mutation bleibt dauerhaft im Core | hoch | muss in Kapitel 02/Character-Foundation geplant werden |
| `GetCoreObject` erlaubt zu breiten Zugriff | mittel | durch Doku, Tests und spaetere Public-API-Grenzen begrenzen |
| Resources gewoehnen sich an Core-Character-Exports | mittel | neue Ressourcen auf kuenftigen Character-Owner ausrichten |
| Permission-API wird als Gameplay-Rollenmodell missverstanden | mittel | technische Permissions im Core lassen, Rollenbelegung separat |

## Entscheidung

Kapitel 01 bleibt akzeptabel, solange die Character-Exports als Uebergangs- und Kompatibilitaetsflaeche verstanden werden. Keine neue Gameplay-Domain soll in `nexa-core` ergaenzt werden.
