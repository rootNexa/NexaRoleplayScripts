local commandsRegistered = false

local function getEnvironment()
    if GetResourceState('nexa_config') == 'started' then
        return exports.nexa_config:getEnvironment()
    end

    return GetConvar('nexa:environment', 'development')
end

local function writeAudit(action, severity, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:writeSecurity({
        severity = severity or 'warning',
        action = action,
        resourceName = NEXA_DEVTOOLS.resourceName,
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function writeLog(level, message, metadata)
    if GetResourceState('nexa_logs') ~= 'started' then
        print(('[%s] %s'):format(NEXA_DEVTOOLS.resourceName, message))
        return
    end

    if level == 'critical' then
        exports.nexa_logs:error(NEXA_DEVTOOLS.resourceName, message, metadata)
        return
    end

    if level == 'warning' then
        exports.nexa_logs:warn(NEXA_DEVTOOLS.resourceName, message, metadata)
        return
    end

    exports.nexa_logs:info(NEXA_DEVTOOLS.resourceName, message, metadata)
end

local function assertEnvironment()
    local environment = getEnvironment()

    if environment == 'production' then
        local metadata = {
            environment = environment,
            blocked = true,
            commandsRegistered = commandsRegistered
        }

        writeAudit('devtools.production.blocked', 'critical', metadata)
        writeLog('critical', 'nexa_devtools wurde in Production hart blockiert.', metadata)
        error('nexa_devtools darf in Production niemals starten.', 0)
    end

    if NexaDevtoolsServer.allowedEnvironments[environment] ~= true then
        local metadata = {
            environment = environment,
            blocked = true,
            commandsRegistered = commandsRegistered
        }

        writeAudit('devtools.environment.blocked', 'critical', metadata)
        writeLog('critical', 'nexa_devtools wurde ausserhalb der Development-Umgebung blockiert.', metadata)
        error(('nexa_devtools ist in Umgebung %s nicht erlaubt.'):format(environment), 0)
    end

    return environment
end

local function commandNameIsSafe(commandName)
    local lowered = commandName:lower()

    for _, fragment in ipairs(NexaDevtoolsServer.forbiddenCommandFragments) do
        if lowered:find(fragment, 1, true) ~= nil then
            return false
        end
    end

    return true
end

local function assertSafeCommands()
    for _, commandName in pairs(NexaDevtoolsServer.commands) do
        if not commandNameIsSafe(commandName) then
            writeAudit('devtools.command.blocked', 'critical', {
                command = commandName
            })
            error(('Unsicherer Devtools-Command blockiert: %s'):format(commandName), 0)
        end
    end
end

local function buildResponse(success, code, message, data, auditId)
    if GetResourceState('nexa_api') == 'started' then
        return exports.nexa_api:buildResponse(success, code, message, data, nil, auditId)
    end

    return {
        success = success,
        code = code,
        message = message,
        data = data,
        auditId = auditId
    }
end

local function emitCommandResult(source, response)
    if source == 0 then
        print(('[%s] %s'):format(NEXA_DEVTOOLS.resourceName, response.message))
    end
end

local function runStatus(source)
    local environment = getEnvironment()
    local auditId = writeAudit('devtools.status.checked', 'info', {
        source = source,
        environment = environment
    })

    writeLog('info', 'Devtools-Status wurde abgefragt.', {
        source = source,
        environment = environment
    })

    local response = buildResponse(true, 'OK', 'Devtools sind in Development aktiv.', {
        environment = environment,
        commandsRegistered = commandsRegistered,
        productionBlocked = environment ~= 'production'
    }, auditId)

    emitCommandResult(source, response)
    return response
end

local function runPing(source)
    local auditId = writeAudit('devtools.ping', 'info', {
        source = source
    })
    local response = buildResponse(true, 'OK', 'Devtools-Ping erfolgreich.', {
        resource = NEXA_DEVTOOLS.resourceName,
        version = NEXA_DEVTOOLS.version
    }, auditId)

    emitCommandResult(source, response)
    return response
end

local function runContracts(source)
    local contracts = {}

    if GetResourceState('nexa_api') == 'started' then
        contracts = exports.nexa_api:listContracts()
    end

    local auditId = writeAudit('devtools.contracts.checked', 'info', {
        source = source,
        contractCount = #contracts
    })
    local response = buildResponse(true, 'OK', 'API-Contracts wurden diagnostisch geladen.', {
        contractCount = #contracts
    }, auditId)

    emitCommandResult(source, response)
    return response
end

local function registerDevCommands()
    if commandsRegistered then
        return
    end

    RegisterCommand(NexaDevtoolsServer.commands.status, function(source)
        runStatus(source)
    end, true)

    RegisterCommand(NexaDevtoolsServer.commands.ping, function(source)
        runPing(source)
    end, true)

    RegisterCommand(NexaDevtoolsServer.commands.contracts, function(source)
        runContracts(source)
    end, true)

    commandsRegistered = true
    writeAudit('devtools.commands.registered', 'info', {
        environment = getEnvironment()
    })
    writeLog('info', 'Dev-only Debug-Kommandos wurden registriert.', {
        commands = NexaDevtoolsServer.commands
    })
end

local environment = assertEnvironment()
assertSafeCommands()
registerDevCommands()

exports('getEnvironment', function()
    return environment
end)

exports('areCommandsRegistered', function()
    return commandsRegistered
end)

exports('runStatus', runStatus)
