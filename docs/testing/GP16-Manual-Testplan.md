# GP16 Manual Testplan

## Zwei-Spieler-Tests

1. EMS inspiziert einen verletzten Spieler, startet Treatment und dokumentiert Krankenhausakte.
2. Polizei fesselt, eskortiert und transportiert einen Spieler.
3. Polizei fuehrt Durchsuchung und Beschlagnahme mit Evidence-Verknuepfung aus.
4. Dispatch erstellt Call, setzt Unit Status, weist Unit zu und loest Panic aus.
5. MDT erstellt Case, Report, BOLO und Warrant.
6. Evidence wird gesammelt, verpackt, in Locker gelegt und analysiert.
7. Lizenz wird ausgestellt, suspendiert, wieder eingesetzt und entzogen.

## Erwartung

Alle Mutationen laufen serverseitig, erzeugen strukturierte Responses und bleiben nach Resource-Restart persistiert.
