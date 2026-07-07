# nexa_worldstates

Phase 10A stellt den World Core bereit:

- zentrale World-State-Verwaltung
- globale Zustaende
- Resource-Zustaende
- serverseitige Validierung
- Rate-Limits
- Audit und Logging
- API-Contracts ueber `nexa_api.world`

Grenzen:

- Keine Maps.
- Keine Interiors.
- Keine Blips.
- Keine Zones.
- Kein NPC-System.
- Keine MLO-spezifische Logik.
- Keine Gameplay-Systeme.

Clients duerfen World States nie final entscheiden. Diese Resource validiert nur Anfragen und leitet sie an `nexa_api.world` weiter; Persistenz laeuft ueber `resource_settings`.
