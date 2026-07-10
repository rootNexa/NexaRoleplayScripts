# Economy Current State

Vor Kapitel 08 existiert keine dedizierte `nexa_economy`-Resource. Finanzlogik ist teilweise in Altressourcen oder in generischen API-Funktionen verteilt.

## Gefundene Bestandteile

- `nexa_banking` existiert als alte Banking-Resource.
- `nexa_banking` nutzt noch `ox_lib` im Manifest und ueber `lib.callback.register`.
- `nexa_banking` delegiert Konto-, Transfer- und Invoice-Funktionen an `nexa_api`.
- `nexa_inventory` existiert als serverautoritative Inventory-Foundation.
- `nexa_items` existiert als zentrale Itemdefinition.
- `nexa_permissions` und Core-Permissions enthalten bereits Adminrechte fuer Geldsicht und Geldmutation.

## Bewertung

Die vorhandene Banking-Resource ist kein geeignetes Zielmodell fuer Kapitel 08, weil sie noch ox_lib-Abhaengigkeiten hat und keine vollstaendige Ledger-, Reservation-, Idempotency- und Saga-Struktur bereitstellt. Sie bleibt vorerst unangetastet und wird spaeter gezielt migriert.

## Risiken

- Mehrere historische Stellen koennten Geldbegriffe besitzen, ohne echte Economy-Grenze zu respektieren.
- Direkte Kontofunktionen in `nexa_api` muessen spaeter auf `nexa_economy` umgeleitet oder deprecated werden.
- Inventory-Cash muss sauber von Bankgeld getrennt bleiben.

## Ziel fuer Kapitel 08

Kapitel 08 fuegt eine neue Foundation hinzu, ohne Altbanking blind umzubauen. Neue Systeme sollen `nexa_economy` verwenden; Migration bestehender Banking-UI oder Legacy-APIs erfolgt erst nach stabiler Runtime-Abnahme.
