NexaApiClient = {
    Version = NexaApiConstants.version,
    Callbacks = NexaApiClientCallbacks
}

local function normalizeExportArgs(...)
    local args = { ... }

    if type(args[1]) == 'table' then
        table.remove(args, 1)
    end

    return table.unpack(args)
end

function GetApi(...)
    normalizeExportArgs(...)
    return NexaApiClient
end

function RegisterClientCallback(...)
    local name, handler = normalizeExportArgs(...)
    return NexaApiClient.Callbacks.RegisterClientCallback(name, handler)
end

function TriggerServerCallback(...)
    local name, payload, cb, timeoutMs = normalizeExportArgs(...)
    return NexaApiClient.Callbacks.TriggerServerCallback(name, payload, cb, timeoutMs)
end
