# Core Callbacks

Stand: 2026-07-10

`nexa-core` besitzt ein kontrolliertes Callback- und Request-System fuer eindeutige Request/Response-Flows. Es trennt interne Servercallbacks von Netzwerkcallbacks.

## Zweck

Das System ist gedacht fuer:

- serverinterne Requests mit eindeutiger Antwort
- Client-zu-Server-Requests
- Server-zu-Client-Requests, wenn sie fachlich sinnvoll sind
- Timeout- und Fehlerbehandlung
- Source-Bindung fuer Netzwerkantworten
- Rate-Limits und Payload-Validierung fuer Netzwerkrequests

## Rueckgabeformat

Erfolg:

```lua
{
    ok = true,
    data = {}
}
```

Fehler:

```lua
{
    ok = false,
    error = {
        code = 'ERROR_CODE',
        message = 'Safe public message'
    }
}
```

Interne Fehler duerfen in internen Antworten Details enthalten. Antworten an Clients werden sanitisiert.

## Interne Callbacks

```lua
Nexa.Callbacks.Register('nexa:core:cb:example', function(payload, context)
    return {
        ok = true,
        data = {
            value = payload.value
        }
    }
end)

local response = Nexa.Callbacks.Call('nexa:core:cb:example', {
    value = 1
}, {
    module = 'example'
})
```

API:

- `Nexa.Callbacks.Register(name, handler, options)`
- `Nexa.Callbacks.Unregister(name)`
- `Nexa.Callbacks.Call(name, payload, context)`
- `Nexa.Callbacks.CallAwait(name, payload, context)`
- `Nexa.Callbacks.Has(name)`

`CallAwait` ist fuer Kompatibilitaet vorhanden. Interne Calls laufen synchron.

## Netzwerkcallbacks

Client zu Server:

```lua
Nexa.Callbacks.RegisterNetwork('nexa:core:cb:getSession', function(source, payload, context)
    -- source ist die echte FiveM-source
end, {
    rateLimitMs = 1000,
    validate = function(payload)
        return type(payload) == 'table'
    end
})
```

Server zu Client:

```lua
Nexa.Callbacks.TriggerClient(source, 'nexa:core:cb:clientState', {}, function(response)
    if response.ok then
        -- response.data
    end
end)
```

Await-kompatibel:

```lua
local response = Nexa.Callbacks.TriggerClientAwait(source, 'nexa:core:cb:clientState', {})
```

Clientseitig:

```lua
NexaClient.Callbacks.Trigger('nexa:core:cb:getSession', {}, function(response)
    -- response.ok
end)

local response = NexaClient.Callbacks.TriggerAwait('nexa:core:cb:getSession', {})
```

## Sicherheitsregeln

- Callbacknamen muessen dem Nexa-Namespace folgen: `nexa:<resource>:cb:<name>`.
- Clients duerfen nur explizit registrierte Netzwerkcallbacks aufrufen.
- Interne und externe Callback-Registry sind getrennt.
- Der Server verwendet immer die echte FiveM-`source`.
- Eine vom Client gesendete Source-ID wird ignoriert.
- Netzwerkrequests koennen `validate(payload)` nutzen.
- Netzwerkrequests werden rate-limited.
- Serverfehler werden vor Clientantworten sanitisiert.
- Unbekannte Responses werden geloggt und ignoriert.
- Responses mit falscher Source werden als Security-Event geloggt und blockiert.
- Pending Requests werden beim ersten gueltigen Response entfernt.
- Disconnects loesen ausstehende Server-zu-Client-Requests mit `DISCONNECTED` auf.

## Fehlercodes

Haeufige Fehlercodes:

- `INVALID_INPUT`
- `INVALID_PAYLOAD`
- `NOT_FOUND`
- `RATE_LIMITED`
- `TIMEOUT`
- `DISCONNECTED`
- `HANDLER_ERROR`
- `INTERNAL_ERROR`
- `AWAIT_UNAVAILABLE`
- `CORE_NOT_READY`

## Abgrenzung

Das Callback-System ist nicht fuer ungepruefte Events oder Broadcasts gedacht. Fuer lose serverinterne Benachrichtigungen gibt es `Nexa.EventBus`. Fuer Client/Server-Events ohne eindeutige Antwort bleiben validierte Net-Events zustaendig.
