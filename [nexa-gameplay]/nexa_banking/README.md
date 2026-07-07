# nexa_banking

Phase 4C Banking-Resource fuer private Konten, Kontenuebersicht, Transaktionshistorie, Ueberweisungen und Rechnungszahlungen.

## Abhaengigkeiten

- ox_lib
- nexa_api
- nexa_audit
- nexa_security
- nexa_logs

## Architekturgrenze

`nexa_banking` veraendert keine Geldstaende direkt. Alle Geldbewegungen laufen ausschliesslich ueber `nexa_api.account`.

## Callbacks

- `nexa:banking:cb:getAccounts`
- `nexa:banking:cb:createPrivateAccount`
- `nexa:banking:cb:getTransactions`
- `nexa:banking:cb:requestTransfer`
- `nexa:banking:cb:getInvoices`
- `nexa:banking:cb:payInvoice`

## Events

- `nexa:banking:server:requestCreatePrivateAccount`
- `nexa:banking:server:requestTransfer`
- `nexa:banking:server:requestPayInvoice`
- `nexa:banking:client:openMenu`
- `nexa:banking:client:requestResult`

## Datenbanktabellen

- accounts
- account_members
- bank_transactions
- economy_ledger
- invoices

## Sicherheitsregeln

- Keine negativen oder dezimalen Betraege.
- Keine Client-Entscheidung ueber Kontostand, Rechte oder Rechnungstatus.
- Transfer, Ledger und Bankhistorie werden atomar in `nexa_api.account` geschrieben.
- Zugriff auf Konten wird serverseitig ueber Owner oder aktive `account_members` geprueft.
- Alle clientseitig ausloesbaren Aktionen nutzen `nexa_security` Rate-Limits.
- Rechnungszahlungen locken die Rechnung serverseitig und verhindern doppelte Zahlung durch Status-Recheck in derselben Transaktion.
