# nexa_crime

`nexa_crime` ist die serverautoritative Foundation fuer realistisches illegales Gameplay. Es bildet Profile, Reputation, Heat, Crime-Definitionen, Sessions, Gruppen, Challenges, Tools, Tatorte, Alarme, Loot, gestohlene Items sowie Dispatch- und Evidence-Hooks ab.

Das System erzeugt keine linearen Missionskampagnen und keine ueberzeichneten Heists. Crime ist ein offener RP-Rahmen, in dem Erfolg, Loot, Reputation, Heat und Alarme ausschliesslich serverseitig entschieden werden.

## Gruppen, Challenges, Tools und Locations

Crime-Gruppen sind leader- und memberbasiert, Challenges sind an Source, Character, Session und Phase gebunden, Tools kommen aus Item/Inventory, und Tatorte werden zentral in der Location Registry verwaltet. Diese Bausteine sind die Grundlage fuer Robberies, Drugs, Blackmarket und spaetere Creator-Workflows.

## Dispatch, Evidence und Creator

Responder, Dispatch und Evidence werden ueber registrierbare Resolver, Adapter und Provider angebunden. Der Crime Creator darf Definitionen, Tatorte, Loot, Tools und Risk Policies verwalten, muss aber Actor, Reason, Source-Resource, Correlation-ID und Permission-Kontext liefern.
