# nexa_blackmarket

`nexa_blackmarket` ist die serverautoritative Foundation fuer versteckte Maerkte, Hehler, Dirty-Cash-Commerce und Geldwaesche-Sagas.

Preise, Zugang, Hehlerangebote und Geldwaeschebeträge werden serverseitig berechnet. Economy- und Inventory-Auswirkungen sind als Saga-Grenzen vorbereitet und duerfen nicht aus Clientwerten entstehen.

## Laundering

Geldwaeschejobs speichern Betrag, Fee, Payout, Status, Completion-Zeit, Idempotency-Key und Correlation-ID. Auszahlung und Dirty-Cash-Verbrauch bleiben Saga-Schritte und werden nicht direkt aus Clientdaten ausgefuehrt.
