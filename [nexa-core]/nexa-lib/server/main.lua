local RESOURCE = GetCurrentResourceName()

function GetLib()
    return NexaLib
end

function Logger()
    return NexaLib.Logger
end

function Response()
    return NexaLib.Response
end

function Validate()
    return NexaLib.Validate
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    NexaLib.Logger.info(RESOURCE, 'nexa-lib started.', {
        version = NexaLib.Version
    })
end)
