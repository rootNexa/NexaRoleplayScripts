# Economy Money Model

Nexa verwendet ein striktes Integer-Money-Modell. Jeder Betrag wird als ganze Zahl in kleinster Servereinheit gespeichert und verarbeitet.

## Regeln

- Keine Floats in Persistenz, API oder Berechnung.
- Betraege muessen Integer, positiv und innerhalb der konfigurierten Grenzen sein.
- Negative Werte sind nur als interne Ledger-Richtung erlaubt, nicht als API-Betrag.
- Rundung findet nicht in der Economy statt. Aufrufer muessen bereits ganze Werte uebergeben.
- Ueberlauf wird vor jeder Addition oder Subtraktion geprueft.

## Balance

Ein Konto besitzt mindestens:

- `balance`: gesamte gebuchte Kontosumme.
- `reserved_balance`: gesperrter Anteil fuer offene Reservierungen.
- `available_balance`: berechneter Wert `balance - reserved_balance`.

`available_balance` wird nicht blind als Wahrheit gespeichert, sondern bei Abfragen und Buchungspruefungen aus den beiden autoritativen Feldern abgeleitet.

## Konsequenz

Alle Funktionen wie `Credit`, `Debit`, `Transfer`, `Reserve`, `CaptureReservation`, `ReleaseReservation`, `DepositCash` und `WithdrawCash` muessen dieses Modell respektieren. Ein Debit darf nur gegen verfuegbare Mittel laufen.
