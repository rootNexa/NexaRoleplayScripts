# Economy Security

Die Economy ist eine Hochrisiko-Domain. Alle Mutationen sind serverautoritativ.

## Verbote

- Kein Client-trusted Account oder Character.
- Keine direkte Balance-Aenderung ausserhalb der Transaction-Engine.
- Keine Float-Betraege.
- Keine direkten oxmysql-Aufrufe.
- Keine SQL-Stringverkettung mit Benutzereingaben.
- Keine ungefilterten Fehlerdetails an Clients.
- Keine QBCore-, Qbox-, ESX- oder ox_lib-Bridges.

## Schutzmassnahmen

- Permission-Pruefung fuer Adminoperationen.
- Idempotency fuer Retry-sichere Mutationen.
- Ledger fuer jede Balance-Aenderung.
- Audit fuer sicherheitsrelevante Aktionen.
- Reservation-Statusmaschine.
- Server-seitige Source- und Character-Aufloesung.
