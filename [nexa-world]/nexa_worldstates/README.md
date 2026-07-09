# nexa_worldstates

Phase 10A stellt den World Core bereit:

- zentrale World-State-Verwaltung
- globale Zustaende
- Resource-Zustaende
- serverseitige Validierung
- Rate-Limits
- Audit und Logging
- Nexa-Callbacks ueber `nexa_api`

Grenzen:

- Keine Maps.
- Keine Interiors.
- Keine Blips.
- Keine Zones.
- Kein NPC-System.
- Keine MLO-spezifische Logik.
- Keine Gameplay-Systeme.

Clients duerfen World States nie final entscheiden. Diese Resource validiert Anfragen serverseitig und haelt World States im eigenen autoritativen Runtime-Store.
