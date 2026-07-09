# nexa_zones

Zentrale Zonenverwaltung fuer Nexa Roleplay.

Phase 10C umfasst nur:

- Poly-, Box- und Sphere-Zones als Struktur
- eigenes clientseitiges Zone-Tracking ohne Fremd-Zonenbibliothek
- serverseitig gefilterte Zonenlisten
- Betreten-/Verlassen-Meldungen als nicht-autoritative Client-Signale
- serverseitige Validierung kritischer Zonenaktionen
- Permission-Zonen
- Safezones als vorbereitete Grundlage
- Rate-Limits, Audit und Logging

Nicht enthalten:

- Interiors
- Maps
- NPCs
- komplexe Gameplay-Zonen
- illegale Systeme

Der Client entscheidet keinen kritischen Zonenstatus. Kritische Aktionen muessen `zones.validateCriticalAction` nutzen.
