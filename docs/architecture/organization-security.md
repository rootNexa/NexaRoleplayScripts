# Organization Security

Der Server ist autoritativ.

Verbote:

- Client setzt Organisation.
- Client setzt Rank.
- Client setzt Duty.
- Client setzt Actor oder Character-ID.
- Client setzt Permissions.
- Freie Konto- oder Inventory-ID aus Payload.
- Bypass-Flags.
- direkte oxmysql-Nutzung.
- Framework-Bridges.

Alle mutierenden Aktionen brauchen Actor-Kontext, Reason, Permission- und Hierarchiepruefung sowie Audit.
