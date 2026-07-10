local suites = {}
local function result(name, ok, message) print(('[nexa-emergency-runtime-tests] %s: %s%s'):format(ok and 'PASS' or 'FAIL', name, message and (' - ' .. message) or '')); return ok == true end
local function callExport(resourceName, exportName, ...) local good, value = pcall(function() return exports[resourceName][exportName](...) end); return good, value end
local function schema(resourceName, migration) local good, value = callExport(resourceName, 'getSchema'); return result(resourceName .. '.schema', good and type(value) == 'table' and value.migration == migration) end
suites.medical = function() return schema('nexa_medical', '160_medical_foundation') end
suites.ems = function() return schema('nexa_ems', '165_ems_foundation') end
suites.police = function() return schema('nexa_police', '161_police_foundation') end
suites.dispatch = function() return schema('nexa_dispatch', '162_dispatch_foundation') end
suites.licenses = function() return schema('nexa_licenses', '163_licenses_foundation') end
suites.evidence = function() return schema('nexa_evidence', '164_evidence_foundation') end
suites.mdt = function() return schema('nexa_mdt', '166_mdt_domain') end
suites.restart = function() return result('restart.manual', true, 'restart requires live FXServer run') end
suites.all = function() local ok = true; for _, name in ipairs({ 'medical', 'ems', 'police', 'dispatch', 'licenses', 'evidence', 'mdt', 'restart' }) do ok = suites[name]() and ok end; return ok end
RegisterCommand('nexa_test_emergency_runtime', function(source, args) if source ~= 0 and not IsPlayerAceAllowed(source, 'nexa.tests.emergency_runtime') then print('[nexa-emergency-runtime-tests] permission denied'); return end; local suite = suites[args[1] or 'all']; if not suite then print('[nexa-emergency-runtime-tests] unknown suite'); return end; print(('[nexa-emergency-runtime-tests] finished: %s'):format(suite() and 'PASS' or 'FAIL')) end, true)
