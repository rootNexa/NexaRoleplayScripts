# Account Model

Stand: 2026-07-10

Ein Account repraesentiert eine reale Serveridentitaet, nicht einen Charakter und nicht eine einzelne Verbindung.

## Tabelle `nexa_accounts`

- `id`: interne Account-ID
- `primary_license`: primaere FiveM/Rockstar-License
- `status`: Accountstatus
- `status_reason`: Begruendung fuer Status
- `banned_until`: optionale Sperrfrist
- `metadata_json`: optionale Metadaten
- `legacy_player_id`: Uebergangsverknuepfung zu `nexa_players.id`
- `created_at`
- `last_login_at`
- `last_logout_at`
- `updated_at`
- `version`

## Status

- `active`
- `suspended`
- `banned`
- `disabled`
- `pending_review`

`pending_review` ist kein harter Ban. Der Account darf technisch weiter existieren, wird aber fuer Admin-Pruefung markiert.

## Regeln

- License ist der primaere technische Identifier.
- Accountstatus wird serverseitig entschieden.
- Clients duerfen keine Account-ID setzen.
- Account-ID wird aus der Session/Identity abgeleitet.
- Gesperrte Accounts werden serverseitig abgelehnt.
- Statuswechsel werden in `nexa_account_status_history` dokumentiert.

## Kompatibilitaet

`legacy_player_id` verbindet die neue Account-Domain mit bestehenden Core-Tabellen, die noch `nexa_players.id` referenzieren. Diese Spalte ist ein Migrationsanker, kein neues Fachmodell.
