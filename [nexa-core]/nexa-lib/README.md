# nexa-lib

Standalone utility library for Nexa Framework resources.

`nexa-lib` has no dependency on `nexa-core`, database resources, inventory resources, or legacy framework resources. It is intended to replace small utility use cases that would otherwise require external framework libraries.

## Exports

- `exports['nexa-lib']:GetLib()`
- `exports['nexa-lib']:Logger()`
- `exports['nexa-lib']:Response()`
- `exports['nexa-lib']:Validate()`

## APIs

- `NexaLib.Logger.info(resource, message, data)`
- `NexaLib.Logger.warn(resource, message, data)`
- `NexaLib.Logger.error(resource, message, data)`
- `NexaLib.Logger.debug(resource, message, data)`
- `NexaLib.Response.ok(data)`
- `NexaLib.Response.fail(code, message, details)`
- `NexaLib.Validate.isString(value)`
- `NexaLib.Validate.isNonEmptyString(value)`
- `NexaLib.Validate.maxLength(value, max)`
- `NexaLib.Validate.isNumber(value)`
- `NexaLib.Validate.isInteger(value)`
- `NexaLib.Validate.isBoolean(value)`
- `NexaLib.Validate.isDate(value)`
- `NexaLib.Validate.sanitizeString(value)`
- `NexaLib.Table.shallowCopy(value)`
- `NexaLib.Table.deepCopy(value)`
- `NexaLib.Table.count(value)`
- `NexaLib.Table.contains(value, needle)`
- `NexaLib.Table.merge(base, overlay)`
- `NexaLib.String.trim(value)`
- `NexaLib.String.lower(value)`
- `NexaLib.String.upper(value)`
- `NexaLib.String.startsWith(value, prefix)`
- `NexaLib.String.endsWith(value, suffix)`
- `NexaLib.Math.clamp(value, min, max)`
- `NexaLib.Math.round(value, decimals)`
- `NexaLib.ServerCallbacks.Register(name, handler)`
- `NexaLib.ServerCallbacks.Trigger(source, name, payload, cb, timeoutMs)`
- `NexaLib.ClientCallbacks.Register(name, handler)`
- `NexaLib.ClientCallbacks.Trigger(name, payload, cb, timeoutMs)`
- `NexaLib.ServerEvents.Register(name, handler, options)`
- `NexaLib.ServerEvents.Emit(source, name, payload)`
- `NexaLib.ClientEvents.Register(name, handler)`
- `NexaLib.ClientEvents.Emit(name, payload)`

## Development Order

```cfg
ensure oxmysql
ensure chat
ensure nexa-lib
ensure nexa-core
ensure nexa-character
ensure nexa-identity
ensure nexa-spawn
ensure nexa-core-test
ensure nexa-character-test
```
