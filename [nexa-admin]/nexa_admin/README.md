# nexa_admin

Admin-Core-Grundstruktur fuer Nexa Roleplay.

Phase 11A umfasst:

- Admin-Rollen und Admin-Permissions als serverseitige Struktur
- minimale Admin-Menue-Grundstruktur ueber ox_lib
- Spieleruebersicht
- sichere Admin-Aktions-Contracts ohne Ausfuehrung kritischer Aktionen
- Audit und Logging fuer Admin-Zugriffe und Contract-Validierungen
- Rate-Limits und Featureflag

Nicht enthalten:

- Tickets
- Teleport
- Ban-System
- Anticheat
- Devtools

Phase 11B ergaenzt:

- Report erstellen
- eigene Reports anzeigen
- Reports mit Admin-Permission anzeigen
- Reports annehmen
- Reports schliessen
- Report-Historie

Reports sind serverseitige Laufzeitdaten in `nexa_admin`. Spieler sehen nur eigene Reports. Admins sehen, bearbeiten und schliessen Reports nur mit expliziten Admin-Permissions. Jede Admin-Reportaktion wird auditierbar protokolliert.

Spieler koennen Reports ueber den eigenen Report-Command erstellen und ihre eigenen Reports anzeigen. Das Admin-Menue bleibt Admins mit `admin.menu` vorbehalten.

Phase 11C ergaenzt:

- `/ticket`
- Ticket-Grund
- Ticketliste fuer Admins
- Ticketstatus
- Ticketzuweisung
- Ticket schliessen

Tickets sind serverseitige Laufzeitdaten in `nexa_admin`. Spieler koennen Tickets erstellen. Admins sehen, weisen zu und schliessen Tickets nur mit expliziten `admin.tickets.*` Permissions. Discord-Tickets, Webpanel, Anticheat und Ban-System sind nicht enthalten.

Phase 11D ergaenzt:

- Warn
- Kick
- Tempban-Vorbereitung
- Spieler einfrieren und freigeben
- Spectate-Vorbereitung
- Admin-Notizen

Moderationsaktionen laufen ausschliesslich ueber serverseitige `admin.moderation.*` Contracts. Jede Aktion wird auditierbar protokolliert und rate-limitiert. Tempban und Spectate sind nur vorbereitete, auditierte Strukturen; ein vollstaendiges Anticheat-Ban-System, Screenshot-System, Executor Detection und Devtools sind nicht enthalten.

Phase 11E ergaenzt:

- Bring
- GoTo
- Return
- Koordinaten-Teleport
- Admin-Heal-Vorbereitung
- Admin-Revive-Vorbereitung

Admin-Utilities laufen ausschliesslich ueber serverseitige `admin.utility.*` Contracts mit Permission, Audit und Rate-Limit. Teleports werden serverseitig autorisiert und nur als freigegebene Client-Wirkung ausgefuehrt. Admin-Heal und Admin-Revive sind vorbereitete, auditierte Utilities; EMS-Logik, vollstaendige Revive-Systeme, Godmode-Systeme, Anticheat und Devtools sind nicht enthalten.

Der Client darf Adminrechte nur fuer Anzeigezwecke anfragen. Jede Adminfunktion wird serverseitig ueber `nexa_permissions`, `nexa_security`, `nexa_audit` und `nexa_api` validiert. Die Resource nutzt keine direkten Client-DB-Zugriffe und startet keine Production-Devtools.
