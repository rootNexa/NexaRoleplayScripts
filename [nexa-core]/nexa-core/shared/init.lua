Nexa = Nexa or {}
Nexa.Constants = NEXA_CONSTANTS
Nexa.Config = NexaConfig
Nexa.Version = NEXA_CONSTANTS.version

function Nexa.Response(success, code, message, data, meta)
    return {
        success = success == true,
        code = code or (success and NEXA_CONSTANTS.errors.ok or NEXA_CONSTANTS.errors.internal),
        message = message or '',
        data = data,
        meta = meta
    }
end
