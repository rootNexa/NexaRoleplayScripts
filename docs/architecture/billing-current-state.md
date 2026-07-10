# Billing Current State

Vor Kapitel 10 gibt es keine dedizierte `nexa_billing`-Resource. Historische Billing-/Invoice-Logik kann in Banking-, Business-, Government- oder Faction-Ressourcen liegen.

Ziel ist ein neues Rechnungsmodell mit serverseitig berechneten Positionen, klaren Status, Economy-Transfers, Payments, Credits und Audit.

Risiken:

- Client manipuliert Rechnungssumme
- Rechnungsempfaenger wird frei vorgegeben
- Zahlung ohne Statuspruefung
- doppelte Zahlung
- Storno ohne Historie
