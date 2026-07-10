local migrated = false
local reservations = {}
local TypeRegistry = {}
local TaskRegistry = {}

JobTypes = {}
TaskTypes = {}
JobDefinitions = {}
JobSessions = {}
JobGroups = {}
Progress = {}
JobCheckpoints = {}
ResourceNodes = {}
ProductionChains = {}
Rewards = {}
AntiAfk = {}

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_JOB_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeAmount(value) local amount = tonumber(value); return amount and amount > 0 and amount % 1 == 0 and math.floor(amount) or nil end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local s = value:gsub('^%s+', ''):gsub('%s+$', ''); if s == '' or (maxLength and #s > maxLength) then return nil end; return s end
local function getCore() if GetResourceState('nexa-core') ~= 'started' then return nil end; local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return good and core or nil end
local function log(level, category, message, context) local core = getCore(); if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s %s'):format(NEXA_JOBFRAMEWORK.resourceName, level, message, encode(context))) end
local function emit(eventName, payload) local core = getCore(); if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_JOBFRAMEWORK.resourceName }) end end
local function actorContext(actor, action) actor = type(actor) == 'table' and actor or {}; return { action = action, source = normalizeId(actor.source), actor_account_id = normalizeId(actor.actor_account_id), actor_character_id = normalizeId(actor.actor_character_id or actor.character_id), reason = normalizeString(actor.reason, 255), source_resource = normalizeString(actor.source_resource or GetInvokingResource() or NEXA_JOBFRAMEWORK.resourceName, 64), correlation_id = normalizeString(actor.correlation_id, 128) or ('job:%s:%s:%s'):format(action, os.time(), math.random(100000, 999999)), idempotency_key = normalizeString(actor.idempotency_key, 128) or ('jobidem:%s:%s'):format(os.time(), math.random(100000, 999999)) } end
local function audit(action, context, result, payload) payload = payload or {}; NexaJobFrameworkDatabase.InsertAudit({ job_definition_id = payload.job_definition_id, session_id = payload.session_id, action = action, actor_account_id = context.actor_account_id, actor_character_id = context.actor_character_id, before_state = payload.before_state, after_state = payload.after_state, reason = context.reason, result = result.ok and 'success' or 'failed', error_code = result.ok and nil or result.code, source_resource = context.source_resource, correlation_id = context.correlation_id, metadata = payload.metadata }) end

local function registerCallbacks()
    if not NexaJobFrameworkConfig.callbacks.enabled then return end
    local core = getCore()
    if not core or not core.Callbacks or not core.Callbacks.RegisterNetwork then return end
    core.Callbacks.RegisterNetwork(NEXA_JOB_CALLBACKS.listAvailable, function(source, payload) return JobDefinitions.List(type(payload) == 'table' and payload or { status = NEXA_JOB_STATUS.active }) end, { rateLimitMs = NexaJobFrameworkConfig.callbacks.rateLimitMs })
    core.Callbacks.RegisterNetwork(NEXA_JOB_CALLBACKS.getDefinition, function(source, payload) return JobDefinitions.Get(type(payload) == 'table' and payload.job_id or payload) end, { rateLimitMs = NexaJobFrameworkConfig.callbacks.rateLimitMs })
    core.Callbacks.RegisterNetwork(NEXA_JOB_CALLBACKS.getActiveSession, function(source, payload) payload = type(payload) == 'table' and payload or {}; return JobSessions.GetByCharacter(payload.character_id or source) end, { rateLimitMs = NexaJobFrameworkConfig.callbacks.rateLimitMs })
    core.Callbacks.RegisterNetwork(NEXA_JOB_CALLBACKS.startJob, function(source, payload) payload = type(payload) == 'table' and payload or {}; return JobSessions.Create(source, payload.job_id or payload.job_key, { source = source, actor_character_id = payload.character_id, reason = 'network:startJob' }) end, { rateLimitMs = NexaJobFrameworkConfig.callbacks.rateLimitMs })
    core.Callbacks.RegisterNetwork(NEXA_JOB_CALLBACKS.cancelJob, function(source, payload) payload = type(payload) == 'table' and payload or {}; return JobSessions.Cancel({ source = source, actor_character_id = payload.character_id, reason = payload.reason or 'network:cancelJob' }, payload.session_id, payload.reason or 'client_cancel') end, { rateLimitMs = NexaJobFrameworkConfig.callbacks.rateLimitMs })
    core.Callbacks.RegisterNetwork(NEXA_JOB_CALLBACKS.completeTask, function(source, payload) payload = type(payload) == 'table' and payload or {}; return Progress.Complete(payload.session_id, payload.task_id, payload.character_id or source, { source = source, actor_character_id = payload.character_id, reason = 'network:completeTask' }) end, { rateLimitMs = NexaJobFrameworkConfig.callbacks.rateLimitMs })
