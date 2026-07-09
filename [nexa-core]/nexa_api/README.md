# nexa_api

`nexa_api` is the Nexa foundation API layer for future resources. It provides a small, dependency-light surface for registry state, resource contracts, normalized callbacks, permission checks, and core player bridges.

## Response Format

All public APIs return one of these shapes:

```lua
{ ok = true, data = value, error = nil }
{ ok = false, data = nil, error = { code = 'CODE', message = 'Text', details = details } }
```

## Server Exports

- `GetApi()`
- `RegisterModule(name, meta)`
- `GetModule(name)`
- `ListModules()`
- `IsModuleReady(name)`
- `SetModuleReady(name, ready)`
- `RegisterContract(name, definition)`
- `GetContract(name)`
- `ListContracts()`
- `ValidateContractPayload(name, payload)`
- `RegisterServerCallback(name, handler, options)`
- `TriggerServerCallback(name, source, payload)`
- `RegisterClientCallback(name, targetSource, handlerName, payload, timeoutMs, cb)`
- `HasPermission(source, permission)`
- `RequirePermission(source, permission)`
- `GetPlayer(source)`
- `GetCharacter(source)`
- `GetIdentifier(source)`

## Client Exports

- `GetApi()`
- `RegisterClientCallback(name, handler)`
- `TriggerServerCallback(name, payload, cb, timeoutMs)`

## Commands

Commands are available from console, in development mode, or to players with `nexa.admin`.

- `/nexaapi`
- `/nexaapimodules`
- `/nexaapicontracts`
- `/nexaapihas <permission>`

## Contract Example

```lua
exports['nexa_api']:RegisterContract('nexa_example', {
    version = '1.0.0',
    events = {},
    callbacks = {},
    exports = {},
    schema = {
        required = { 'name' },
        properties = {
            name = { type = 'string', min = 2, max = 64 },
            amount = { type = 'number', min = 0 }
        }
    }
})
```

## Resource Example

```lua
local Api = exports['nexa_api']:GetApi()

Api.Registry.RegisterModule('nexa_example', {
    version = '1.0.0'
})

Api.Callbacks.RegisterServerCallback('nexa:example:getState', function(source, payload)
    local permission = Api.RequirePermission(source, 'nexa.example.read')

    if not permission.ok then
        return permission
    end

    return { ok = true, data = { state = 'ready' }, error = nil }
end)
```
