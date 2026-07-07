local status = {
    ok = false,
    environment = 'unknown',
    version = NEXA_BOOTSTRAP.version,
    errors = {},
    checkedAt = nil
}

local function addError(message)
    status.errors[#status.errors + 1] = message
end

local function getConvarValue(name, fallback)
    local value = GetConvar(name, fallback)

    if value == nil or value == '' then
        return fallback
    end

    return value
end

local function validateEnvironment()
    local environment = exports.nexa_config:getEnvironment()
    status.environment = environment

    if exports.nexa_config:isProduction() and getConvarValue('nexa:debug', 'false') == 'true' then
        addError('Debug darf in Production nicht aktiv sein.')
    end
end

local function validateRequiredResources()
    for _, resourceName in ipairs(NEXA_BOOTSTRAP.requiredResources) do
        local resourceState = GetResourceState(resourceName)

        if resourceState ~= 'started' then
            addError(('Resource nicht gestartet: %s (%s)'):format(resourceName, resourceState))
        end
    end
end

local function validateProductionRules()
    if status.environment ~= 'production' then
        return
    end

    if GetResourceState('nexa_devtools') ~= 'missing' then
        addError('nexa_devtools darf in Production nicht vorhanden oder gestartet sein.')
    end
end

local function runBootstrap()
    status.errors = {}
    status.checkedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')

    validateEnvironment()
    validateRequiredResources()
    validateProductionRules()

    status.ok = #status.errors == 0

    if status.ok then
        exports.nexa_logs:info(NEXA_BOOTSTRAP.resourceName, 'Startvalidierung erfolgreich.', {
            environment = status.environment
        })
        return
    end

    for _, message in ipairs(status.errors) do
        exports.nexa_logs:error(NEXA_BOOTSTRAP.resourceName, message, {
            environment = status.environment
        })
    end

    error('Nexa Bootstrap hat die Startvalidierung abgebrochen.', 0)
end

function getStatus()
    return status
end

CreateThread(function()
    Wait(NexaBootstrapConfig.validationDelayMs)
    runBootstrap()
end)