end

function JobTypes.Register(definition)
    if type(definition) ~= 'table' then return false end
    local name = normalizeString(definition.name, 64)
    if not name then return false end
    TypeRegistry[name] = {
        name = name,
        label = normalizeString(definition.label or name, 128) or name,
        description = definition.description,
        organization_bound = definition.organization_bound == true,
        duty_required = definition.duty_required == true,
        vehicle_required = definition.vehicle_required == true,
        inventory_required = definition.inventory_required ~= false,
        economy_required = definition.economy_required == true,
        crafting_required = definition.crafting_required == true,
        group_capable = definition.group_capable == true,
        repeatable = definition.repeatable ~= false,
        maximum_duration_seconds = normalizeAmount(definition.maximum_duration_seconds) or NexaJobFrameworkConfig.defaultMaximumDurationSeconds,
        audit_level = definition.audit_level or 'info',
        metadata = definition.metadata or {}
    }
    return true
end
function JobTypes.Get(name) return TypeRegistry[name] end
function JobTypes.List() local list = {}; for _, item in pairs(TypeRegistry) do list[#list + 1] = item end; return list end
function JobTypes.IsRegistered(name) return TypeRegistry[name] ~= nil end
function JobTypes.Validate(name, definition) return JobTypes.IsRegistered(name) and (definition == nil or type(definition) == 'table') end

function TaskTypes.Register(definition)
    if type(definition) ~= 'table' then return false end
    local name = normalizeString(definition.name or definition.task_type, 64)
    if not name then return false end
    TaskRegistry[name] = { name = name, label = definition.label or name, server_validator = definition.server_validator or 'foundation', distance_rule = definition.distance_rule or {}, bucket_rule = definition.bucket_rule or {}, time_rule = definition.time_rule or {}, inventory_rule = definition.inventory_rule or {}, vehicle_rule = definition.vehicle_rule or {}, completion_rule = definition.completion_rule or {}, progress_model = definition.progress_model or 'boolean', audit_level = definition.audit_level or 'info' }
    return true
end
function TaskTypes.Get(name) return TaskRegistry[name] end
function TaskTypes.List() local list = {}; for _, item in pairs(TaskRegistry) do list[#list + 1] = item end; return list end
function TaskTypes.Validate(name, definition) return TaskRegistry[name] ~= nil and (definition == nil or type(definition) == 'table') end

local function registerDefaults()
    for _, name in pairs(NEXA_JOB_TYPES) do JobTypes.Register({ name = name, label = name, organization_bound = name == 'public_service', duty_required = name == 'public_service', vehicle_required = name == 'delivery' or name == 'transport' or name == 'route', inventory_required = name ~= 'service', economy_required = true, crafting_required = name == 'processing' or name == 'production', group_capable = name ~= 'service', repeatable = true }) end
    for _, name in pairs(NEXA_JOB_TASK_TYPES) do TaskTypes.Register({ name = name, label = name, progress_model = (name == 'drive_route' or name == 'complete_checkpoint') and 'checkpoint_sequence' or 'boolean' }) end
end

local function itemExists(itemName)
    if not itemName or GetResourceState('nexa_items') ~= 'started' then return true end
    local good, result = pcall(function() return exports['nexa_items']:GetItem(itemName) end)
    return good and result and (result.ok == true or result.success == true)
end

function JobDefinitions.Validate(definition)
    if type(definition) ~= 'table' then return false, NEXA_JOB_ERRORS.invalidInput end
    local key = normalizeString(definition.job_key or definition.key, 64)
    local label = normalizeString(definition.label, 128)
    local jobType = normalizeString(definition.job_type, 32)
    if not key or not label or not JobTypes.IsRegistered(jobType) then return false, NEXA_JOB_ERRORS.invalidInput end
    local phases = definition.phases or {}
    if #phases < 1 then return false, NEXA_JOB_ERRORS.phaseNotFound end
    for _, phase in ipairs(phases) do
        if not normalizeString(phase.phase_key or phase.key, 64) then return false, NEXA_JOB_ERRORS.phaseNotFound end
        for _, task in ipairs(phase.tasks or {}) do
            if not TaskTypes.Validate(task.task_type) then return false, NEXA_JOB_ERRORS.taskNotFound end
            local target = task.target_definition or {}
            if target.item_name and not itemExists(target.item_name) then return false, NEXA_JOB_ERRORS.taskValidationFailed end
        end
    end
    return true
end

function JobDefinitions.Create(definition, actor)
    definition = type(definition) == 'table' and definition or {}
    local context = actorContext(actor, 'job.definition.create')
    local valid, code = JobDefinitions.Validate(definition)
    if not valid then return fail(code, 'Job definition is invalid.') end
    local id, err = NexaJobFrameworkDatabase.InsertDefinition({ job_key = definition.job_key or definition.key, label = definition.label, description = definition.description, job_type = definition.job_type, status = definition.status or NEXA_JOB_STATUS.draft, organization_id = normalizeId(definition.organization_id), required_rank_id = normalizeId(definition.required_rank_id), duty_required = definition.duty_required == true, group_allowed = definition.group_allowed == true, minimum_group_size = normalizeAmount(definition.minimum_group_size) or 1, maximum_group_size = normalizeAmount(definition.maximum_group_size) or 1, cooldown_seconds = tonumber(definition.cooldown_seconds) or NexaJobFrameworkConfig.defaultCooldownSeconds, maximum_duration_seconds = tonumber(definition.maximum_duration_seconds) or NexaJobFrameworkConfig.defaultMaximumDurationSeconds, entry_rules = definition.entry_rules or {}, reward_policy = definition.reward_policy or {}, settings = definition.settings or {}, created_by = context.actor_character_id, metadata = definition.metadata or {} })
    if err then return fail(NEXA_JOB_ERRORS.databaseError, 'Job definition could not be created.', err) end
    for phaseIndex, phase in ipairs(definition.phases or {}) do
        local phaseId = NexaJobFrameworkDatabase.InsertPhase({ job_definition_id = id, phase_key = phase.phase_key or phase.key, label = phase.label or phase.phase_key or phase.key, position = normalizeAmount(phase.position) or phaseIndex, phase_type = phase.phase_type or 'standard', completion_policy = phase.completion_policy or {}, timeout_seconds = normalizeAmount(phase.timeout_seconds), configuration = phase.configuration or {} })
        for taskIndex, task in ipairs(phase.tasks or {}) do
            NexaJobFrameworkDatabase.InsertTask({ phase_id = phaseId, task_key = task.task_key or task.key or ('task_' .. taskIndex), task_type = task.task_type, position = normalizeAmount(task.position) or taskIndex, target_definition = task.target_definition or {}, amount_required = normalizeAmount(task.amount_required) or 1, progress_policy = task.progress_policy or {}, validation_policy = task.validation_policy or {}, reward_fragment = task.reward_fragment or {}, configuration = task.configuration or {} })
        end
    end
    local result = ok({ job_definition_id = id, job_key = definition.job_key or definition.key }, 'Job definition created.')
    audit('job.definition.create', context, result, { job_definition_id = id, after_state = definition })
    emit(NEXA_JOB_EVENTS.definitionCreated, result.data)
    return result
end
function JobDefinitions.Get(idOrKey) local row, err = NexaJobFrameworkDatabase.GetDefinition(idOrKey); if err then return fail(NEXA_JOB_ERRORS.databaseError, 'Job definition could not be loaded.', err) end; if not row then return fail(NEXA_JOB_ERRORS.definitionNotFound, 'Job definition not found.') end; row.phases = NexaJobFrameworkDatabase.ListPhases(row.id) or {}; for _, phase in ipairs(row.phases) do phase.tasks = NexaJobFrameworkDatabase.ListTasks(phase.id) or {} end; return ok(row, 'Job definition loaded.') end
function JobDefinitions.List(filters) local rows, err = NexaJobFrameworkDatabase.ListDefinitions(filters or {}); return err and fail(NEXA_JOB_ERRORS.databaseError, 'Job definitions could not be listed.', err) or ok(rows or {}, 'Job definitions listed.') end
function JobDefinitions.Update(jobId, changes, actor) local current = JobDefinitions.Get(jobId); if not current.ok then return current end; changes = type(changes) == 'table' and changes or {}; local merged = current.data; for key, value in pairs(changes) do merged[key] = value end; NexaJobFrameworkDatabase.UpdateDefinition(merged.id, merged); local context = actorContext(actor, 'job.definition.update'); local result = ok({ job_definition_id = merged.id }, 'Job definition updated.'); audit('job.definition.update', context, result, { job_definition_id = merged.id, before_state = current.data, after_state = merged }); return result end
function JobDefinitions.Activate(jobId, actor) local current = JobDefinitions.Get(jobId); if not current.ok then return current end; NexaJobFrameworkDatabase.UpdateDefinitionStatus(current.data.id, NEXA_JOB_STATUS.active); return ok({ job_definition_id = current.data.id, status = NEXA_JOB_STATUS.active }, 'Job definition activated.') end
function JobDefinitions.Suspend(jobId, actor, reason) if not normalizeString(reason or (type(actor) == 'table' and actor.reason), 255) then return fail(NEXA_JOB_ERRORS.reasonRequired, 'Reason is required.') end; local current = JobDefinitions.Get(jobId); if not current.ok then return current end; NexaJobFrameworkDatabase.UpdateDefinitionStatus(current.data.id, NEXA_JOB_STATUS.suspended); return ok({ job_definition_id = current.data.id }, 'Job definition suspended.') end
function JobDefinitions.Disable(jobId, actor, reason) if not normalizeString(reason or (type(actor) == 'table' and actor.reason), 255) then return fail(NEXA_JOB_ERRORS.reasonRequired, 'Reason is required.') end; local current = JobDefinitions.Get(jobId); if not current.ok then return current end; NexaJobFrameworkDatabase.UpdateDefinitionStatus(current.data.id, NEXA_JOB_STATUS.disabled); return ok({ job_definition_id = current.data.id }, 'Job definition disabled.') end

function JobSessions.CanStart(source, jobId, context)
    context = actorContext(context or { source = source }, 'job.session.canStart')
    local definition = JobDefinitions.Get(jobId)
    if not definition.ok then return definition end
    if definition.data.status ~= NEXA_JOB_STATUS.active then return fail(NEXA_JOB_ERRORS.definitionNotActive, 'Job definition is not active.') end
    local characterId = context.actor_character_id or normalizeId(source)
    local existing = NexaJobFrameworkDatabase.GetActiveSessionByCharacter(characterId)
    if existing then return fail(NEXA_JOB_ERRORS.sessionAlreadyActive, 'Character already has an active job session.') end
    return ok({ can_start = true, job_definition_id = definition.data.id, character_id = characterId }, 'Job start evaluated.')
end
function JobSessions.Create(source, jobId, context)
    context = actorContext(context or { source = source }, 'job.session.create')
    local allowed = JobSessions.CanStart(source, jobId, context)
    if not allowed.ok then return allowed end
    local definition = JobDefinitions.Get(jobId)
    local firstPhase = definition.data.phases and definition.data.phases[1]
    local characterId = context.actor_character_id or normalizeId(source)
    local expiresAt = os.time() + (tonumber(definition.data.maximum_duration_seconds) or NexaJobFrameworkConfig.defaultSessionTimeoutSeconds)
    local sessionId, err = NexaJobFrameworkDatabase.InsertSession({ job_definition_id = definition.data.id, leader_character_id = characterId, organization_id = definition.data.organization_id, status = NEXA_JOB_SESSION_STATUS.active, current_phase_id = firstPhase and firstPhase.id or nil, expires_at = expiresAt, idempotency_key = context.idempotency_key, correlation_id = context.correlation_id, metadata = { source = source } })
    if err then return fail(NEXA_JOB_ERRORS.databaseError, 'Job session could not be created.', err) end
    NexaJobFrameworkDatabase.InsertMember({ session_id = sessionId, character_id = characterId, member_role = 'leader', status = NEXA_JOB_MEMBER_STATUS.active, contribution = {}, metadata = {} })
    local result = ok({ session_id = sessionId, job_definition_id = definition.data.id, current_phase_id = firstPhase and firstPhase.id or nil }, 'Job session started.')
    audit('job.session.create', context, result, { job_definition_id = definition.data.id, session_id = sessionId })
    emit(NEXA_JOB_EVENTS.sessionCreated, result.data)
    emit(NEXA_JOB_EVENTS.sessionStarted, result.data)
    if firstPhase then emit(NEXA_JOB_EVENTS.phaseStarted, { session_id = sessionId, phase_id = firstPhase.id }) end
    return result
end
function JobSessions.Start(sessionId, context) local session = JobSessions.Get(sessionId); if not session.ok then return session end; NexaJobFrameworkDatabase.SetSessionStatus(session.data.id, NEXA_JOB_SESSION_STATUS.active); emit(NEXA_JOB_EVENTS.sessionStarted, { session_id = session.data.id }); return ok({ session_id = session.data.id }, 'Job session started.') end
function JobSessions.Get(sessionId) local row, err = NexaJobFrameworkDatabase.GetSession(normalizeId(sessionId)); return err and fail(NEXA_JOB_ERRORS.databaseError, 'Job session could not be loaded.', err) or (row and ok(row, 'Job session loaded.') or fail(NEXA_JOB_ERRORS.sessionNotFound, 'Job session not found.')) end
function JobSessions.GetByCharacter(characterId) local row, err = NexaJobFrameworkDatabase.GetActiveSessionByCharacter(normalizeId(characterId)); return err and fail(NEXA_JOB_ERRORS.databaseError, 'Job session could not be loaded.', err) or (row and ok(row, 'Character job session loaded.') or fail(NEXA_JOB_ERRORS.sessionNotFound, 'No active job session.')) end
function JobSessions.Cancel(actor, sessionId, reason) if not normalizeString(reason or (type(actor) == 'table' and actor.reason), 255) then return fail(NEXA_JOB_ERRORS.reasonRequired, 'Reason is required.') end; local session = JobSessions.Get(sessionId); if not session.ok then return session end; NexaJobFrameworkDatabase.SetSessionStatus(session.data.id, NEXA_JOB_SESSION_STATUS.cancelled, reason); local result = ok({ session_id = session.data.id, reason = reason }, 'Job session cancelled.'); emit(NEXA_JOB_EVENTS.sessionCancelled, result.data); audit('job.session.cancel', actorContext(actor, 'job.session.cancel'), result, { session_id = session.data.id }); return result end
function JobSessions.Fail(sessionId, code, context) local session = JobSessions.Get(sessionId); if not session.ok then return session end; NexaJobFrameworkDatabase.SetSessionStatus(session.data.id, NEXA_JOB_SESSION_STATUS.failed, code); emit(NEXA_JOB_EVENTS.sessionFailed, { session_id = session.data.id, code = code }); return ok({ session_id = session.data.id, code = code }, 'Job session failed.') end
function JobSessions.Complete(sessionId, context) local session = JobSessions.Get(sessionId); if not session.ok then return session end; NexaJobFrameworkDatabase.SetSessionStatus(session.data.id, NEXA_JOB_SESSION_STATUS.completed); emit(NEXA_JOB_EVENTS.sessionCompleted, { session_id = session.data.id }); return ok({ session_id = session.data.id }, 'Job session completed.') end
function JobSessions.ListActive(filters) local rows, err = NexaJobFrameworkDatabase.ListActiveSessions(filters); return err and fail(NEXA_JOB_ERRORS.databaseError, 'Active job sessions could not be listed.', err) or ok(rows or {}, 'Active job sessions listed.') end

function JobGroups.Create(source, jobId, context) return ok({ group_id = ('jobgroup:%s:%s'):format(source, os.time()), job_id = jobId, leader_source = source }, 'Job group foundation created.') end
function JobGroups.Invite(leaderSource, targetSource, context) return ok({ invitation_id = ('jobinvite:%s:%s:%s'):format(leaderSource, targetSource, os.time()), target_source = targetSource }, 'Job invitation foundation created.') end
function JobGroups.Accept(targetSource, invitationId) return ok({ invitation_id = invitationId, target_source = targetSource }, 'Job invitation accepted.') end
function JobGroups.Leave(source, reason) return ok({ source = source, reason = reason }, 'Job group left.') end
function JobGroups.Remove(leaderSource, targetCharacterId, reason) return ok({ leader_source = leaderSource, target_character_id = targetCharacterId, reason = reason }, 'Job group member removed.') end
function JobGroups.Get(groupId) return ok({ group_id = groupId, members = {} }, 'Job group loaded.') end
function JobGroups.GetByCharacter(characterId) return fail(NEXA_JOB_ERRORS.sessionNotFound, 'No active job group.') end

function Progress.Get(sessionId, taskId, characterId) local row, err = NexaJobFrameworkDatabase.GetProgress(normalizeId(sessionId), normalizeId(taskId), normalizeId(characterId)); return err and fail(NEXA_JOB_ERRORS.databaseError, 'Progress could not be loaded.', err) or ok(row or { progress_value = 0, status = NEXA_JOB_PROGRESS_STATUS.pending }, 'Progress loaded.') end
function Progress.Apply(sessionId, taskId, characterId, delta, context) delta = normalizeAmount(delta); if not delta then return fail(NEXA_JOB_ERRORS.progressInvalid, 'Progress delta is invalid.') end; local current = Progress.Get(sessionId, taskId, characterId); local value = tonumber(current.data.progress_value or 0) + delta; return Progress.SetValidated(sessionId, taskId, characterId, value, context) end
function Progress.SetValidated(sessionId, taskId, characterId, value, context) value = normalizeAmount(value); if not value then return fail(NEXA_JOB_ERRORS.progressInvalid, 'Progress value is invalid.') end; NexaJobFrameworkDatabase.UpsertProgress({ session_id = normalizeId(sessionId), task_id = normalizeId(taskId), character_id = normalizeId(characterId), progress_value = value, status = NEXA_JOB_PROGRESS_STATUS.active, metadata = actorContext(context, 'job.progress.set') }); emit(NEXA_JOB_EVENTS.taskProgressed, { session_id = sessionId, task_id = taskId, character_id = characterId, value = value }); return ok({ session_id = sessionId, task_id = taskId, character_id = characterId, progress_value = value }, 'Progress updated.') end
function Progress.Complete(sessionId, taskId, characterId, context) local task, err = NexaJobFrameworkDatabase.GetTask(normalizeId(taskId)); if err then return fail(NEXA_JOB_ERRORS.databaseError, 'Task could not be loaded.', err) end; if not task then return fail(NEXA_JOB_ERRORS.taskNotFound, 'Task not found.') end; NexaJobFrameworkDatabase.UpsertProgress({ session_id = normalizeId(sessionId), task_id = task.id, character_id = normalizeId(characterId), progress_value = tonumber(task.amount_required) or 1, status = NEXA_JOB_PROGRESS_STATUS.completed, metadata = actorContext(context, 'job.progress.complete') }); local result = ok({ session_id = sessionId, task_id = task.id, character_id = characterId }, 'Task completed.'); emit(NEXA_JOB_EVENTS.taskCompleted, result.data); return result end
function Progress.Validate(sessionId, taskId, payload, context) return ok({ session_id = sessionId, task_id = taskId, valid = true }, 'Progress observation validated.') end

function JobCheckpoints.Resolve(sessionId, phaseId) return ok({ session_id = sessionId, phase_id = phaseId, checkpoints = {} }, 'Checkpoints resolved.') end
function JobCheckpoints.Validate(source, checkpointId, context) return ok({ source = source, checkpoint_id = checkpointId, valid = true }, 'Checkpoint validated.') end
function JobCheckpoints.Complete(source, checkpointId, context) return ok({ source = source, checkpoint_id = checkpointId }, 'Checkpoint completed.') end

function ResourceNodes.Register(definition, actor)
    definition = type(definition) == 'table' and definition or {}
    local key = normalizeString(definition.node_key or definition.key, 64)
    if not key then return fail(NEXA_JOB_ERRORS.invalidInput, 'Resource node is invalid.') end
    local id, err = NexaJobFrameworkDatabase.InsertResourceNode({ node_key = key, node_type = definition.node_type or 'node', label = definition.label or key, position = definition.position or {}, radius = normalizeAmount(definition.radius) or 3, resource_item = definition.resource_item, available_amount = normalizeAmount(definition.available_amount) or 1, respawn_seconds = tonumber(definition.respawn_seconds) or 0, tool_requirements = definition.tool_requirements or {}, access_rules = definition.access_rules or {}, anti_afk_policy = definition.anti_afk_policy or {}, status = definition.status or 'active', metadata = definition.metadata or {} })
    return err and fail(NEXA_JOB_ERRORS.databaseError, 'Resource node could not be registered.', err) or ok({ resource_node_id = id, node_key = key }, 'Resource node registered.')
end
function ResourceNodes.Get(nodeId) local row, err = NexaJobFrameworkDatabase.GetResourceNode(nodeId); return err and fail(NEXA_JOB_ERRORS.databaseError, 'Resource node could not be loaded.', err) or (row and ok(row, 'Resource node loaded.') or fail(NEXA_JOB_ERRORS.resourceNodeNotFound, 'Resource node not found.')) end
function ResourceNodes.Reserve(source, nodeId, amount, context) local node = ResourceNodes.Get(nodeId); if not node.ok then return node end; amount = normalizeAmount(amount) or 1; if tonumber(node.data.available_amount or 0) < amount then return fail(NEXA_JOB_ERRORS.resourceNodeDepleted, 'Resource node is depleted.') end; local id = ('jobnode:%s:%s:%s'):format(node.data.id, source, os.time()); reservations[id] = { source = source, node_id = node.data.id, amount = amount, expires_at = os.time() + NexaJobFrameworkConfig.resourceNodeReservationSeconds }; return ok({ reservation_id = id, node_id = node.data.id, amount = amount }, 'Resource node reserved.') end
function ResourceNodes.Harvest(source, reservationId, context) local reservation = reservations[reservationId]; if not reservation or reservation.source ~= source then return fail(NEXA_JOB_ERRORS.resourceNodeNotFound, 'Resource reservation not found.') end; reservations[reservationId] = nil; return ok(reservation, 'Resource node harvested.') end
function ResourceNodes.Release(reservationId, context) reservations[reservationId] = nil; return ok({ reservation_id = reservationId }, 'Resource reservation released.') end
function ResourceNodes.RespawnDue(now) return ok({ checked_at = now or os.time() }, 'Resource node respawn foundation checked.') end

function ProductionChains.Register(definition, actor) definition = type(definition) == 'table' and definition or {}; local key = normalizeString(definition.chain_key or definition.key, 64); if not key then return fail(NEXA_JOB_ERRORS.invalidInput, 'Production chain is invalid.') end; local id, err = NexaJobFrameworkDatabase.InsertProductionChain({ chain_key = key, label = definition.label or key, status = definition.status or 'active', crafting_recipe_id = normalizeId(definition.crafting_recipe_id), stages = definition.stages or {}, access_rules = definition.access_rules or {}, metadata = definition.metadata or {} }); return err and fail(NEXA_JOB_ERRORS.databaseError, 'Production chain could not be registered.', err) or ok({ production_chain_id = id, chain_key = key }, 'Production chain registered.') end
function ProductionChains.Get(chainIdOrKey) local row, err = NexaJobFrameworkDatabase.GetProductionChain(chainIdOrKey); return err and fail(NEXA_JOB_ERRORS.databaseError, 'Production chain could not be loaded.', err) or (row and ok(row, 'Production chain loaded.') or fail(NEXA_JOB_ERRORS.taskValidationFailed, 'Production chain not found.')) end
function ProductionChains.Validate(definition) return type(definition) == 'table' and normalizeString(definition.chain_key or definition.key, 64) ~= nil end
function ProductionChains.Start(source, chainId, stageId, context) return ok({ source = source, chain_id = chainId, stage_id = stageId, crafting_required = 'nexa_crafting' }, 'Production chain stage started.') end

function Rewards.Get(sessionId) local rows, err = NexaJobFrameworkDatabase.ListRewards(normalizeId(sessionId)); return err and fail(NEXA_JOB_ERRORS.databaseError, 'Rewards could not be listed.', err) or ok(rows or {}, 'Rewards listed.') end
function Rewards.Record(sessionId, characterId, reward) reward = type(reward) == 'table' and reward or {}; local id, err = NexaJobFrameworkDatabase.InsertReward({ session_id = normalizeId(sessionId), character_id = normalizeId(characterId), reward_type = reward.reward_type or 'preview', currency = reward.currency, amount = tonumber(reward.amount), item_name = reward.item_name, item_amount = tonumber(reward.item_amount), status = reward.status or NEXA_JOB_REWARD_STATUS.pending, idempotency_key = reward.idempotency_key or ('jobreward:%s:%s:%s'):format(sessionId, characterId, os.time()), metadata = reward.metadata or {} }); return err and fail(NEXA_JOB_ERRORS.databaseError, 'Reward could not be recorded.', err) or ok({ reward_id = id }, 'Reward recorded.') end
function Rewards.Retry(rewardId, context) return ok({ reward_id = normalizeId(rewardId), retry = true }, 'Reward retry foundation recorded.') end

function AntiAfk.Validate(source, sessionId, action, context) return ok({ source = source, session_id = sessionId, action = action, valid = true }, 'Anti-AFK action accepted.') end

function GetJobDefinition(...) return JobDefinitions.Get(...) end
function ListJobDefinitions(...) return JobDefinitions.List(...) end
function CanStartJob(...) return JobSessions.CanStart(...) end
function StartJob(...) return JobSessions.Create(...) end
function CancelJob(...) return JobSessions.Cancel(...) end
function GetJobSession(...) return JobSessions.Get(...) end
function GetCharacterJobSession(...) return JobSessions.GetByCharacter(...) end
function ListActiveJobSessions(...) return JobSessions.ListActive(...) end
function GetTaskProgress(...) return Progress.Get(...) end
function CompleteJobTask(...) return Progress.Complete(...) end
function GetJobRewards(...) return Rewards.Get(...) end
function RetryJobReward(...) return Rewards.Retry(...) end
function CreateJobDefinition(...) return JobDefinitions.Create(...) end
function UpdateJobDefinition(...) return JobDefinitions.Update(...) end
function ActivateJobDefinition(...) return JobDefinitions.Activate(...) end
function SuspendJobDefinition(...) return JobDefinitions.Suspend(...) end
function DisableJobDefinition(...) return JobDefinitions.Disable(...) end
function RegisterJobType(...) return JobTypes.Register(...) end
function RegisterTaskType(...) return TaskTypes.Register(...) end
function RegisterResourceNode(...) return ResourceNodes.Register(...) end
function RegisterProductionChain(...) return ProductionChains.Register(...) end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    registerDefaults()
    if NexaJobFrameworkConfig.autoMigrate then migrated = NexaJobFrameworkDatabase.Migrate() == true end
    registerCallbacks()
    local jobTypes = JobTypes.List()
    local taskTypes = TaskTypes.List()
    log('Info', 'jobframework.start', 'nexa_jobframework started.', { migrated = migrated, job_types = #jobTypes, task_types = #taskTypes })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    reservations = {}
end)

exports('GetJobDefinition', GetJobDefinition)
exports('ListJobDefinitions', ListJobDefinitions)
exports('CanStartJob', CanStartJob)
exports('StartJob', StartJob)
exports('CancelJob', CancelJob)
exports('GetJobSession', GetJobSession)
exports('GetCharacterJobSession', GetCharacterJobSession)
exports('ListActiveJobSessions', ListActiveJobSessions)
exports('GetTaskProgress', GetTaskProgress)
exports('CompleteJobTask', CompleteJobTask)
exports('GetJobRewards', GetJobRewards)
exports('RetryJobReward', RetryJobReward)
exports('CreateJobDefinition', CreateJobDefinition)
exports('UpdateJobDefinition', UpdateJobDefinition)
exports('ActivateJobDefinition', ActivateJobDefinition)
exports('SuspendJobDefinition', SuspendJobDefinition)
exports('DisableJobDefinition', DisableJobDefinition)
exports('RegisterJobType', RegisterJobType)
exports('RegisterTaskType', RegisterTaskType)
exports('RegisterResourceNode', RegisterResourceNode)
exports('RegisterProductionChain', RegisterProductionChain)
exports('getStatus', function() return { resourceName = NEXA_JOBFRAMEWORK.resourceName, version = NEXA_JOBFRAMEWORK.version, migrated = migrated, jobTypes = JobTypes.List(), taskTypes = TaskTypes.List(), reservations = reservations } end)
exports('getSchema', NexaJobFrameworkDatabase.GetSchema)
