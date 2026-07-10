local SUITES = {
    registry = true,
    metadata = true,
    stacking = true,
    durability = true,
    expiration = true,
    actions = true,
    assets = true,
    studio = true,
    inventory = true,
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

    if suite == 'registry' then
        local status = exports.nexa_items:getStatus()
        return result(suite, type(status) == 'table' and 'passed' or 'failed', 'Static item registry export smoke check.', status)
    end

    return result(suite, 'open', 'Requires running FXServer and isolated test item definitions.')
end

RegisterCommand('nexa_test_items_runtime', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'nexa.tests.items_runtime') then
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
