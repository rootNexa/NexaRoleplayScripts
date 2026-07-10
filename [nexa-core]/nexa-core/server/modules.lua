Nexa.Modules = Nexa.Modules or {
    registry = {},
    order = {},
    startedOrder = {},
    initialized = false,
    started = false
}

local MODULE_NAME_PATTERN = '^[%w_%-%.:]+$'

local function moduleLog(level, category, message, context)
    if Nexa.Logger and Nexa.Logger[level] then
        Nexa.Logger[level](category, message, context)
        return
    end

    Nexa.Log(level:lower(), message, context)
end

local function copyArray(value)
    local result = {}

    if type(value) ~= 'table' then
        return result
    end

    for _, item in ipairs(value) do
        if type(item) == 'string' and item ~= '' then
            result[#result + 1] = item
        end
    end

    return result
end

local function normalizeDefinition(definition)
    if type(definition) ~= 'table' then
        return nil, 'INVALID_DEFINITION'
    end

    if type(definition.name) ~= 'string' or definition.name == '' or not definition.name:match(MODULE_NAME_PATTERN) then
        return nil, 'INVALID_NAME'
    end

    if type(definition.version) ~= 'string' or definition.version == '' then
        return nil, 'INVALID_VERSION'
    end

    return {
        name = definition.name,
        version = definition.version,
        dependencies = copyArray(definition.dependencies),
        optionalDependencies = copyArray(definition.optionalDependencies),
        critical = definition.critical ~= false and definition.optional ~= true,
        Initialize = definition.Initialize,
        Start = definition.Start,
        Ready = definition.Ready,
        Stop = definition.Stop,
        Health = definition.Health,
        metadata = type(definition.metadata) == 'table' and definition.metadata or {},
        status = 'registered',
        failureReason = nil,
        registeredAt = os.time()
    }, nil
end

local function setStatus(module, status, reason)
    module.status = status
    module.failureReason = reason

    moduleLog(status == 'failed' and 'Error' or 'Debug', 'modules.lifecycle', 'Modulstatus aktualisiert.', {
        module = module.name,
        status = status,
        reason = reason
    })
end

local function dependencyExists(name)
    return Nexa.Modules.registry[name] ~= nil
end

local function buildDependencyGraph()
    local graph = {}

    for name, module in pairs(Nexa.Modules.registry) do
        graph[name] = {}

        for _, dependencyName in ipairs(module.dependencies) do
            if not dependencyExists(dependencyName) then
                local reason = ('MISSING_DEPENDENCY:%s:%s'):format(name, dependencyName)

                if module.critical then
                    return nil, reason
                end

                setStatus(module, 'failed', reason)
                moduleLog('Warn', 'modules.dependencies', 'Nicht kritisches Modul wegen fehlender Abhaengigkeit deaktiviert.', {
                    module = name,
                    dependency = dependencyName
                })
                break
            end

            graph[name][#graph[name] + 1] = dependencyName
        end

        for _, dependencyName in ipairs(module.optionalDependencies) do
            if dependencyExists(dependencyName) then
                graph[name][#graph[name] + 1] = dependencyName
            else
                moduleLog('Info', 'modules.dependencies', 'Optionale Modulabhaengigkeit nicht vorhanden.', {
                    module = name,
                    dependency = dependencyName
                })
            end
        end
    end

    return graph, nil
end

local function topologicalSort()
    local graph, graphErr = buildDependencyGraph()

    if not graph then
        return nil, graphErr
    end

    local sorted = {}
    local visiting = {}
    local visited = {}

    local function visit(name, stack)
        if visiting[name] then
            return false, ('CYCLIC_DEPENDENCY:%s:%s'):format(name, table.concat(stack, ' -> '))
        end

        if visited[name] then
            return true, nil
        end

        visiting[name] = true
        stack[#stack + 1] = name

        for _, dependencyName in ipairs(graph[name] or {}) do
            local ok, err = visit(dependencyName, stack)

            if not ok then
                return false, err
            end
        end

        stack[#stack] = nil
        visiting[name] = nil
        visited[name] = true
        sorted[#sorted + 1] = name
        return true, nil
    end

    for name in pairs(Nexa.Modules.registry) do
        local ok, err = visit(name, {})

        if not ok then
            return nil, err
        end
    end

    return sorted, nil
end

local function callModule(module, phase)
    local handler = module[phase]

    if handler == nil then
        return true, nil
    end

    if type(handler) ~= 'function' then
        return false, ('INVALID_%s_HANDLER'):format(phase:upper())
    end

    local ok, err = pcall(handler, module)

    if not ok then
        return false, tostring(err)
    end

    return true, nil
end

local function failModule(module, phase, err)
    setStatus(module, 'failed', err)
    moduleLog('Error', 'modules.lifecycle', 'Modul-Lifecycle fehlgeschlagen.', {
        module = module.name,
        phase = phase,
        critical = module.critical,
        error = err
    })

    if module.critical then
        return false, ('MODULE_%s_FAILED:%s'):format(phase:upper(), module.name)
    end

    return true, nil
end

local function dependenciesHealthy(module)
    for _, dependencyName in ipairs(module.dependencies) do
        local dependency = Nexa.Modules.registry[dependencyName]

        if not dependency or dependency.status == 'failed' or dependency.status == 'stopped' then
            return false, ('DEPENDENCY_NOT_READY:%s'):format(dependencyName)
        end
    end

    return true, nil
end

local function runPhase(moduleName, phase, nextStatus)
    local module = Nexa.Modules.registry[moduleName]
    local phaseStatuses = {
        Initialize = 'initializing',
        Start = 'starting',
        Ready = 'readying',
        Stop = 'stopping'
    }

    if not module then
        return false, 'MODULE_NOT_FOUND'
    end

    if module.status == 'failed' then
        return true, nil
    end

    if phase ~= 'Initialize' then
        local depsOk, depsErr = dependenciesHealthy(module)

        if not depsOk then
            return failModule(module, phase, depsErr)
        end
    end

    setStatus(module, phaseStatuses[phase] or phase:lower())

    local ok, err = callModule(module, phase)

    if not ok then
        return failModule(module, phase, err)
    end

    setStatus(module, nextStatus)
    return true, nil
end

function Nexa.Modules.Register(definition)
    local module, err = normalizeDefinition(definition)

    if not module then
        moduleLog('Error', 'modules.register', 'Modulregistrierung ungueltig.', {
            error = err
        })
        return false, err
    end

    if Nexa.Modules.registry[module.name] then
        moduleLog('Error', 'modules.register', 'Doppelte Modulregistrierung blockiert.', {
            module = module.name
        })
        return false, 'DUPLICATE_MODULE'
    end

    Nexa.Modules.registry[module.name] = module
    moduleLog('Info', 'modules.register', 'Core-Modul registriert.', {
        module = module.name,
        version = module.version,
        critical = module.critical
    })
    return true, nil
end

function Nexa.Modules.InitializeAll()
    if Nexa.Modules.initialized then
        return false, 'ALREADY_INITIALIZED'
    end

    local sorted, sortErr = topologicalSort()

    if not sorted then
        return false, sortErr
    end

    Nexa.Modules.order = sorted

    for _, moduleName in ipairs(sorted) do
        local ok, err = runPhase(moduleName, 'Initialize', 'initialized')

        if not ok then
            Nexa.Modules.StopAll('initialize_failed')
            return false, err
        end
    end

    Nexa.Modules.initialized = true
    return true, nil
end

function Nexa.Modules.StartAll()
    if Nexa.Modules.started then
        return false, 'ALREADY_STARTED'
    end

    if not Nexa.Modules.initialized then
        local ok, err = Nexa.Modules.InitializeAll()

        if not ok then
            return false, err
        end
    end

    Nexa.Modules.startedOrder = {}

    for _, moduleName in ipairs(Nexa.Modules.order) do
        local ok, err = runPhase(moduleName, 'Start', 'started')

        if not ok then
            Nexa.Modules.StopAll('start_failed')
            return false, err
        end

        if Nexa.Modules.registry[moduleName].status ~= 'failed' then
            Nexa.Modules.startedOrder[#Nexa.Modules.startedOrder + 1] = moduleName
        end
    end

    Nexa.Modules.started = true
    return true, nil
end

function Nexa.Modules.ReadyAll()
    if not Nexa.Modules.started then
        return false, 'NOT_STARTED'
    end

    for _, moduleName in ipairs(Nexa.Modules.order) do
        local ok, err = runPhase(moduleName, 'Ready', 'ready')

        if not ok then
            Nexa.Modules.StopAll('ready_failed')
            return false, err
        end
    end

    return true, nil
end

function Nexa.Modules.StopAll(reason)
    reason = reason or 'stop'

    local stopOrder = #Nexa.Modules.startedOrder > 0 and Nexa.Modules.startedOrder or Nexa.Modules.order

    for index = #stopOrder, 1, -1 do
        local module = Nexa.Modules.registry[stopOrder[index]]

        if module and module.status ~= 'stopped' and module.status ~= 'registered' then
            setStatus(module, 'stopping', reason)

            local ok, err = callModule(module, 'Stop')

            if not ok then
                setStatus(module, 'failed', err)
                moduleLog('Error', 'modules.stop', 'Modul konnte nicht sauber gestoppt werden.', {
                    module = module.name,
                    reason = reason,
                    error = err
                })
            else
                setStatus(module, 'stopped', reason)
            end
        end
    end

    Nexa.Modules.started = false
    Nexa.Modules.initialized = false
    Nexa.Modules.startedOrder = {}
    return true, nil
end

function Nexa.Modules.Get(name)
    return Nexa.Modules.registry[name]
end

function Nexa.Modules.GetStatus(name)
    local module = Nexa.Modules.registry[name]

    if not module then
        return nil
    end

    return {
        name = module.name,
        version = module.version,
        status = module.status,
        critical = module.critical,
        dependencies = copyArray(module.dependencies),
        optionalDependencies = copyArray(module.optionalDependencies),
        ready = module.status == 'ready',
        failureReason = module.failureReason
    }
end

function Nexa.Modules.GetAllStatuses()
    local statuses = {}

    for name in pairs(Nexa.Modules.registry) do
        statuses[#statuses + 1] = Nexa.Modules.GetStatus(name)
    end

    table.sort(statuses, function(left, right)
        return left.name < right.name
    end)

    return statuses
end

function Nexa.Modules.IsReady(name)
    local module = Nexa.Modules.registry[name]
    return module ~= nil and module.status == 'ready'
end

function Nexa.Modules.GetHealth(name)
    local module = Nexa.Modules.registry[name]

    if not module then
        return nil, 'MODULE_NOT_FOUND'
    end

    local health = {
        name = module.name,
        version = module.version,
        status = module.status,
        ready = module.status == 'ready',
        critical = module.critical,
        failureReason = module.failureReason
    }

    if type(module.Health) == 'function' then
        local ok, result = pcall(module.Health, module)

        if ok and type(result) == 'table' then
            for key, value in pairs(result) do
                health[key] = value
            end
        elseif not ok then
            health.status = 'failed'
            health.failureReason = tostring(result)
        end
    end

    return health, nil
end
