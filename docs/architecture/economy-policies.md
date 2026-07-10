# Economy Policies

Policies definieren technische und fachliche Grenzen der Economy.

## Grundregeln

- Kein Client darf Account-IDs, Character-IDs oder Balancewerte autoritativ setzen.
- Adminoperationen benoetigen serverseitige Permission-Pruefung und Audit-Grund.
- Bankgeld darf nicht direkt in Inventory-Items gespiegelt werden.
- Cash und Dirty Cash duerfen nicht als Bankkonto gefuehrt werden.
- Jede Mutation braucht Kategorie, Grund oder Systemkontext.

## Limits

Konfigurationen bestimmen maximale Betraege, Reservierungs-TTL, Debug-Logging und erlaubte Accounttypen. Defaults sind konservativ. Runtime-Aenderungen erfolgen nur kontrolliert.
