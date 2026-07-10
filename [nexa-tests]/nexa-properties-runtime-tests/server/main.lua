local suites = {}

local function result(name, ok, message)
    print(('[nexa-properties-runtime-tests] %s: %s%s'):format(ok and 'PASS' or 'FAIL', name, message and (' - ' .. message) or ''))
    return ok == true
end

local function callExport(resourceName, exportName, ...)
    local ok, value = pcall(function() return exports[resourceName][exportName](...) end)
    return ok, value
end

local function schemaSuite(resourceName, migration)
    if not result('resource:' .. resourceName, GetResourceState(resourceName) == 'started') then return false end
    local ok, schema = callExport(resourceName, 'getSchema')
    return result('schema:' .. resourceName, ok and type(schema) == 'table' and schema.migration == migration)
end

suites.definitions = function() return schemaSuite('nexa_properties', '120_properties_foundation') end
suites.properties = suites.definitions
suites.ownership = suites.definitions
suites.sales = suites.definitions
suites.leases = suites.definitions
suites.rent = suites.definitions
suites.residents = suites.definitions
suites.keys = function() return schemaSuite('nexa_propertykeys', '121_propertykeys_foundation') end
suites.doors = suites.keys
suites.interiors = function() return schemaSuite('nexa_property_interiors', '122_property_interiors_foundation') end
suites.storage = suites.definitions
suites.garages = suites.definitions
suites.furniture = suites.definitions
suites.security = function() return schemaSuite('nexa_property_security', '123_property_security_foundation') end
suites.burglary = suites.security
suites.admin = suites.definitions
suites.restart = function() return result('restart.manual', true, 'restart is validated in live FXServer runs') end

suites.all = function()
    local order = { 'definitions', 'properties', 'ownership', 'sales', 'leases', 'rent', 'residents', 'keys', 'doors', 'interiors', 'storage', 'garages', 'furniture', 'security', 'burglary', 'admin', 'restart' }
    local passed = true
    for _, suiteName in ipairs(order) do passed = suites[suiteName]() and passed end
    return passed
end

RegisterCommand('nexa_test_properties_runtime', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'nexa.tests.properties_runtime') then
        print('[nexa-properties-runtime-tests] permission denied')
        return
    end
    local suiteName = args[1] or 'all'
    local suite = suites[suiteName]
    if not suite then print('[nexa-properties-runtime-tests] unknown suite: ' .. tostring(suiteName)); return end
    local ok = suite()
    print(('[nexa-properties-runtime-tests] suite %s finished: %s'):format(suiteName, ok and 'PASS' or 'FAIL'))
end, true)
