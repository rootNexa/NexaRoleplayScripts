# Economy Admin

Adminfunktionen duerfen Geld nicht an der Transaction-Engine vorbei veraendern.

## Erlaubte Aktionen

- Konto und Ledger einsehen.
- Administrative Credit-, Debit- oder Adjust-Buchung mit Grund ausfuehren.
- Reservierungen pruefen und bei Bedarf freigeben.
- Audit- und Transaction-Kontext durchsuchen.

## Permissions

Mindestens:

- `nexa.admin.money.view`
- `nexa.admin.money.modify`

Jede mutierende Adminaktion schreibt Audit mit Actor, Source, Character- oder Accountkontext, Grund, Betrag und Correlation-ID.
