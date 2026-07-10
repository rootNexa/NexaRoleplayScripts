# nexa-core

`nexa-core` ist Kapitel 01 der Nexa Framework Foundation. Die Resource stellt keine Gameplay-Systeme bereit, sondern die kontrollierte technische Basis fuer Serverstart, Sessions, Datenbankzugriff, Permissions, interne Events, Callbacks, Module und Runtime-Caching.

## Verantwortlichkeiten

- Bootstrap und Lifecycle mit `created`, `initializing`, `initialized`, `starting`, `ready`, `stopping`, `stopped`, `failed`.
- Strukturierte Logs ueber `Nexa.Logger`.
- Validierte Konfiguration ueber `Nexa.Config`.
- Datenbankabstraktion und Migrationen ueber `Nexa.Database`.
- Interner EventBus fuer serverinterne Events.
- Sicheres Callback- und Request-System.
- Interner Module Loader.
- Permission-Foundation mit Rollen, Vererbung, Allow/Deny und Audit.
- Player Session Manager mit License-Pflicht und Datenschutzregeln.
- Kontrollierter Runtime-Cache.

## Nicht verantwortlich

- Inventory, Items, Shops, Jobs, Organisationen, MDT, Dispatch, Spawn, Kleidung, Geld, Fahrzeuge, Housing oder sonstiger Gameplay-State.
- QBCore-, Qbox-, ESX-, ox_lib- oder ox_inventory-Kompatibilitaet.
- Clientseitige Autoritaet ueber Identitaet, Permissions oder Gameplay-Entscheidungen.

## Abhaengigkeiten

Pflicht:

- `oxmysql`

Keine anderen externen Frameworks sind Bestandteil von `nexa-core`.

## Startreihenfolge

Minimal:

```cfg
ensure oxmysql
ensure nexa-core
```

Der Core prueft Pflichtabhaengigkeiten beim Bootstrap. Fehlt `oxmysql`, wechselt der Core in `failed` und meldet keine falsche Bereitschaft.

## Oeffentliche Exports

- `GetCoreObject`
- `GetPlayer`
- `GetCharacter`
- `ListCharacters`
- `HasPermission`
- `GetIdentifier`
- `CreateCharacter`
- `SelectCharacter`
- `UpdateCharacter`

Details stehen in `docs/API.md`.

## Interne Foundation-APIs

- `Nexa.Lifecycle`
- `Nexa.Logger`
- `Nexa.Config`
- `Nexa.Database`
- `Nexa.EventBus`
- `Nexa.Callbacks`
- `Nexa.Modules`
- `Nexa.Permissions`
- `Nexa.Sessions`
- `Nexa.Cache`

## Tests und Validierung

Kapitel-01-Gesamtvalidierung:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-foundation.ps1
```

Einzelvalidierungen:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-lifecycle.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-logger.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-config.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-database.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-eventbus.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-callbacks.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-modules.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-permissions.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-sessions.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-core-cache.ps1
```

Einige Tests benoetigen eine laufende FXServer-Instanz mit MariaDB/oxmysql. Diese sind in `docs/architecture/core-testing.md` beschrieben.

## Dokumentation

- Architekturuebersicht: `docs/architecture/core-overview.md`
- Lifecycle: `docs/architecture/core-lifecycle.md`
- Logging: `docs/architecture/core-logging.md`
- Config: `docs/architecture/core-config.md`
- Datenbank und Migrationen: `docs/architecture/core-database.md`
- Events: `docs/architecture/core-eventbus.md`
- Callbacks: `docs/architecture/core-callbacks.md`
- Module: `docs/architecture/core-modules.md`
- Permissions: `docs/architecture/core-permissions.md`
- Sessions: `docs/architecture/core-sessions.md`
- Cache: `docs/architecture/core-cache.md`
- Betrieb: `docs/architecture/core-operations.md`
- Troubleshooting: `docs/architecture/core-troubleshooting.md`
- Kapitel-01-Abschluss: `docs/architecture/core-chapter01-validation.md`

## Definition of Done

Kapitel 01 gilt als abgeschlossen, wenn die Gesamtvalidierung erfolgreich ist, `nexa-core` im FXServer mit `oxmysql` startet, kontrolliert stoppt, Migrationen idempotent laufen, Sessions und Permissions serverseitig funktionieren und keine kritischen oder hohen Fehler offen sind.
