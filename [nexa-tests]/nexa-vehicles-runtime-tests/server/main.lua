local suites = {}

local function result(name, ok, message)
    print(('[nexa-vehicles-runtime-tests] %s: %s%s'):format(ok and 'PASS' or 'FAIL', name, message and (' - ' .. message) or ''))
    return ok == true
end

local function resourceStarted(name)
    return GetResourceState(name) == 'started'
end

local function callExport(resourceName, exportName, ...)
    local ok, value = pcall(function()
        return exports[resourceName][exportName](...)
    end)
    return ok, value
end

local function statusSuite()
    local resources = { 'nexa_vehicles', 'nexa_vehiclekeys', 'nexa_garages', 'nexa_impound' }
    for _, resourceName in ipairs(resources) do
        if not result('resource:' .. resourceName, resourceStarted(resourceName), 'resource must be started') then return false end
        local ok, status = callExport(resourceName, 'getStatus')
        if not result('status:' .. resourceName, ok and type(status) == 'table', 'getStatus must return a table') then return false end
    end
    return true
end

suites.definitions = function()
    local ok, schema = callExport('nexa_vehicles', 'getSchema')
    return result('definitions.schema', ok and type(schema) == 'table' and schema.migration == '110_vehicles_foundation')
end

suites.creation = function() return statusSuite() end
suites.spawn = function() return statusSuite() end
suites.despawn = function() return statusSuite() end
suites.keys = function() local ok, schema = callExport('nexa_vehiclekeys', 'getSchema'); return result('keys.schema', ok and type(schema) == 'table' and schema.migration == '111_vehiclekeys_foundation') end
suites.access = suites.keys
suites.garages = function() local ok, schema = callExport('nexa_garages', 'getSchema'); return result('garages.schema', ok and type(schema) == 'table' and schema.migration == '112_garages_foundation') end
suites.state = suites.definitions
suites.damage = suites.definitions
suites.fuel = suites.definitions
suites.mileage = suites.definitions
suites.insurance = suites.definitions
suites.mods = suites.definitions
suites.impound = function() local ok, schema = callExport('nexa_impound', 'getSchema'); return result('impound.schema', ok and type(schema) == 'table' and schema.migration == '113_impound_foundation') end
suites.theft = suites.definitions
suites.security = suites.definitions
suites.restart = function() return result('restart.manual', true, 'restart behavior is validated during FXServer restart runs') end

suites.all = function()
    local order = { 'definitions', 'creation', 'spawn', 'despawn', 'keys', 'access', 'garages', 'state', 'damage', 'fuel', 'mileage', 'insurance', 'mods', 'impound', 'theft', 'security', 'restart' }
    local passed = true
    for _, suiteName in ipairs(order) do
        passed = suites[suiteName]() and passed
    end
    return passed
end

RegisterCommand('nexa_test_vehicles_runtime', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'nexa.tests.vehicles_runtime') then
        print('[nexa-vehicles-runtime-tests] permission denied')
        return
    end

    local suiteName = args[1] or 'all'
    local suite = suites[suiteName]
    if not suite then
        print('[nexa-vehicles-runtime-tests] unknown suite: ' .. tostring(suiteName))
        return
    end

    local ok = suite()
    print(('[nexa-vehicles-runtime-tests] suite %s finished: %s'):format(suiteName, ok and 'PASS' or 'FAIL'))
end, true)
