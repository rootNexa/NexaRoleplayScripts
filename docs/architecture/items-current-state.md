# Items Current State

Stand: 2026-07-10

`[nexa-gameplay]/nexa_items` existiert als fruehe Item-Foundation mit einfacher `items` Tabelle, Item Studio Client-Grundlage und Exports `CreateItem`, `GetItem`, `ListItems`, `UpdateItem`, `SetItemEnabled`, `DeleteItem`. Die Resource nutzt noch direkte `oxmysql`-Imports und ist deshalb nicht Zielzustand fuer Kapitel 07.

## Definitionsquellen

- `nexa_items` Tabelle `items`: alte Foundation.
- `nexa_inventory` Uebergangskatalog: `water`, `bread`, `radio`; muss entfernt werden.
- Item Studio Client Demo-Daten: rein UI-seitig, nicht autoritativ.

## Risiken

- Direkte DB-Nutzung.
- Keine versionierten Definitionen.
- Keine zentral registrierten Itemtypen.
- Keine Metadaten-Schema-Validierung.
- Keine Handler-Registry.
- Freie `image_url`-Strings ohne Asset-Sicherheitsmodell.
- Delete ist physisch statt Soft-Delete.

## Ziel

`nexa_items` wird zentrale serverautoritative Item Registry. `nexa_inventory` nutzt nur stabile `nexa_items` APIs und behaelt keine zweite Definitionsquelle.
