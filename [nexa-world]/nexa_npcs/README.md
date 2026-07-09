# nexa_npcs

NPC- und Interaction-Registry fuer Nexa Roleplay.

Phase 10F umfasst nur:

- NPC-Registry
- einfache Ped-Konfiguration als Datenstruktur
- Interaktionspunkte
- Nexa-eigene Interaktionsgrundlage ohne Fremd-Target-Abhaengigkeit
- Permission-/Job-/Faction-Filter
- deutsche und lore-freundliche Labels
- Audit und Logging fuer Registry- und Interaktionsvalidierung

Nicht enthalten:

- komplexe NPC-KI
- Shops
- Quest-Systeme
- illegale Haendler
- Polizei-/EMS-NPCs als Gameplay
- neue Jobs

NPCs sind nur registrierte Interaktionspunkte. Kritische Aktionen muessen spaeter ueber die jeweilige Fach-API validiert und ausgefuehrt werden; der Client entscheidet keine Permissions final.
