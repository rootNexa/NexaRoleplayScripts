local migrated = false
local DrugTypeRegistry = {}

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_DRUG_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local s = value:gsub('^%s+', ''):gsub('%s+$', ''); if s == '' or (maxLength and #s > maxLength) then return nil end; return s end
local function getCore() if GetResourceState('nexa-core') ~= 'started' then return nil end; local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return good and core or nil end
local function log(level, category, message, context) local core = getCore(); if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s %s'):format(NEXA_DRUGS.resourceName, level, message, encode(context))) end
local function emit(eventName, payload) local core = getCore(); if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_DRUGS.resourceName }) end end

DrugTypes = {}
function DrugTypes.Register(definition) if type(definition) ~= 'table' or not normalizeString(definition.name, 64) then return false end; DrugTypeRegistry[definition.name] = definition; return true end
function DrugTypes.Get(name) return DrugTypeRegistry[name] end
function DrugTypes.List() local list = {}; for _, value in pairs(DrugTypeRegistry) do list[#list + 1] = value end; return list end
function DrugTypes.Validate(name, definition) return DrugTypeRegistry[name] ~= nil and (definition == nil or type(definition) == 'table') end

local function registerDefaults() for _, name in pairs(NEXA_DRUG_TYPES) do DrugTypes.Register({ name = name, label = name, abstract_only = true, no_real_recipe = true }) end end

function GetDrugDefinition(idOrKey) local row, err = NexaDrugsDatabase.GetDefinition(idOrKey); return err and fail(NEXA_DRUG_ERRORS.databaseError, 'Drug definition could not be loaded.', err) or (row and ok(row, 'Drug definition loaded.') or fail(NEXA_DRUG_ERRORS.definitionNotFound, 'Drug definition not found.')) end
function ListDrugDefinitions() local rows, err = NexaDrugsDatabase.ListDefinitions(); return err and fail(NEXA_DRUG_ERRORS.databaseError, 'Drug definitions could not be listed.', err) or ok(rows or {}, 'Drug definitions listed.') end
function RegisterDrugGrowSite(definition, actor) definition = type(definition) == 'table' and definition or {}; local siteKey = normalizeString(definition.site_key or definition.key, 64); local drugId = normalizeId(definition.drug_definition_id); if not siteKey or not drugId then return fail(NEXA_DRUG_ERRORS.invalidInput, 'Grow site is invalid.') end; local id, err = NexaDrugsDatabase.InsertGrowSite({ site_key = siteKey, drug_definition_id = drugId, status = definition.status or 'active', property_id = normalizeId(definition.property_id), position = definition.position or {}, capacity = normalizeId(definition.capacity) or 1, access_rules = definition.access_rules or {}, metadata = definition.metadata or {} }); return err and fail(NEXA_DRUG_ERRORS.databaseError, 'Grow site could not be registered.', err) or ok({ grow_site_id = id, site_key = siteKey }, 'Grow site registered.') end
function StartDrugGrow(source, growSiteId, payload) payload = type(payload) == 'table' and payload or {}; local site, err = NexaDrugsDatabase.GetGrowSite(growSiteId); if err then return fail(NEXA_DRUG_ERRORS.databaseError, 'Grow site could not be loaded.', err) end; if not site then return fail(NEXA_DRUG_ERRORS.growSiteNotFound, 'Grow site not found.') end; local quality = GetDrugQuality(site.drug_definition_id, payload.inputs or {}, site, payload); local id, insertErr = NexaDrugsDatabase.InsertBatch({ drug_definition_id = site.drug_definition_id, grow_site_id = site.id, character_id = normalizeId(payload.character_id or source), status = 'growing', quality = quality.data.quality, amount = normalizeId(payload.amount) or 1, ready_at = os.time() + NexaDrugsConfig.defaultGrowSeconds, idempotency_key = payload.idempotency_key or ('druggrow:%s:%s'):format(source, os.time()), metadata = { abstract = true } }); if insertErr then return fail(NEXA_DRUG_ERRORS.databaseError, 'Grow batch could not be started.', insertErr) end; emit(NEXA_DRUG_EVENTS.growStarted, { batch_id = id, grow_site_id = site.id }); return ok({ batch_id = id, grow_site_id = site.id, quality = quality.data.quality }, 'Drug grow started.') end
function HarvestDrugGrow(source, batchId, payload) local batch, err = NexaDrugsDatabase.GetBatch(normalizeId(batchId)); if err then return fail(NEXA_DRUG_ERRORS.databaseError, 'Batch could not be loaded.', err) end; if not batch then return fail(NEXA_DRUG_ERRORS.batchNotFound, 'Batch not found.') end; NexaDrugsDatabase.SetBatchStatus(batch.id, 'harvested'); emit(NEXA_DRUG_EVENTS.harvested, { batch_id = batch.id }); return ok({ batch_id = batch.id, quality = batch.quality, amount = batch.amount }, 'Drug grow harvested.') end
function StartDrugProcessing(source, batchId, payload) payload = type(payload) == 'table' and payload or {}; local batch = GetDrugBatch(batchId); if not batch.ok then return batch end; local quality = GetDrugQuality(batch.data.drug_definition_id, payload.inputs or {}, {}, payload); local id, err = NexaDrugsDatabase.InsertProcessingJob({ drug_definition_id = batch.data.drug_definition_id, batch_id = batch.data.id, character_id = normalizeId(payload.character_id or source), status = 'active', completes_at = os.time() + NexaDrugsConfig.defaultProcessingSeconds, quality_result = quality.data.quality, idempotency_key = payload.idempotency_key or ('drugproc:%s:%s'):format(source, os.time()), metadata = { abstract = true, crafting_required = 'nexa_crafting' } }); if err then return fail(NEXA_DRUG_ERRORS.databaseError, 'Drug processing could not be started.', err) end; emit(NEXA_DRUG_EVENTS.processingStarted, { processing_job_id = id, batch_id = batch.data.id }); return ok({ processing_job_id = id, quality = quality.data.quality }, 'Drug processing started.') end
function GetDrugBatch(batchId) local row, err = NexaDrugsDatabase.GetBatch(normalizeId(batchId)); return err and fail(NEXA_DRUG_ERRORS.databaseError, 'Batch could not be loaded.', err) or (row and ok(row, 'Drug batch loaded.') or fail(NEXA_DRUG_ERRORS.batchNotFound, 'Drug batch not found.')) end
function GetDrugProcessingJob(jobId) local row, err = NexaDrugsDatabase.GetProcessingJob(normalizeId(jobId)); return err and fail(NEXA_DRUG_ERRORS.databaseError, 'Processing job could not be loaded.', err) or (row and ok(row, 'Drug processing job loaded.') or fail(NEXA_DRUG_ERRORS.processingNotFound, 'Drug processing job not found.')) end
function GetDrugQuality(definition, inputs, station, context) local seed = tonumber(context and context.seed) or 50; local quality = math.max(NexaDrugsConfig.qualityMin, math.min(NexaDrugsConfig.qualityMax, seed)); return ok({ quality = quality, server_calculated = true, no_real_recipe = true }, 'Drug quality calculated.') end

AddEventHandler('onResourceStart', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; registerDefaults(); if NexaDrugsConfig.autoMigrate then migrated = NexaDrugsDatabase.Migrate() == true end; log('Info', 'drugs.start', 'nexa_drugs started.', { migrated = migrated, abstract_only = true }) end)

exports('GetDrugDefinition', GetDrugDefinition)
exports('ListDrugDefinitions', ListDrugDefinitions)
exports('GetDrugBatch', GetDrugBatch)
exports('RegisterDrugGrowSite', RegisterDrugGrowSite)
exports('StartDrugGrow', StartDrugGrow)
exports('HarvestDrugGrow', HarvestDrugGrow)
exports('StartDrugProcessing', StartDrugProcessing)
exports('GetDrugProcessingJob', GetDrugProcessingJob)
exports('GetDrugQuality', GetDrugQuality)
exports('getStatus', function() return { resourceName = NEXA_DRUGS.resourceName, version = NEXA_DRUGS.version, migrated = migrated, drugTypes = DrugTypes.List(), abstractOnly = true } end)
exports('getSchema', NexaDrugsDatabase.GetSchema)
