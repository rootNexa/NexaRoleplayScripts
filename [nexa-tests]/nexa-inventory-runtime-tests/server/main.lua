local SUITES = {
    create = true,
    addremove = true,
    slots = true,
    transfer = true,
    quickslots = true,
    containers = true,
    drops = true,
    integrity = true,
    security = true,
    restart = true,
    all = true
}

local function result(suite, status, message, data)
    return {
        suite = suite,
        status = status,
        message = message,
        data = data
    }
end

local function runSuite(suite)
    if suite == 'all' then
        local results = {}

        for name in pairs(SUITES) do
            if name ~= 'all' then
                results[#results + 1] = runSuite(name)
            end
        end

        return results
    end

    if suite == 'create' then
        local status = exports.nexa_inventory:getStatus()
        return result(suite, type(status) == 'table' and 'passed' or 'failed', 'Static inventory export smoke check.', status)
    end

    return result(suite, 'open', 'Requires running FXServer, isolated test inventories and cleanup.')
end

RegisterCommand('nexa_test_inventory_runtime', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'nexa.tests.inventory_runtime') then
        print(json.encode(result('auth', 'failed', 'ACE permission missing.')))
        return
    end

    local suite = args[1] or 'all'

    if not SUITES[suite] then
        print(json.encode(result(suite, 'failed', 'Unknown suite.')))
        return
    end

    print(json.encode(runSuite(suite)))
end, true)
