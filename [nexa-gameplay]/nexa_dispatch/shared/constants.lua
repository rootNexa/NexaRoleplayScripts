NEXA_DISPATCH = { resourceName = 'nexa_dispatch', version = '0.5.0' }
NEXA_DISPATCH_CALL_STATUS = { created = 'created', assigned = 'assigned', enroute = 'enroute', on_scene = 'on_scene', closed = 'closed', cancelled = 'cancelled' }
NEXA_DISPATCH_UNIT_STATUS = { available = 'available', busy = 'busy', enroute = 'enroute', on_scene = 'on_scene', offline = 'offline' }
NEXA_DISPATCH_EVENTS = { callCreated = 'nexa:internal:dispatch:callCreated', unitAssigned = 'nexa:internal:dispatch:unitAssigned', callStatusChanged = 'nexa:internal:dispatch:callStatusChanged', unitStatusChanged = 'nexa:internal:dispatch:unitStatusChanged' }
NEXA_DISPATCH_ERRORS = { callNotFound = 'DISPATCH_CALL_NOT_FOUND', unitNotFound = 'DISPATCH_UNIT_NOT_FOUND', statusInvalid = 'DISPATCH_STATUS_INVALID', invalidInput = 'DISPATCH_INVALID_INPUT', databaseError = 'DISPATCH_DATABASE_ERROR' }
