# Economy Domain Boundary

`nexa_economy` besitzt nur Bankgeld und Buchhaltung. Alles andere bleibt in seiner Fachdomain.

## Economy gehoert

- Account-Definitionen fuer Buchgeld.
- Balance, reserved balance und available balance.
- Transactions und Ledger.
- Reservations.
- Idempotency fuer Geldmutationen.
- Economy-Audit.
- Sagas fuer Cross-Domain-Geldvorgaenge.

## Economy gehoert nicht

- Itemdefinitionen: `nexa_items`.
- Iteminstanzen, Cash und Dirty Cash: `nexa_inventory`.
- Shops und Preise: `nexa_shops`.
- Jobs, Organisationen und Grades: `nexa_jobscreator`.
- UI: `nexa_ui`.
- Character-Identitaet: `nexa_identity` und `nexa_characters`.
- Adminrollen: Core/Permissions/Adminsystem.

## Integrationsregel

Wenn ein Vorgang mehrere Domains aendert, ist Economy nur fuer den Geldteil autoritativ. Die Koordination erfolgt ueber Sagas und idempotente Schritte.
