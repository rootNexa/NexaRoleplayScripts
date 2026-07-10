# Economy Idempotency

Idempotenz verhindert doppelte Buchungen bei Retries, Timeouts oder wiederholten Clientaktionen.

## Key

Jede externe mutierende Operation kann einen `idempotency_key` uebergeben. Der Key wird zusammen mit Operation, Actor und relevanter Payload gespeichert. Wird derselbe Key erneut gesehen, liefert die Economy das urspruengliche Ergebnis zurueck.

## Regeln

- Ein Key darf nicht fuer verschiedene Operationen wiederverwendet werden.
- Konflikte erzeugen einen sicheren Fehler.
- Erfolgreiche und fehlgeschlagene finale Ergebnisse werden nachvollziehbar gespeichert.
- Idempotenz gilt fuer Credit, Debit, Transfer, Reservation, Capture, Release, Deposit und Withdraw.

## Retry

Aufrufer duerfen nach Netzwerk- oder Timeoutfehlern erneut mit demselben Key aufrufen. Die Engine entscheidet, ob ein bestehendes Ergebnis vorliegt oder der Vorgang fortgesetzt werden muss.
