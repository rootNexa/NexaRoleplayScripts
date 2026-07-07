# nexa_blips

Phase 10B stellt zentrale Kartenmarkierungen bereit:

- oeffentliche Gebaeude- und Orts-Blips
- Job-Blips
- Fraktions-Blips
- serverseitig gefilterte dynamische Blip-Grundlage
- deutsche/lore-friendly Labels

Grenzen:

- Keine allgemeinen Player-Blips.
- Keine Dispatch-/Einheitenstatus-Ausnahme.
- Keine Zones, Interiors, Maps, NPCs oder Gameplay-Logik.
- Kein direkter Datenbankzugriff.

Der Client rendert ausschliesslich die vom Server gelieferten Blips. Gesperrte Blips werden serverseitig ueber Job, Fraktion und Permission gefiltert.
