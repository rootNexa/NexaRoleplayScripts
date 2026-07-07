# nexa_dispatch

Eigenstaendiges Dispatch- und Notrufsystem fuer Phase 4E.

## Umfang

- Notrufe in `dispatch_calls`
- Call-Lifecycle: `open`, `assigned`, `closed`, `cancelled`
- Prioritaeten 1 bis 5
- Zuweisungen ueber `dispatch_calls.metadata.assigned_units`
- Fraktions-/Job-Zugriff serverseitig ueber `nexa_api.dispatch`
- Spam-Schutz ueber `nexa_security`
- Audit ueber `nexa_audit`
- minimale ox_lib-Interaktion per `/nexadispatch`

## Grenzen

- Kein Polizei-Gameplay
- Kein EMS-Gameplay
- Kein MDT
- Kein Handy
- Keine Fahrzeuge, Housing- oder illegalen Systeme
- Keine grosse UI

## Events und Callbacks

- `nexa:dispatch:server:requestCreateCall`
- `nexa:dispatch:server:requestAssign`
- `nexa:dispatch:server:requestStatus`
- `nexa:dispatch:server:requestPriority`
- `nexa:dispatch:cb:createCall`
- `nexa:dispatch:cb:listCalls`
- `nexa:dispatch:cb:assignCall`
- `nexa:dispatch:cb:updateStatus`
- `nexa:dispatch:cb:setPriority`

## Permissions

- `dispatch.view`
- `dispatch.create`
- `dispatch.assign`
- `dispatch.status`
- `dispatch.priority`
- `dispatch.manage`

Notrufe von Spielern benoetigen keine Client-Rechteentscheidung. Der Server prueft Quelle, aktiven Charakter, Payload und Rate-Limit.
