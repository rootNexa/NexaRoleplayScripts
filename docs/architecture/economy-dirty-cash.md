# Economy Dirty Cash

Dirty Cash ist physisches Schwarzgeld und wird als Inventory-Item `currency_dirty_cash` gefuehrt.

## Regeln

- Dirty Cash ist nicht automatisch einzahlbar.
- Es darf nicht in normalen Bankkonten als Currency erscheinen.
- Add/Remove-Funktionen sind serverseitige Integrationshelfer fuer spaetere Crime-, Evidence- oder Adminmodule.
- Jede administrative Aenderung muss auditierbar bleiben.

## Zukunft

Reinigung, Beschlagnahme, Markierung, Serialisierung und Ermittlungsfunktionen werden spaeter ueber eigene Module modelliert, nicht im Economy-Core versteckt.
