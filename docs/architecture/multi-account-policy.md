# Multi-Account Policy

Stand: 2026-07-10

Multi-Accounting wird als Risikomodell behandelt. `nexa_identity` sperrt nicht automatisch anhand schwacher Signale.

## Signale

| Signal | Staerke | Entscheidung |
| --- | --- | --- |
| gleiche License | stark | `pending_review` |
| gleiche License2 | stark | `pending_review` |
| gleiche Discord-ID | stark | `pending_review` |
| gleiche FiveM-ID | stark | `pending_review` |
| gleiche Steam-ID | mittel | Signal erfassen |
| wiederholt gleiche IP | schwach | nicht als permanenter Identifier speichern |
| Namensaehnlichkeit | kein Signal | ignorieren |

## Regeln

- Keine automatische Sperre nur wegen gleicher IP.
- Keine automatische Sperre nur wegen fehlendem Discord.
- Keine Hardware-ID.
- Unsichere Faelle werden zur Pruefung markiert.
- Jede Entscheidung wird auditierbar gespeichert.
- Identifier in Evidence werden maskiert.

## Tabelle `nexa_account_review_signals`

- `account_id`
- `signal_type`
- `strength`
- `related_account_id`
- `decision`
- `evidence_json`
- `actor`
- `created_at`

## Admin-Pruefung

Admins sollen spaeter sehen:

- warum ein Account markiert wurde
- welche Signalstaerke vorliegt
- welche Account-IDs betroffen sind
- wann die Markierung entstanden ist
- welcher Actor die Entscheidung ausgeloest hat

Die UI fuer diese Pruefung ist nicht Teil dieses Kapitels.
