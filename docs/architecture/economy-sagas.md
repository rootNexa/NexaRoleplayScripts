# Economy Sagas

Sagas koordinieren Vorgänge, die mehrere Domains betreffen und deshalb nicht in einer einzigen Datenbanktransaktion garantiert werden koennen.

## Verwendete Sagas

- `deposit_cash`: Inventory Remove + Economy Credit.
- `withdraw_cash`: Economy Debit + Inventory Add.
- spaeter: Shop Purchase, Refund, Salary, Tax, Impound Fee.

## Status

- `started`
- `step_completed`
- `completed`
- `compensating`
- `compensated`
- `failed`

## Regeln

Jeder Schritt wird persistiert. Kompensationen sind explizit und auditierbar. Eine Saga darf keine stillen Teilzustaende hinterlassen.
