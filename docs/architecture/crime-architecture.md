# Crime Architecture

Nexa Crime bildet realistische offene Straftaten ab, keine linearen Missionskampagnen. `nexa_crime` ist die zentrale Foundation fuer Profile, Reputation, Heat, Sessions, Gruppen, Challenges, Tools, Tatorte, Alarme, Loot, gestohlene Items, Dispatch-Hooks, Evidence-Hooks und Creator/Admin-Grenzen.

Abhaengigkeiten laufen nach unten zu Core, Characters, PlayerState, Permissions, Items, Inventory, Economy, Vehicles, Properties und Jobframework. Police, Dispatch und Evidence werden ueber Hooks oder Adapter angebunden, nicht hart verdrahtet.
