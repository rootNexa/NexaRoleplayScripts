NexaApi = {
    Version = NexaApiConstants.version,
    Registry = NexaApiRegistry,
    Contracts = NexaApiContracts,
    Callbacks = NexaApiCallbacks
}

local function resourceStarted(name)
    return GetResourceState(name) == 'started'
end

local function normalizeExternalResponse(result, defaultKey)
    if type(result) == 'table' and result.ok ~= nil then
        return result
    end

    if type(result) == 'table' and result.success ~= nil then
        if result.success then
            return NexaApiResponse.ok(result.data)
        end

        return NexaApiResponse.fail(result.code, result.message, result.meta)
    end

    if defaultKey then
        return NexaApiResponse.ok({
            [defaultKey] = result
        })
    end

    return NexaApiResponse.ok(result)
end

local function normalizeExportArgs(...)
    local args = { ... }

    if type(args[1]) == 'table' then
        table.remove(args, 1)
    end

    return table.unpack(args)
end

function NexaApi.HasPermission(source, permission)
    source = tonumber(source)

    if not source or source <= 0 or type(permission) ~= 'string' or permission == '' then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Permission check input is invalid.')
    end

    if resourceStarted('nexa_permissions') then
        local ok, result = pcall(function()
            return exports['nexa_permissions']:Has(source, permission)
        end)

        if ok then
            local response = normalizeExternalResponse(result)
            local allowed = response.ok and response.data and response.data.allowed == true
            return NexaApiResponse.ok({
                allowed = allowed,
                permission = permission
            })
        end
    end

    if resourceStarted('nexa-core') then
        local ok, result = pcall(function()
            return exports['nexa-core']:HasPermission(source, permission)
        end)

        if ok then
            return NexaApiResponse.ok({
                allowed = result == true,
                permission = permission
            })
        end
    end

    return NexaApiResponse.ok({
        allowed = false,
        permission = permission
    })
end

function NexaApi.RequirePermission(source, permission)
    local response = NexaApi.HasPermission(source, permission)

    if not response.ok then
        return response
    end

    if response.data.allowed then
        return response
    end

    return NexaApiResponse.fail(NexaApiConstants.errors.forbidden, 'Permission denied.', {
        permission = permission
    })
end

function NexaApi.GetPlayer(source)
    source = tonumber(source)

    if not source or source <= 0 then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Source is invalid.')
    end

    if not resourceStarted('nexa-core') then
        return NexaApiResponse.fail(NexaApiConstants.errors.notFound, 'nexa-core is not started.')
    end

    local ok, result = pcall(function()
        return exports['nexa-core']:GetPlayer(source)
    end)

    if not ok then
        return NexaApiResponse.fail(NexaApiConstants.errors.internal, 'GetPlayer failed.', result)
    end

    return normalizeExternalResponse(result)
end

function NexaApi.GetCharacter(source)
    source = tonumber(source)

    if not source or source <= 0 then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Source is invalid.')
    end

    if not resourceStarted('nexa-core') then
        return NexaApiResponse.fail(NexaApiConstants.errors.notFound, 'nexa-core is not started.')
    end

    local ok, result = pcall(function()
        return exports['nexa-core']:GetCharacter(source)
    end)

    if not ok then
        return NexaApiResponse.fail(NexaApiConstants.errors.internal, 'GetCharacter failed.', result)
    end

    return normalizeExternalResponse(result)
end

function NexaApi.GetIdentifier(source)
    source = tonumber(source)

    if not source or source <= 0 then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Source is invalid.')
    end

    if not resourceStarted('nexa-core') then
        return NexaApiResponse.fail(NexaApiConstants.errors.notFound, 'nexa-core is not started.')
    end

    local ok, result = pcall(function()
        return exports['nexa-core']:GetIdentifier(source)
    end)

    if not ok then
        return NexaApiResponse.fail(NexaApiConstants.errors.internal, 'GetIdentifier failed.', result)
    end

    return normalizeExternalResponse(result, 'identifier')
end

function GetApi(...)
    normalizeExportArgs(...)
    return NexaApi
end

function RegisterModule(...)
    local name, meta = normalizeExportArgs(...)
    return NexaApi.Registry.RegisterModule(name, meta)
end

function GetModule(...)
    local name = normalizeExportArgs(...)
    return NexaApi.Registry.GetModule(name)
end

function ListModules(...)
    normalizeExportArgs(...)
    return NexaApi.Registry.ListModules()
end

function IsModuleReady(...)
    local name = normalizeExportArgs(...)
    return NexaApi.Registry.IsModuleReady(name)
end

function SetModuleReady(...)
    local name, ready = normalizeExportArgs(...)
    return NexaApi.Registry.SetModuleReady(name, ready)
end

function RegisterContract(...)
    local name, definition = normalizeExportArgs(...)
    return NexaApi.Contracts.RegisterContract(name, definition)
end

function GetContract(...)
    local name = normalizeExportArgs(...)
    return NexaApi.Contracts.GetContract(name)
end

function ListContracts(...)
    normalizeExportArgs(...)
    return NexaApi.Contracts.ListContracts()
end

function ValidateContractPayload(...)
    local name, payload = normalizeExportArgs(...)
    return NexaApi.Contracts.ValidateContractPayload(name, payload)
end

function RegisterServerCallback(...)
    local name, handler, options = normalizeExportArgs(...)
    return NexaApi.Callbacks.RegisterServerCallback(name, handler, options)
end

function TriggerServerCallback(...)
    local name, source, payload = normalizeExportArgs(...)
    return NexaApi.Callbacks.TriggerServerCallback(name, source, payload)
end

function RegisterClientCallback(...)
    local name, targetSource, handlerName, payload, timeoutMs, cb = normalizeExportArgs(...)
    return NexaApi.Callbacks.RegisterClientCallback(name, targetSource, handlerName, payload, timeoutMs, cb)
end

function HasPermission(...)
    local source, permission = normalizeExportArgs(...)
    return NexaApi.HasPermission(source, permission)
end

function RequirePermission(...)
    local source, permission = normalizeExportArgs(...)
    return NexaApi.RequirePermission(source, permission)
end

function GetPlayer(...)
    local source = normalizeExportArgs(...)
    return NexaApi.GetPlayer(source)
end

function GetCharacter(...)
    local source = normalizeExportArgs(...)
    return NexaApi.GetCharacter(source)
end

function GetIdentifier(...)
    local source = normalizeExportArgs(...)
    return NexaApi.GetIdentifier(source)
end
