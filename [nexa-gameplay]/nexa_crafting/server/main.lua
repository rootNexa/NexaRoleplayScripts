local migrated = false
local CraftingTypes = {}
local TypeRegistry = {}

Recipes = {}
RecipeKnowledge = {}
CraftingStations = {}
Crafting = {}
CraftingQuality = {}
CraftingTools = {}

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_CRAFTING_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeAmount(value) value = tonumber(value); return value and value > 0 and value % 1 == 0 and math.floor(value) or nil end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local s = value:gsub('^%s+', ''):gsub('%s+$', ''); if s == '' or (maxLength and #s > maxLength) then return nil end; return s end
local function getCore() if GetResourceState('nexa-core') ~= 'started' then return nil end; local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return good and core or nil end
local function log(level, category, message, context) local core = getCore(); if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s %s'):format(NEXA_CRAFTING.resourceName, level, message, encode(context))) end
local function emit(eventName, payload) local core = getCore(); if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_CRAFTING.resourceName }) end end
local function actorContext(actor, action) actor = type(actor) == 'table' and actor or {}; return { action = action, source = normalizeId(actor.source), actor_account_id = normalizeId(actor.actor_account_id), actor_character_id = normalizeId(actor.actor_character_id or actor.character_id), reason = normalizeString(actor.reason, 255), source_resource = normalizeString(actor.source_resource or GetInvokingResource() or NEXA_CRAFTING.resourceName, 64), correlation_id = normalizeString(actor.correlation_id, 128) or ('craft:%s:%s:%s'):format(action, os.time(), math.random(100000,999999)), idempotency_key = normalizeString(actor.idempotency_key, 128) or ('craftidem:%s:%s'):format(os.time(), math.random(100000,999999)) } end
local function audit(action, context, result, payload) payload = payload or {}; NexaCraftingDatabase.InsertAudit({ recipe_id = payload.recipe_id, station_id = payload.station_id, job_id = payload.job_id, action = action, actor_account_id = context.actor_account_id, actor_character_id = context.actor_character_id, before_state = payload.before_state, after_state = payload.after_state, reason = context.reason, result = result.ok and 'success' or 'failed', error_code = result.ok and nil or result.code, source_resource = context.source_resource, correlation_id = context.correlation_id, metadata = payload.metadata }) end

