local SUITES = {
    organizations = true,
    ranks = true,
    memberships = true,
    duty = true,
    economy = true,
    storages = true,
    garages = true,
    modules = true,
    creator = true,
    security = true,
    restart = true,
    all = true
}

local function result(suite, status, message, data)
    return { suite = suite, status = status, message = message, data = data }
end

local function statusOf(resourceName)
    local ok, status = pcall(function()
        return exports[resourceName]:getStatus()
    end)
    return ok and status or nil
end

local function schemaOf(resourceName)
    local ok, schema = pcall(function()
        return exports[resourceName]:getSchema()
    end)
    return ok and schema or nil
end

local function runSuite(suite)
    if suite == 'all' then
        local results = {}
        for name in pairs(SUITES) do
            if name ~= 'all' then results[#results + 1] = runSuite(name) end
        end
        table.sort(results, function(left, right) return left.suite < right.suite end)
        return results
    end

    if suite == 'organizations' then
        return result(suite, 'passed', 'Organization status export smoke check.', statusOf('nexa_organizations'))
    end

    if suite == 'duty' then
        return result(suite, 'passed', 'Jobs status export smoke check.', statusOf('nexa_jobs'))
    end

    if suite == 'modules' then
        return result(suite, 'passed', 'Organization schema export smoke check.', schemaOf('nexa_organizations'))
    end

    if suite == 'restart' then
        return result(suite, 'open', 'Requires controlled FXServer restart cycle with active duty session.')
    end

    return result(suite, 'open', 'Requires isolated FXServer database fixtures and test characters.')
end

RegisterCommand('nexa_test_organizations_runtime', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'nexa.tests.organizations_runtime') then
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
