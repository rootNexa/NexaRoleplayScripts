# Economy Deposit And Withdraw

Deposit und Withdraw verbinden Inventory und Economy kontrolliert.

## Deposit

1. Serverseitig Character und Inventory bestimmen.
2. Cash-Verfuegbarkeit pruefen.
3. Cash-Item entfernen.
4. Character-Bankkonto sicherstellen.
5. Bank-Credit buchen.
6. Saga als erfolgreich markieren.

Schlaegt der Bank-Credit nach dem Entfernen fehl, versucht die Saga Cash zu kompensieren.

## Withdraw

1. Serverseitig Character-Bankkonto bestimmen.
2. Verfuegbare Bankmittel pruefen.
3. Bank-Debit buchen.
4. Cash-Item ins Inventory legen.
5. Saga als erfolgreich markieren.

Schlaegt Inventory-Add nach dem Debit fehl, versucht die Saga eine Gegenbuchung.

## Sicherheit

Betrag, Source und Character werden serverseitig validiert. Der Client darf nur einen Wunschbetrag senden.
