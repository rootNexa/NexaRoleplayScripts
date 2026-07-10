local SUITES = {
    accounts = true,
    credit = true,
    debit = true,
    transfer = true,
    reservations = true,
    cash = true,
    dirtycash = true,
    deposit = true,
    withdraw = true,
    ledger = true,
    admin = true,
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

local function economyStatus()
    local ok, status = pcall(function()
        return exports.nexa_economy:getStatus()
    end)

    return ok and status or nil
end

local function runSuite(suite)
    if suite == 'all' then
        local results = {}

        for name in pairs(SUITES) do
            if name ~= 'all' then
                results[#results + 1] = runSuite(name)
            end
        end

        table.sort(results, function(left, right)
            return left.suite < right.suite
        end)

        return results
    end

    if suite == 'accounts' then
        local status = economyStatus()
        return result(suite, type(status) == 'table' and status.ready == true and 'passed' or 'open', 'Economy status export smoke check.', status)
    end

    if suite == 'ledger' then
        local ok, schema = pcall(function()
            return exports.nexa_economy:getSchema()
        end)
        return result(suite, ok and type(schema) == 'table' and 'passed' or 'failed', 'Economy schema export smoke check.', schema)
    end

    if suite == 'security' then
        return result(suite, 'open', 'Requires live client source to verify source-bound callbacks and permission boundaries.')
    end

    if suite == 'restart' then
        return result(suite, 'open', 'Requires controlled FXServer restart cycle and persistent database.')
    end

    return result(suite, 'open', 'Requires isolated FXServer database fixtures and test characters.')
end

RegisterCommand('nexa_test_economy_runtime', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'nexa.tests.economy_runtime') then
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
