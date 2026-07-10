# Identity Architecture

Stand: 2026-07-10

`nexa_identity` ist die serverseitige Account- und Verbindungsidentitaets-Domain.

## Verantwortlichkeiten

- Session zu Account aufloesen
- Account erstellen oder laden
- Identifier normalisieren und aktualisieren
- Accountstatus pruefen
- gesperrte Accounts ablehnen
- Multi-Account-Hinweise erfassen
- Accountdaten cachen
- Session mit Account-ID verbinden

## Nicht verantwortlich

- Charaktererstellung
- Charakterauswahl
- Spawn
- Kleidung
- Inventar
- Geld
- Jobs
- UI

## Lifecycle

1. `nexa-core` erstellt eine Session.
2. `nexa_identity` empfaengt `nexa:internal:session:created`.
3. Identifier werden normalisiert.
4. Account wird per License gesucht oder erstellt.
5. Identifier werden dem Account zugeordnet.
6. Accountstatus wird geprueft.
7. Multi-Account-Signale werden bewertet.
8. Session wird mit `accountId` markiert.
9. `nexa:internal:identity:ready` wird emittiert.
10. Bei Disconnect wird `last_logout_at` gesetzt und Cache bereinigt.

## Exports

- `GetAccount(sourceOrAccountId)`
- `GetAccountId(source)`
- `GetAccountStatus(sourceOrAccountId)`
- `IsAccountReady(source)`

Mutierende Adminfunktionen sind intern und nicht breit exportiert.

## Interne Events

- `nexa:internal:identity:resolving`
- `nexa:internal:identity:ready`
- `nexa:internal:identity:rejected`
- `nexa:internal:identity:statusChanged`

## Fehlercodes

- `ACCOUNT_NOT_FOUND`
- `ACCOUNT_NOT_READY`
- `ACCOUNT_DISABLED`
- `ACCOUNT_SUSPENDED`
- `ACCOUNT_BANNED`
- `IDENTIFIER_MISSING`
- `IDENTIFIER_INVALID`
- `IDENTITY_RESOLUTION_FAILED`
- `MULTI_ACCOUNT_REVIEW_REQUIRED`

## Datenbank

Migration `010_identity_accounts` erstellt:

- `nexa_accounts`
- `nexa_account_identifiers`
- `nexa_account_status_history`
- `nexa_account_review_signals`

Alle Zugriffe laufen ueber `Nexa.Database` aus `nexa-core`.
