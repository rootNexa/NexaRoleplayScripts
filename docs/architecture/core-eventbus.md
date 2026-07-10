# Core Event Bus

Stand: 2026-07-10

`nexa-core` besitzt einen internen serverseitigen Event-Bus unter `Nexa.EventBus`. Er dient der losen Kopplung von Core-Modulen und serverinternen Framework-Benachrichtigungen.

## Zweck

Der Event-Bus ist gedacht fuer:

- Kommunikation innerhalb des Servers
- Lifecycle-Ereignisse
- Session-Ereignisse
- lose Kopplung von Core-Modulen
- kontrollierte interne Benachrichtigungen

Er ist nicht als Ersatz fuer alle FiveM-Events gedacht.

## Abgrenzung

Netzwerkkommunikation zwischen Client und Server bleibt separat:

- Server-Net-Events laufen weiter ueber `Nexa.Events.RegisterNet`.
- Client-Events laufen weiter ueber `TriggerClientEvent` oder `Nexa.Events.EmitClient`.
- Netzwerkpayloads muessen weiterhin Source, Session, Permissions und Daten validieren.
- Der interne Event-Bus darf keine ungeprueften Clientdaten direkt weiterreichen.

## API

```lua
Nexa.EventBus.On(name, callback, options)
Nexa.EventBus.Once(name, callback, options)
Nexa.EventBus.Off(subscriptionId)
Nexa.EventBus.Emit(name, payload, context)
Nexa.EventBus.HasListeners(name)
Nexa.EventBus.GetListenerCount(name)
```

Kompatibilitaet:

```lua
Nexa.Events.EmitInternal(name, payload, context)
```

## Namenskonvention

Interne Events muessen diesem Muster folgen:

```text
nexa:internal:<bereich>:<ereignis>
```

Beispiele:

- `nexa:internal:core:ready`
- `nexa:internal:core:failed`
- `nexa:internal:core:stopping`
- `nexa:internal:session:created`
- `nexa:internal:session:removed`

Andere Namen werden blockiert.

## Listener

```lua
local subscriptionId = Nexa.EventBus.On('nexa:internal:core:ready', function(payload, context)
    Nexa.Logger.Info('example.ready', 'Core ist bereit.', {
        environment = payload.environment,
        event = context.event
    })
end, {
    priority = 10,
    metadata = {
        module = 'example'
    }
})
```

Optionen:

- `priority`: hoehere Werte laufen zuerst.
- `async`: Listener wird kontrolliert in einem Thread ausgefuehrt.
- `failFast`: Fehler stoppt den synchronen Dispatch.
- `metadata`: strukturierte Listener-Metadaten fuer Diagnose.
- `debug`: Registrierungsdetails werden geloggt.
- `maxListeners`: optionales Limit fuer dieses Event.

## Once-Listener

```lua
Nexa.EventBus.Once('nexa:internal:core:ready', function()
    -- laeuft nur einmal
end)
```

Once-Listener werden vor der Ausfuehrung entfernt, damit rekursive Emits sie nicht mehrfach ausloesen.

## Fehlerverhalten

Listener laufen mit `pcall`. Fehler:

- werden strukturiert geloggt
- stoppen andere Listener nicht automatisch
- werden im Dispatch-Ergebnis gesammelt

Kritische Listener koennen `failFast = true` setzen. Dann endet der synchrone Dispatch nach dem ersten Fehler.

Asynchrone Listener werden isoliert ausgefuehrt. Ihre Fehler werden geloggt, aber nicht in das synchrone Emit-Ergebnis zurueckgegeben.

## Rekursionsschutz

Der Event-Bus trackt Dispatch-Tiefe pro Event. Standardlimit:

```lua
Nexa.EventBus.maxDepth = 8
```

Wird das Limit ueberschritten, wird der Emit blockiert und `RECURSION_LIMIT` geliefert.

## Listener-Limit

Standardlimit:

```lua
Nexa.EventBus.maxListeners = 32
```

Wird das Limit erreicht, gibt `On` oder `Once` `nil, 'MAX_LISTENERS'` zurueck.

## Aktuelle Core-Events

`nexa-core` emittiert aktuell:

- `nexa:internal:core:ready`
- `nexa:internal:core:failed`
- `nexa:internal:core:stopping`
- `nexa:internal:session:created`
- `nexa:internal:session:removed`

Diese Events enthalten serverseitig erzeugte Payloads und keine ungeprueften Clientdaten.