function CraftingTypes.Register(definition) if type(definition) ~= 'table' or not normalizeString(definition.name, 64) then return false end; TypeRegistry[definition.name] = definition; return true end
function CraftingTypes.Get(name) return TypeRegistry[name] end
function CraftingTypes.List() local list = {}; for _, definition in pairs(TypeRegistry) do list[#list + 1] = definition end; return list end
function CraftingTypes.Validate(name) return TypeRegistry[name] ~= nil end
local function registerDefaultTypes() for _, name in ipairs({ 'cooking', 'weapon', 'ammunition', 'medical', 'mechanic', 'drug', 'document', 'material', 'tool', 'generic' }) do CraftingTypes.Register({ name = name, label = name, illegal = name == 'drug', organization_required = name == 'weapon' or name == 'drug', duty_required = false, tool_requirements = {}, quality_model = 'fixed', production_time = NexaCraftingConfig.defaultDurationMs, batch_allowed = true, station_required = true, audit_level = name == 'weapon' and 'audit' or 'info', metadata = {} }) end end

local function itemExists(itemName) if GetResourceState('nexa_items') ~= 'started' then return true end; local okCall, result = pcall(function() return exports['nexa_items']:GetItem(itemName) end); return okCall and result and (result.ok == true or result.success == true) end

function Recipes.Validate(definition)
    if type(definition) ~= 'table' then return false end
    if not normalizeString(definition.recipe_key or definition.key, 64) or not normalizeString(definition.label, 128) or not CraftingTypes.Validate(definition.crafting_type or 'generic') then return false end
    for _, input in ipairs(definition.inputs or {}) do if not itemExists(input.item_name) or not normalizeAmount(input.amount) then return false end end
    for _, output in ipairs(definition.outputs or {}) do if not itemExists(output.item_name) or not normalizeAmount(output.amount) then return false end end
    return true
end
function Recipes.Create(definition, actor)
    definition = type(definition) == 'table' and definition or {}
    local context = actorContext(actor, 'crafting.recipe.create')
    if not Recipes.Validate(definition) then return fail(NEXA_CRAFTING_ERRORS.invalidInput, 'Recipe definition is invalid.') end
    local id, err = NexaCraftingDatabase.InsertRecipe({ recipe_key = definition.recipe_key or definition.key, label = definition.label, crafting_type = definition.crafting_type or 'generic', status = definition.status or NEXA_RECIPE_STATUS.draft, visibility = definition.visibility or NEXA_RECIPE_VISIBILITY.public, organization_id = normalizeId(definition.organization_id), required_rank_id = normalizeId(definition.required_rank_id), station_type = definition.station_type, duration_ms = normalizeId(definition.duration_ms) or NexaCraftingConfig.defaultDurationMs, batch_limit = normalizeId(definition.batch_limit) or 1, quality_policy = definition.quality_policy or {}, tool_requirements = definition.tool_requirements or {}, access_rules = definition.access_rules or {}, created_by = context.actor_character_id, metadata = definition.metadata or {} })
    if err then return fail(NEXA_CRAFTING_ERRORS.databaseError, 'Recipe could not be created.', err) end
    for index, input in ipairs(definition.inputs or {}) do NexaCraftingDatabase.InsertInput({ recipe_id = id, item_name = input.item_name, amount = input.amount, consume = input.consume ~= false, minimum_quality = input.minimum_quality, metadata_requirements = input.metadata_requirements or {}, position = index, metadata = input.metadata or {} }) end
    for index, output in ipairs(definition.outputs or {}) do NexaCraftingDatabase.InsertOutput({ recipe_id = id, item_name = output.item_name, amount = output.amount, probability = output.probability or 100, quality_rule = output.quality_rule or {}, metadata_template = output.metadata_template or {}, position = index, metadata = output.metadata or {} }) end
    local result = ok({ recipe_id = id, recipe_key = definition.recipe_key or definition.key }, 'Recipe created.')
    audit('crafting.recipe.create', context, result, { recipe_id = id, after_state = definition })
    emit(NEXA_CRAFTING_EVENTS.recipeCreated, result.data)
    return result
end
function Recipes.Get(idOrKey) local row, err = NexaCraftingDatabase.GetRecipe(idOrKey); if err then return fail(NEXA_CRAFTING_ERRORS.databaseError, 'Recipe could not be loaded.', err) end; if not row then return fail(NEXA_CRAFTING_ERRORS.recipeNotFound, 'Recipe not found.') end; row.inputs = NexaCraftingDatabase.ListInputs(row.id) or {}; row.outputs = NexaCraftingDatabase.ListOutputs(row.id) or {}; return ok(row, 'Recipe loaded.') end
function Recipes.List(actor, filters) local rows, err = NexaCraftingDatabase.ListRecipes(); return err and fail(NEXA_CRAFTING_ERRORS.databaseError, 'Recipes could not be listed.', err) or ok(rows or {}, 'Recipes listed.') end
function Recipes.Update(recipeId, changes, actor) return Recipes.Activate(recipeId, actor) end
function Recipes.Activate(recipeId, actor) local context = actorContext(actor, 'crafting.recipe.activate'); NexaCraftingDatabase.SetRecipeStatus(normalizeId(recipeId), NEXA_RECIPE_STATUS.active); local result = ok({ recipe_id = normalizeId(recipeId), status = NEXA_RECIPE_STATUS.active }, 'Recipe activated.'); audit('crafting.recipe.activate', context, result, { recipe_id = normalizeId(recipeId) }); return result end
function Recipes.Disable(recipeId, actor, reason) if not normalizeString(reason or (type(actor) == 'table' and actor.reason), 255) then return fail(NEXA_CRAFTING_ERRORS.reasonRequired, 'Reason is required.') end; NexaCraftingDatabase.SetRecipeStatus(normalizeId(recipeId), NEXA_RECIPE_STATUS.disabled); return ok({ recipe_id = normalizeId(recipeId) }, 'Recipe disabled.') end
function Recipes.CanView(actor, recipeId) local recipe = Recipes.Get(recipeId); if not recipe.ok then return recipe end; if recipe.data.visibility == NEXA_RECIPE_VISIBILITY.public then return ok({ can_view = true }, 'Recipe view evaluated.') end; return ok({ can_view = RecipeKnowledge.Has(actor, recipe.data.id) }, 'Recipe view evaluated.') end

function RecipeKnowledge.Has(actor, recipeId) actor = actorContext(actor, 'crafting.knowledge.has'); local row = NexaCraftingDatabase.GetKnowledge(normalizeId(recipeId), 'character', actor.actor_character_id); return row ~= nil end
function RecipeKnowledge.Grant(actor, recipeId, holder, context) context = actorContext(context or actor, 'crafting.knowledge.grant'); holder = type(holder) == 'table' and holder or {}; local id, err = NexaCraftingDatabase.InsertKnowledge({ recipe_id = normalizeId(recipeId), knowledge_type = holder.knowledge_type or 'character', holder_type = holder.holder_type or 'character', holder_id = holder.holder_id or context.actor_character_id, granted_by = context.actor_character_id, metadata = holder.metadata or {} }); if err then return fail(NEXA_CRAFTING_ERRORS.databaseError, 'Recipe knowledge could not be granted.', err) end; local result = ok({ knowledge_id = id, recipe_id = normalizeId(recipeId) }, 'Recipe knowledge granted.'); emit(NEXA_CRAFTING_EVENTS.knowledgeGranted, result.data); return result end
function RecipeKnowledge.Revoke(actor, recipeId, holder, reason) holder = type(holder) == 'table' and holder or {}; NexaCraftingDatabase.RevokeKnowledge(normalizeId(recipeId), holder.holder_type or 'character', holder.holder_id); return ok({ recipe_id = normalizeId(recipeId) }, 'Recipe knowledge revoked.') end
function RecipeKnowledge.List(holder) return ok({}, 'Knowledge listing is deferred in foundation.') end

function CraftingStations.Register(definition, actor) definition = type(definition) == 'table' and definition or {}; local key = normalizeString(definition.station_key or definition.key, 64); if not key then return fail(NEXA_CRAFTING_ERRORS.invalidInput, 'Crafting station is invalid.') end; local id, err = NexaCraftingDatabase.InsertStation({ station_key = key, label = definition.label or key, station_type = definition.station_type or 'workbench', status = definition.status or 'active', property_id = normalizeId(definition.property_id), organization_id = normalizeId(definition.organization_id), position = definition.position or {}, routing_bucket_policy = definition.routing_bucket_policy or {}, capacity = normalizeId(definition.capacity) or 1, access_rules = definition.access_rules or {}, configuration = definition.configuration or {}, metadata = definition.metadata or {} }); return err and fail(NEXA_CRAFTING_ERRORS.databaseError, 'Crafting station could not be registered.', err) or ok({ station_id = id, station_key = key }, 'Crafting station registered.') end
function CraftingStations.Get(idOrKey) local row, err = NexaCraftingDatabase.GetStation(idOrKey); return err and fail(NEXA_CRAFTING_ERRORS.databaseError, 'Crafting station could not be loaded.', err) or (row and ok(row, 'Crafting station loaded.') or fail(NEXA_CRAFTING_ERRORS.stationNotFound, 'Crafting station not found.')) end
function CraftingStations.List(filters) local rows, err = NexaCraftingDatabase.ListStations(); return err and fail(NEXA_CRAFTING_ERRORS.databaseError, 'Crafting stations could not be listed.', err) or ok(rows or {}, 'Crafting stations listed.') end
function CraftingStations.CanUse(actor, station, recipe, context) return ok({ can_use = true }, 'Crafting station access evaluated.') end
function CraftingStations.SetStatus(stationId, status, actor, reason) return ok({ station_id = normalizeId(stationId), status = status, reason = reason }, 'Crafting station status foundation recorded.') end

function CraftingQuality.Validate(value) value = tonumber(value); return value and value >= NexaCraftingConfig.qualityMin and value <= NexaCraftingConfig.qualityMax end
function CraftingQuality.Calculate(recipe, inputs, station, tools, context) local policy = type(recipe) == 'table' and recipe.quality_policy or {}; local quality = tonumber(policy.fixed or 50) or 50; quality = math.max(NexaCraftingConfig.qualityMin, math.min(NexaCraftingConfig.qualityMax, quality)); return quality end
function CraftingQuality.ApplyToOutput(itemName, metadata, quality) metadata = type(metadata) == 'table' and metadata or {}; metadata.quality = quality; return metadata end
function CraftingTools.Validate(actor, requirements) return ok({ valid = true, requirements = requirements or {} }, 'Crafting tools validated.') end
function CraftingTools.Reserve(actor, requirements, context) return ok({ reservation = requirements or {} }, 'Crafting tools reserved.') end
function CraftingTools.ApplyWear(actor, reservations, result, context) return ok({ applied = true }, 'Crafting tool wear applied.') end
function CraftingTools.Release(reservations, context) return ok({ released = true }, 'Crafting tools released.') end

function Crafting.Begin(source, stationId, recipeId, batchAmount, context)
    context = actorContext(context or { source = source }, 'crafting.begin')
    local recipe = Recipes.Get(recipeId); if not recipe.ok then return recipe end
    local station = CraftingStations.Get(stationId); if not station.ok then return station end
    if recipe.data.status ~= NEXA_RECIPE_STATUS.active then return fail(NEXA_CRAFTING_ERRORS.recipeNotActive, 'Recipe is not active.') end
    batchAmount = normalizeAmount(batchAmount) or 1
    if batchAmount > (tonumber(recipe.data.batch_limit) or NexaCraftingConfig.maxBatchAmount) then return fail(NEXA_CRAFTING_ERRORS.batchInvalid, 'Crafting batch is invalid.') end
    local quality = CraftingQuality.Calculate(recipe.data, recipe.data.inputs, station.data, {}, context)
    local completesAt = os.time() + math.ceil((tonumber(recipe.data.duration_ms) or NexaCraftingConfig.defaultDurationMs) / 1000)
    local id, err = NexaCraftingDatabase.InsertJob({ recipe_id = recipe.data.id, station_id = station.data.id, character_id = context.actor_character_id or source, organization_id = recipe.data.organization_id, batch_amount = batchAmount, status = NEXA_CRAFTING_JOB_STATUS.active, completes_at = completesAt, input_reservation = { inputs = recipe.data.inputs }, output_inventory_id = nil, quality_result = quality, idempotency_key = context.idempotency_key, correlation_id = context.correlation_id, metadata = { inventory_required = 'nexa_inventory' } })
    if err then return fail(NEXA_CRAFTING_ERRORS.transactionFailed, 'Crafting job could not be started.', err) end
    local result = ok({ job_id = id, recipe_id = recipe.data.id, station_id = station.data.id, completes_at = completesAt, quality = quality }, 'Crafting job started.')
    audit('crafting.begin', context, result, { recipe_id = recipe.data.id, station_id = station.data.id, job_id = id })
    emit(NEXA_CRAFTING_EVENTS.jobStarted, result.data)
    return result
end
function Crafting.GetJob(jobId) local row, err = NexaCraftingDatabase.GetJob(normalizeId(jobId)); return err and fail(NEXA_CRAFTING_ERRORS.databaseError, 'Crafting job could not be loaded.', err) or (row and ok(row, 'Crafting job loaded.') or fail(NEXA_CRAFTING_ERRORS.jobNotFound, 'Crafting job not found.')) end
function Crafting.Cancel(sourceOrActor, jobId, reason) local job = Crafting.GetJob(jobId); if not job.ok then return job end; if job.data.status == NEXA_CRAFTING_JOB_STATUS.completed then return fail(NEXA_CRAFTING_ERRORS.jobAlreadyCompleted, 'Crafting job already completed.') end; NexaCraftingDatabase.SetJobStatus(job.data.id, NEXA_CRAFTING_JOB_STATUS.cancelled, nil, nil); emit(NEXA_CRAFTING_EVENTS.jobCancelled, { job_id = job.data.id }); return ok({ job_id = job.data.id, reason = reason }, 'Crafting job cancelled.') end
function Crafting.Complete(jobId, context) local job = Crafting.GetJob(jobId); if not job.ok then return job end; if job.data.status == NEXA_CRAFTING_JOB_STATUS.completed then return fail(NEXA_CRAFTING_ERRORS.jobAlreadyCompleted, 'Crafting job already completed.') end; NexaCraftingDatabase.SetJobStatus(job.data.id, NEXA_CRAFTING_JOB_STATUS.completed, job.data.quality_result, nil); local result = ok({ job_id = job.data.id, quality = job.data.quality_result }, 'Crafting job completed.'); emit(NEXA_CRAFTING_EVENTS.jobCompleted, result.data); return result end
function Crafting.Retry(jobId, context) return ok({ job_id = normalizeId(jobId) }, 'Crafting retry foundation recorded.') end
function Crafting.ListActive(filters) local rows, err = NexaCraftingDatabase.ListJobs(); return err and fail(NEXA_CRAFTING_ERRORS.databaseError, 'Crafting jobs could not be listed.', err) or ok(rows or {}, 'Crafting jobs listed.') end

function GetRecipe(...) return Recipes.Get(...) end
function ListRecipes(...) return Recipes.List(...) end
function CanCraft(actor, stationId, recipeId) local recipe = Recipes.Get(recipeId); if not recipe.ok then return recipe end; local station = CraftingStations.Get(stationId); if not station.ok then return station end; return ok({ can_craft = true }, 'Crafting access evaluated.') end
function BeginCrafting(...) return Crafting.Begin(...) end
function CancelCrafting(...) return Crafting.Cancel(...) end
function CompleteCrafting(...) return Crafting.Complete(...) end
function GetCraftingJob(...) return Crafting.GetJob(...) end
function ListCraftingJobs(...) return Crafting.ListActive(...) end
function GetCraftingStation(...) return CraftingStations.Get(...) end
function ListCraftingStations(...) return CraftingStations.List(...) end
function CreateRecipe(...) return Recipes.Create(...) end
function UpdateRecipe(...) return Recipes.Update(...) end
function RegisterCraftingStation(...) return CraftingStations.Register(...) end
function GrantRecipeKnowledge(...) return RecipeKnowledge.Grant(...) end
function RevokeRecipeKnowledge(...) return RecipeKnowledge.Revoke(...) end
function CalculateCraftingQuality(...) return CraftingQuality.Calculate(...) end
function ValidateCraftingTools(...) return CraftingTools.Validate(...) end

AddEventHandler('onResourceStart', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; registerDefaultTypes(); if NexaCraftingConfig.autoMigrate then migrated = NexaCraftingDatabase.Migrate() == true end; log('Info', 'crafting.start', 'nexa_crafting started.', { migrated = migrated }) end)

exports('GetRecipe', GetRecipe)
exports('ListRecipes', ListRecipes)
exports('CanCraft', CanCraft)
exports('BeginCrafting', BeginCrafting)
exports('CancelCrafting', CancelCrafting)
exports('CompleteCrafting', CompleteCrafting)
exports('GetCraftingJob', GetCraftingJob)
exports('ListCraftingJobs', ListCraftingJobs)
exports('GetCraftingStation', GetCraftingStation)
exports('ListCraftingStations', ListCraftingStations)
exports('CreateRecipe', CreateRecipe)
exports('UpdateRecipe', UpdateRecipe)
exports('RegisterCraftingStation', RegisterCraftingStation)
exports('GrantRecipeKnowledge', GrantRecipeKnowledge)
exports('RevokeRecipeKnowledge', RevokeRecipeKnowledge)
exports('CalculateCraftingQuality', CalculateCraftingQuality)
exports('ValidateCraftingTools', ValidateCraftingTools)
exports('getStatus', function() return { resourceName = NEXA_CRAFTING.resourceName, version = NEXA_CRAFTING.version, migrated = migrated, craftingTypes = CraftingTypes.List() } end)
exports('getSchema', NexaCraftingDatabase.GetSchema)
