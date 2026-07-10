# nexa_identity

Serverseitige Account- und Verbindungsidentitaet fuer Nexa Roleplay.

## Zweck

- Session zu Account aufloesen
- Account erstellen oder laden
- Identifier normalisieren und zuordnen
- Accountstatus pruefen
- gesperrte Accounts ablehnen
- Multi-Account-Hinweise erfassen
- Accountdaten cachen
- Session mit Account-ID verbinden

Nicht enthalten:

- Charaktererstellung
- Charakterauswahl
- Spawn
- Kleidung
- Inventar
- Geld
- Jobs
- UI

## Abhaengigkeiten

- `nexa-core`

Alle Datenbankzugriffe laufen ueber `exports['nexa-core']:GetCoreObject().Database`.

## Accountstatus

- `active`
- `suspended`
- `banned`
- `disabled`
- `pending_review`

## Identifier

Unterstuetzt werden:

- `license`
- `license2`
- `fivem`
- `discord`
- `steam`

IP-Adressen werden nicht als Account-Identifier gespeichert. Hardware-IDs werden nicht verwendet.

## Exports

- `GetAccount(sourceOrAccountId)`
- `GetAccountId(source)`
- `GetAccountStatus(sourceOrAccountId)`
- `IsAccountReady(source)`

Mutierende Adminfunktionen werden nicht breit exportiert.

## Interne Events

- `nexa:internal:identity:resolving`
- `nexa:internal:identity:ready`
- `nexa:internal:identity:rejected`
- `nexa:internal:identity:statusChanged`

## Datenbanktabellen

- `nexa_accounts`
- `nexa_account_identifiers`
- `nexa_account_status_history`
- `nexa_account_review_signals`

Migrationen werden append-only ueber den Core-Migrationslayer registriert.

## Multi-Accounting

`nexa_identity` erfasst Signale, sperrt aber nicht hart nur anhand schwacher Hinweise.

- gleiche License: stark
- gleiche Discord/FiveM: stark
- gleiche Steam: mittel
- gleiche IP: wird nicht als permanenter Identifier verwendet

Unsichere Faelle koennen `pending_review` erhalten. Identifier werden in Logs maskiert.

## Grenzen

Charaktere gehoeren in `nexa_characters`. Diese Resource verwaltet nur Account und Verbindungsidentitaet.
