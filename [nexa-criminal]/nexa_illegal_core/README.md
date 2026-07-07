# nexa_illegal_core

`nexa_illegal_core` ist die Phase-9A-Basis fuer spaetere illegale Systeme.

## Zweck

- illegale Reputation ueber `nexa_api.criminal`
- serverseitige Illegal-Permissions
- serverseitige Cooldowns ohne Cliententscheidung
- Illegal-Featureflag `phase9a.illegal_core`
- Audit/Logging und Rate-Limits fuer alle externen Anfragen
- minimale `ox_lib`-Interaktion fuer Status/Kontakt

## Grenzen

Nicht enthalten sind Drugs, Blackmarket, Heists, Chopshop, Moneywash, Evidence und Gangs.
Diese spaeteren Systeme muessen ausschliesslich ueber Illegal Core und `nexa_api.criminal` laufen.

## Datenbank

Die Resource schreibt nicht direkt in die Datenbank. Persistente Reputation laeuft ueber `nexa_api.criminal` und die Tabelle `illegal_reputation`.

## Exports

- `illegal.getSnapshot`
- `illegal.adjustReputation`
- `illegal.checkCooldown`
- `illegal.startCooldown`
- `illegal.requestContact`
- `getStatus`

## Events und Callbacks

- `nexa:illegal_core:cb:getSnapshot`
- `nexa:illegal_core:cb:adjustReputation`
- `nexa:illegal_core:cb:checkCooldown`
- `nexa:illegal_core:server:requestSnapshot`
- `nexa:illegal_core:server:requestContact`

Kontakt- und Cooldown-Anfragen loesen den aktiven Charakter serverseitig auf. Alle Anfragen werden serverseitig validiert, rate-limited und bei kritischen Aenderungen auditierbar verarbeitet.
