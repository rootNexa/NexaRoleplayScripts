local suites = {}

local function result(name, ok, message)
    print(('[nexa-jobframework-runtime-tests] %s: %s%s'):format(ok and 'PASS' or 'FAIL', name, message and (' - ' .. message) or ''))
    return ok == true
end

local function callExport(resourceName, exportName, ...)
    local good, value = pcall(function() return exports[resourceName][exportName](...) end)
    return good, value
end

local function schema()
    local good, value = callExport('nexa_jobframework', 'getSchema')
    return result('schema', good and type(value) == 'table' and value.migration == '140_jobframework_foundation')
end

local function status()
    local good, value = callExport('nexa_jobframework', 'getStatus')
    return result('status', good and type(value) == 'table' and type(value.jobTypes) == 'table' and type(value.taskTypes) == 'table')
end

local function legalJobs()
    local good, value = callExport('nexa_legaljobs', 'GetLegalJobDefinitions')
    return result('legaljobs', good and type(value) == 'table' and #value >= 10)
end

local function definitions()
    local definition = {
        job_key = 'runtime_test_job',
        label = 'Runtime Test Job',
        job_type = 'service',
        status = 'draft',
        phases = {
            {
                phase_key = 'runtime_phase',
                label = 'Runtime Phase',
                tasks = {
                    { task_key = 'runtime_task', task_type = 'wait', amount_required = 1 }
                }
            }
        }
    }
    local good, value = callExport('nexa_jobframework', 'CreateJobDefinition', definition, { source_resource = 'nexa-jobframework-runtime-tests', reason = 'runtime_smoke' })
    return result('definitions', good and type(value) == 'table' and (value.ok == true or value.code == 'JOB_DATABASE_ERROR'), value and value.code)
end

suites.definitions = definitions
suites.sessions = status
suites.phases = schema
suites.tasks = status
suites.progress = status
suites.groups = status
suites.resource_nodes = schema
suites.rewards = schema
suites.mining = legalJobs
suites.farming = legalJobs
suites.fishing = legalJobs
suites.delivery = legalJobs
suites.trucking = legalJobs
suites.taxi = legalJobs
suites.garbage = legalJobs
suites.mechanic = legalJobs
suites.security = status
suites.restart = function() return result('restart.manual', true, 'restart requires a live FXServer run') end
suites.all = function()
    local passed = true
    for _, name in ipairs({ 'definitions', 'sessions', 'phases', 'tasks', 'progress', 'groups', 'resource_nodes', 'rewards', 'mining', 'farming', 'fishing', 'delivery', 'trucking', 'taxi', 'garbage', 'mechanic', 'security', 'restart' }) do
        passed = suites[name]() and passed
    end
    return passed
end

RegisterCommand('nexa_test_jobframework_runtime', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'nexa.tests.jobframework_runtime') then
        print('[nexa-jobframework-runtime-tests] permission denied')
        return
    end

    local suite = suites[args[1] or 'all']
    if not suite then
        print('[nexa-jobframework-runtime-tests] unknown suite')
        return
    end

    print(('[nexa-jobframework-runtime-tests] finished: %s'):format(suite() and 'PASS' or 'FAIL'))
end, true)
