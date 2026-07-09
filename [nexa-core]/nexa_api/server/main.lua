local RESOURCE = GetCurrentResourceName()

local function printResult(command, response)
    print(('[%s] %s %s'):format(RESOURCE, command, json.encode(response)))
end

local function commandAllowed(source)
    if source == 0 then
        return true
    end

    if NexaApiConfig.IsDevelopment() then
        return true
    end

    local response = NexaApi.RequirePermission(source, NexaApiConstants.devPermission)
    return response.ok == true
end

local function countResponse(response)
    if not response.ok or type(response.data) ~= 'table' then
        return 0
    end

    return #response.data
end

local function registerCommands()
    RegisterCommand('nexaapi', function(source)
        if not commandAllowed(source) then
            printResult('nexaapi', NexaApiResponse.fail(NexaApiConstants.errors.forbidden, 'Permission denied.'))
            return
        end

        printResult('nexaapi', NexaApiResponse.ok({
            version = NexaApi.Version,
            modules = countResponse(NexaApi.Registry.ListModules()),
            contracts = countResponse(NexaApi.Contracts.ListContracts())
        }))
    end, false)

    RegisterCommand('nexaapimodules', function(source)
        if not commandAllowed(source) then
            printResult('nexaapimodules', NexaApiResponse.fail(NexaApiConstants.errors.forbidden, 'Permission denied.'))
            return
        end

        printResult('nexaapimodules', NexaApi.Registry.ListModules())
    end, false)

    RegisterCommand('nexaapicontracts', function(source)
        if not commandAllowed(source) then
            printResult('nexaapicontracts', NexaApiResponse.fail(NexaApiConstants.errors.forbidden, 'Permission denied.'))
            return
        end

        printResult('nexaapicontracts', NexaApi.Contracts.ListContracts())
    end, false)

    RegisterCommand('nexaapihas', function(source, args)
        if not commandAllowed(source) then
            printResult('nexaapihas', NexaApiResponse.fail(NexaApiConstants.errors.forbidden, 'Permission denied.'))
            return
        end

        printResult('nexaapihas', NexaApi.HasPermission(source, args[1]))
    end, false)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    NexaApi.Registry.RegisterModule('nexa_api', {
        version = NexaApi.Version,
        resource = RESOURCE
    })
    NexaApi.Registry.SetModuleReady('nexa_api', true)

    if NexaApiConfig.commandsEnabled then
        registerCommands()
    end

    print(('[%s] started version %s'):format(RESOURCE, NexaApi.Version))
end)
