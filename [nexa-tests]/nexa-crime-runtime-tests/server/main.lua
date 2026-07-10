local suites = {}

local function result(name, ok, message)
    print(('[nexa-crime-runtime-tests] %s: %s%s'):format(ok and 'PASS' or 'FAIL', name, message and (' - ' .. message) or ''))
    return ok == true
end

local function callExport(resourceName, exportName, ...)
    local good, value = pcall(function() return exports[resourceName][exportName](...) end)
    return good, value
end

local function schema(resourceName, migration)
    local good, value = callExport(resourceName, 'getSchema')
    return result(resourceName .. '.schema', good and type(value) == 'table' and value.migration == migration)
end

suites.profiles = function() return schema('nexa_crime', '150_crime_foundation') end
suites.sessions = suites.profiles
suites.challenges = suites.profiles
suites.robberies = function() return schema('nexa_robberies', '151_robberies_foundation') end
suites.loot = suites.robberies
suites.drugs = function() return schema('nexa_drugs', '152_drugs_foundation') end
suites.blackmarket = function() return schema('nexa_blackmarket', '153_blackmarket_foundation') end
suites.moneylaundering = suites.blackmarket
suites.security = function()
    local good, status = callExport('nexa_crime', 'getStatus')
    return result('security', good and type(status) == 'table' and type(status.crimeTypes) == 'table')
end
suites.restart = function() return result('restart.manual', true, 'restart requires live FXServer run') end
suites.all = function()
    local ok = true
    for _, name in ipairs({ 'profiles', 'sessions', 'challenges', 'robberies', 'loot', 'drugs', 'blackmarket', 'moneylaundering', 'security', 'restart' }) do
        ok = suites[name]() and ok
    end
    return ok
end

RegisterCommand('nexa_test_crime_runtime', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'nexa.tests.crime_runtime') then
        print('[nexa-crime-runtime-tests] permission denied')
        return
    end
    local suite = suites[args[1] or 'all']
    if not suite then
        print('[nexa-crime-runtime-tests] unknown suite')
        return
    end
    print(('[nexa-crime-runtime-tests] finished: %s'):format(suite() and 'PASS' or 'FAIL'))
end, true)
