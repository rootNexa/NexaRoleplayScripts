# Economy Transactions

Transactions sind die atomaren Economy-Operationen.

## Typen

- `credit`: Geld auf ein Konto buchen.
- `debit`: Geld von einem Konto abbuchen.
- `transfer`: Geld zwischen zwei Konten bewegen.
- `adjust`: administrative Korrektur.
- `reverse`: kontrollierte Gegenbuchung einer frueheren Transaktion.
- `reservation_capture`: reservierte Mittel endgueltig abbuchen.
- `reservation_release`: Reservierung freigeben.

## Ablauf

1. Request validieren.
2. Idempotency-Key pruefen.
3. Konten laden und sperren.
4. Verfuegbarkeit pruefen.
5. Transaction-Record erzeugen.
6. Balance innerhalb einer Datenbanktransaktion aktualisieren.
7. Ledger-Zeilen schreiben.
8. Audit-Kontext schreiben.
9. Ergebnis mit sicherem Fehlerformat zurueckgeben.

## Fehler

Fehler duerfen keine SQL-Details, Secrets oder interne Stacktraces an Clients liefern. Interne Logs enthalten strukturierte, maskierte Details.
