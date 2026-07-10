# Jobs Current State

Jobs sind vor Kapitel 09 nicht als eigene klare Runtime-Domain vorhanden. Einige Legacy-Ressourcen verwenden Job-, Duty- oder Grade-Begriffe, aber kein zentraler Job-Lifecycle verwaltet Active Job, Duty-Session, Disconnect-Cleanup und Permissions einheitlich.

## Bestehende Bausteine

- `nexa_playerstate` liefert Gameplay-Ready und active Character.
- `nexa_characters` liefert serverseitige Character-Aufloesung.
- `nexa_jobscreator` besitzt Member- und Duty-Felder, aber keine robuste Duty-Session.
- `nexa_permissions` verwaltet OOC-Adminpermissions, nicht IC-Rangrechte.

## Sicherheitsrisiken

- Clientpayloads mit Job, Rang oder Duty duerfen nicht vertraut werden.
- Duty muss aus aktiver Membership und Rank-Permissions abgeleitet werden.
- Disconnect und Resource-Stop muessen Duty-Sessions sauber beenden.

## Ziel

`nexa_jobs` laedt pro Source den aktiven Character, sucht die aktive Membership in `nexa_organizations`, setzt Job-State und verwaltet Duty serverseitig.
