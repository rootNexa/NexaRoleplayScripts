# Economy Reservations

Reservations sperren verfuegbare Bankmittel fuer spaetere, kontrollierte Buchungen.

## Zweck

Reservierungen werden benoetigt fuer Shops, Auktionen, Rechnungen, Escrow, temporäre Holds und Workflows, bei denen ein Ergebnis erst spaeter feststeht.

## Status

- `active`: Mittel sind gesperrt.
- `captured`: Mittel wurden endgueltig abgebucht.
- `released`: Mittel wurden freigegeben.
- `expired`: TTL ist abgelaufen und die Reservierung wurde bereinigt.

## Regeln

- Reservieren reduziert `available_balance`, nicht `balance`.
- Capture reduziert `balance` und `reserved_balance`.
- Release reduziert nur `reserved_balance`.
- Abgelaufene Reservierungen werden kontrolliert freigegeben.
- Jede Statusaenderung erzeugt Ledger- und Audit-Kontext.
