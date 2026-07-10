# Economy Ledger

Der Ledger ist die unveraenderliche Buchungshistorie. Jede erfolgreiche Balance-Aenderung erzeugt mindestens eine Ledger-Zeile.

## Ledger-Zeile

Eine Ledger-Zeile enthaelt:

- Konto
- Transaktion
- Richtung oder Delta
- Betrag
- Balance vor der Buchung
- Balance nach der Buchung
- Currency
- Kategorie
- Actor-Kontext
- Correlation-ID
- Zeitpunkt

## Regeln

- Ledger-Zeilen werden nicht nachtraeglich bearbeitet.
- Reversals erzeugen neue gegenlaeufige Buchungen statt alte Buchungen zu loeschen.
- Transfer erzeugt eine Debit-Zeile beim Quellkonto und eine Credit-Zeile beim Zielkonto.
- Admin-Korrekturen muessen mit Grund und Audit-Kontext geschrieben werden.

## Zweck

Der Ledger dient Revisionssicherheit, Support, Admin-Audit, Fehlersuche und spaeteren Reports. Er ist nicht als schneller Balance-Cache gedacht.
