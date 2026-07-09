NexaApiRegistry = {
    modules = {}
}

function NexaApiRegistry.RegisterModule(name, meta)
    if not NexaApiValidation.isName(name) then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Module name must be 2-64 characters.')
    end

    if meta ~= nil and type(meta) ~= 'table' then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Module metadata must be a table.')
    end

    NexaApiRegistry.modules[name] = {
        name = name,
        meta = meta or {},
        ready = false,
        registeredAt = os.time()
    }

    return NexaApiResponse.ok(NexaApiRegistry.modules[name])
end

function NexaApiRegistry.GetModule(name)
    if not NexaApiValidation.isName(name) then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Module name must be 2-64 characters.')
    end

    local module = NexaApiRegistry.modules[name]

    if not module then
        return NexaApiResponse.fail(NexaApiConstants.errors.notFound, 'Module is not registered.')
    end

    return NexaApiResponse.ok(module)
end

function NexaApiRegistry.ListModules()
    local list = {}

    for name, module in pairs(NexaApiRegistry.modules) do
        list[#list + 1] = {
            name = name,
            meta = module.meta,
            ready = module.ready,
            registeredAt = module.registeredAt
        }
    end

    table.sort(list, function(left, right)
        return left.name < right.name
    end)

    return NexaApiResponse.ok(list)
end

function NexaApiRegistry.IsModuleReady(name)
    local response = NexaApiRegistry.GetModule(name)

    if not response.ok then
        return response
    end

    return NexaApiResponse.ok(response.data.ready == true)
end

function NexaApiRegistry.SetModuleReady(name, ready)
    if type(ready) ~= 'boolean' then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Module ready state must be boolean.')
    end

    local response = NexaApiRegistry.GetModule(name)

    if not response.ok then
        return response
    end

    response.data.ready = ready
    return NexaApiResponse.ok(response.data)
end
