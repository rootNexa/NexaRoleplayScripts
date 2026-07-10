local migrated = false

PayrollPolicies = {}
DutyTime = {}
PayrollPeriods = {}
PayrollCalculator = {}
PayrollRuns = {}

local function response(success, code, message, data, meta)
    return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_PAYROLL_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } }
end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end

local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function decode(value, fallback) if type(value) ~= 'string' or value == '' then return fallback end; local good, decoded = pcall(json.decode, value); return good and decoded or fallback end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeAmount(value) value = tonumber(value); if not value or value < 1 or value % 1 ~= 0 or value > NexaPayrollConfig.maxAmount then return nil end; return math.floor(value) end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local normalized = value:gsub('^%s+', ''):gsub('%s+$', ''); if normalized == '' or (maxLength and #normalized > maxLength) then return nil end; return normalized end
local function correlationId(prefix) return ('%s:%s:%s:%s'):format(prefix or 'payroll', os.time(), GetGameTimer and GetGameTimer() or 0, math.random(100000, 999999)) end

local function getCore()
    if GetResourceState('nexa-core') ~= 'started' then return nil end
    local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end)
    return good and core or nil
end

local function log(level, category, message, context)
    local core = getCore()
    if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end
    print(('[%s] [%s] %s %s'):format(NEXA_PAYROLL.resourceName, level, message, encode(context)))
end

local function emit(eventName, payload)
    local core = getCore()
    if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_PAYROLL.resourceName }) end
end

local function actorContext(actor, action)
    actor = type(actor) == 'table' and actor or {}
    return { action = action, actor_account_id = normalizeId(actor.actor_account_id), actor_character_id = normalizeId(actor.actor_character_id or actor.character_id), reason = normalizeString(actor.reason, 255), source_resource = normalizeString(actor.source_resource or GetInvokingResource() or NEXA_PAYROLL.resourceName, 64), correlation_id = normalizeString(actor.correlation_id, 128) or correlationId(action), idempotency_key = normalizeString(actor.idempotency_key, 128) }
end

local function audit(action, context, result, payload)
    payload = payload or {}
    NexaPayrollDatabase.InsertAudit({ action = action, actor_account_id = context.actor_account_id, actor_character_id = context.actor_character_id, organization_id = payload.organization_id, run_id = payload.run_id, entry_id = payload.entry_id, amount = payload.amount, before_state = payload.before_state, after_state = payload.after_state, reason = context.reason, result = result.ok and 'success' or 'failed', error_code = result.ok and nil or result.code, source_resource = context.source_resource, correlation_id = context.correlation_id, metadata = payload.metadata })
end

local function normalizePolicy(row)
    if type(row) ~= 'table' then return row end
    row.id = normalizeId(row.id); row.organization_id = normalizeId(row.organization_id); row.rank_id = normalizeId(row.rank_id)
    row.amount = tonumber(row.amount) or 0; row.interval_seconds = tonumber(row.interval_seconds) or NexaPayrollConfig.defaultIntervalSeconds
    row.minimum_duty_seconds = tonumber(row.minimum_duty_seconds) or 0; row.prorated = row.prorated == true or tonumber(row.prorated) == 1
    row.max_amount = row.max_amount and tonumber(row.max_amount) or nil; row.metadata = decode(row.metadata, {})
    return row
end

function PayrollPolicies.Create(definition, actor)
    definition = type(definition) == 'table' and definition or {}
    local context = actorContext(actor, 'payroll.policy.create')
    local amount = normalizeAmount(definition.amount)
    local organizationId, rankId = normalizeId(definition.organization_id), normalizeId(definition.rank_id)
    if not organizationId or not rankId or not amount then return fail(NEXA_PAYROLL_ERRORS.policyInvalid, 'Payroll policy is invalid.') end
    local policyId, err = NexaPayrollDatabase.InsertPolicy({ organization_id = organizationId, rank_id = rankId, amount = amount, interval_seconds = tonumber(definition.interval_seconds) or NexaPayrollConfig.defaultIntervalSeconds, minimum_duty_seconds = tonumber(definition.minimum_duty_seconds) or 0, prorated = definition.prorated == true, max_amount = definition.max_amount and normalizeAmount(definition.max_amount) or nil, status = definition.status or NEXA_PAYROLL_POLICY_STATUS.draft, valid_from = definition.valid_from or os.time(), valid_until = definition.valid_until, created_by = context.actor_character_id, metadata = definition.metadata or {} })
    local result = err and fail(NEXA_PAYROLL_ERRORS.databaseError, 'Policy could not be created.', err) or ok({ id = policyId }, 'Policy created.')
    audit('payroll.policy.create', context, result, { organization_id = organizationId, amount = amount, after_state = definition })
    return result
end

function PayrollPolicies.Get(policyId)
    local row, err = NexaPayrollDatabase.GetPolicy(normalizeId(policyId))
    if err then return fail(NEXA_PAYROLL_ERRORS.databaseError, 'Policy could not be loaded.', err) end
    row = normalizePolicy(row)
    return row and ok(row, 'Policy loaded.') or fail(NEXA_PAYROLL_ERRORS.policyNotFound, 'Policy not found.')
end

function PayrollPolicies.List(organizationId, filters)
    local rows, err = NexaPayrollDatabase.ListPolicies(normalizeId(organizationId))
    if err then return fail(NEXA_PAYROLL_ERRORS.databaseError, 'Policies could not be listed.', err) end
    for i, row in ipairs(rows or {}) do rows[i] = normalizePolicy(row) end
    return ok(rows or {}, 'Policies listed.')
end

function PayrollPolicies.Update(policyId, changes, actor)
    local context = actorContext(actor, 'payroll.policy.update')
    changes = type(changes) == 'table' and changes or {}
    if changes.amount ~= nil then changes.amount = normalizeAmount(changes.amount) end
    local _, err = NexaPayrollDatabase.UpdatePolicy(normalizeId(policyId), { amount = changes.amount, status = changes.status, minimum_duty_seconds = changes.minimum_duty_seconds, prorated = changes.prorated, max_amount = changes.max_amount, updated_by = context.actor_character_id })
    local result = err and fail(NEXA_PAYROLL_ERRORS.databaseError, 'Policy could not be updated.', err) or ok({ id = policyId }, 'Policy updated.')
    audit('payroll.policy.update', context, result, { after_state = changes })
    return result
end

function PayrollPolicies.Activate(policyId, actor) return PayrollPolicies.Update(policyId, { status = NEXA_PAYROLL_POLICY_STATUS.active }, actor) end
function PayrollPolicies.Suspend(policyId, actor, reason) actor = actor or {}; actor.reason = actor.reason or reason; if not actor.reason then return fail(NEXA_PAYROLL_ERRORS.reasonRequired, 'Reason is required.') end; return PayrollPolicies.Update(policyId, { status = NEXA_PAYROLL_POLICY_STATUS.suspended }, actor) end
function PayrollPolicies.GetForRank(organizationId, rankId, atTime)
    local row, err = NexaPayrollDatabase.GetPolicyForRank(normalizeId(organizationId), normalizeId(rankId))
    if err then return fail(NEXA_PAYROLL_ERRORS.databaseError, 'Policy could not be loaded.', err) end
    row = normalizePolicy(row)
    return row and ok(row, 'Policy loaded.') or fail(NEXA_PAYROLL_ERRORS.noPolicy, 'No policy for rank.')
end

local function timestamp(value)
    if type(value) == 'number' then return math.floor(value) end
    return os.time()
end

function DutyTime.GetSessions(characterId, organizationId, filters)
    filters = type(filters) == 'table' and filters or {}
    local startAt = timestamp(filters.period_start or filters.start_at)
    local endAt = timestamp(filters.period_end or filters.end_at)
    local rows, err = NexaPayrollDatabase.ListDutySessions(normalizeId(characterId), normalizeId(organizationId), startAt, endAt)
    return err and fail(NEXA_PAYROLL_ERRORS.databaseError, 'Duty sessions could not be loaded.', err) or ok(rows or {}, 'Duty sessions loaded.')
end

function DutyTime.Calculate(characterId, organizationId, periodStart, periodEnd)
    periodStart, periodEnd = timestamp(periodStart), timestamp(periodEnd)
    if periodEnd <= periodStart then return fail(NEXA_PAYROLL_ERRORS.invalidInput, 'Period is invalid.') end
    local sessions = DutyTime.GetSessions(characterId, organizationId, { period_start = periodStart, period_end = periodEnd })
    if not sessions.ok then return sessions end
    local total, segments = 0, {}
    for _, session in ipairs(sessions.data) do
        local started = session.started_at_unix or periodStart
        local ended = session.ended_at_unix or periodEnd
        started, ended = math.max(periodStart, tonumber(started) or periodStart), math.min(periodEnd, tonumber(ended) or periodEnd)
        if ended > started then
            local seconds = ended - started
            total = total + seconds
            segments[#segments + 1] = { start_at = started, end_at = ended, seconds = seconds, status = session.status }
        end
    end
    return ok({ character_id = characterId, organization_id = organizationId, period_start = periodStart, period_end = periodEnd, duty_seconds = total, segments = segments }, 'Duty time calculated.')
end

function DutyTime.ValidateSessions(characterId, organizationId, period) return DutyTime.Calculate(characterId, organizationId, period.period_start, period.period_end) end
function DutyTime.GetReport(characterId, organizationId, period) return DutyTime.Calculate(characterId, organizationId, period.period_start, period.period_end) end

function PayrollPeriods.GetCurrent(scope)
    scope = type(scope) == 'table' and scope or {}
    local scopeType, scopeId = normalizeString(scope.scope_type or 'global', 32), normalizeString(tostring(scope.scope_id or 'default'), 64)
    local row, err = NexaPayrollDatabase.GetCurrentPeriod(scopeType, scopeId, os.time())
    if err then return fail(NEXA_PAYROLL_ERRORS.databaseError, 'Period could not be loaded.', err) end
    return row and ok(row, 'Current period loaded.') or fail(NEXA_PAYROLL_ERRORS.periodNotFound, 'Current period not found.')
end

function PayrollPeriods.CreateNext(scope, context)
    scope = type(scope) == 'table' and scope or {}
    local now = os.time()
    local periodStart = scope.period_start or (now - (now % NexaPayrollConfig.defaultIntervalSeconds))
    local periodEnd = scope.period_end or (periodStart + NexaPayrollConfig.defaultIntervalSeconds)
    local periodId, err = NexaPayrollDatabase.InsertPeriod({ scope_type = scope.scope_type or 'organization', scope_id = tostring(scope.scope_id or '0'), period_start = periodStart, period_end = periodEnd, status = NEXA_PAYROLL_PERIOD_STATUS.open, metadata = {} })
    return err and fail(NEXA_PAYROLL_ERRORS.periodOverlap, 'Period could not be created.', err) or ok({ id = periodId, period_start = periodStart, period_end = periodEnd }, 'Period created.')
end

function PayrollPeriods.Close(periodId, context)
    local _, err = NexaPayrollDatabase.UpdatePeriodStatus(normalizeId(periodId), NEXA_PAYROLL_PERIOD_STATUS.ready)
    return err and fail(NEXA_PAYROLL_ERRORS.databaseError, 'Period could not be closed.', err) or ok({ id = periodId }, 'Period closed.')
end
function PayrollPeriods.Get(periodId) local row, err = NexaPayrollDatabase.GetPeriod(normalizeId(periodId)); return err and fail(NEXA_PAYROLL_ERRORS.databaseError, 'Period load failed.', err) or (row and ok(row, 'Period loaded.') or fail(NEXA_PAYROLL_ERRORS.periodNotFound, 'Period not found.')) end
function PayrollPeriods.List(filters) return ok({}, 'Period listing is deferred in foundation.') end

function PayrollCalculator.CalculateSegment(segment, policy)
    local dutySeconds = tonumber(segment.duty_seconds or segment.seconds) or 0
    if dutySeconds <= 0 then return 0 end
    if dutySeconds < policy.minimum_duty_seconds then return 0 end
    local amount = policy.amount
    if policy.prorated then amount = math.floor((policy.amount * dutySeconds) / policy.interval_seconds) end
    if policy.max_amount and amount > policy.max_amount then amount = policy.max_amount end
    return math.max(0, amount)
end

function PayrollCalculator.ValidateResult(result)
    return type(result) == 'table' and tonumber(result.calculated_amount or 0) >= 0
end

function PayrollCalculator.Calculate(characterId, organizationId, periodId)
    local period = PayrollPeriods.Get(periodId); if not period.ok then return period end
    local member = exports.nexa_organizations:GetCharacterOrganization(characterId); if not member or not member.ok then return fail(NEXA_PAYROLL_ERRORS.invalidInput, 'Membership missing.') end
    local policy = PayrollPolicies.GetForRank(organizationId, member.data.rank_id); if not policy.ok then return policy end
    local duty = DutyTime.Calculate(characterId, organizationId, os.time() - policy.data.interval_seconds, os.time()); if not duty.ok then return duty end
    local amount = PayrollCalculator.CalculateSegment({ duty_seconds = duty.data.duty_seconds }, policy.data)
    return ok({ character_id = characterId, organization_id = organizationId, rank_id = member.data.rank_id, policy_id = policy.data.id, duty_seconds = duty.data.duty_seconds, calculated_amount = amount, breakdown = { strategy = policy.data.prorated and 'prorated' or 'threshold' } }, 'Payroll calculated.')
end
function PayrollCalculator.GetBreakdown(characterId, periodId) return ok({ character_id = characterId, period_id = periodId }, 'Breakdown deferred in foundation.') end

function PayrollRuns.Create(periodId, organizationId, context)
    context = actorContext(context, 'payroll.run.create')
    local runId, err = NexaPayrollDatabase.InsertRun({ period_id = normalizeId(periodId), organization_id = normalizeId(organizationId), status = NEXA_PAYROLL_RUN_STATUS.created, correlation_id = context.correlation_id, idempotency_key = context.idempotency_key, metadata = { funding_policy = NexaPayrollConfig.defaultFundingPolicy } })
    local result = err and fail(NEXA_PAYROLL_ERRORS.runAlreadyExists, 'Run could not be created.', err) or ok({ id = runId }, 'Run created.')
    audit('payroll.run.create', context, result, { organization_id = organizationId, run_id = runId })
    if result.ok then emit(NEXA_PAYROLL_EVENTS.runCreated, result.data) end
    return result
end

function PayrollRuns.Get(runId) local row, err = NexaPayrollDatabase.GetRun(normalizeId(runId)); return err and fail(NEXA_PAYROLL_ERRORS.databaseError, 'Run load failed.', err) or (row and ok(row, 'Run loaded.') or fail(NEXA_PAYROLL_ERRORS.runNotFound, 'Run not found.')) end
function PayrollRuns.List(filters) local rows, err = NexaPayrollDatabase.ListRuns(); return err and fail(NEXA_PAYROLL_ERRORS.databaseError, 'Runs load failed.', err) or ok(rows or {}, 'Runs listed.') end
function PayrollRuns.Calculate(runId)
    local run = PayrollRuns.Get(runId); if not run.ok then return run end
    NexaPayrollDatabase.UpdateRun(run.data.id, { status = NEXA_PAYROLL_RUN_STATUS.calculating })
    return ok({ run_id = run.data.id, status = NEXA_PAYROLL_RUN_STATUS.calculating }, 'Run calculation prepared.')
end

function PayrollRuns.Execute(runId, context)
    context = actorContext(context, 'payroll.run.execute')
    local run = PayrollRuns.Get(runId); if not run.ok then return run end
    if run.data.status == NEXA_PAYROLL_RUN_STATUS.completed then return fail(NEXA_PAYROLL_ERRORS.runAlreadyCompleted, 'Run already completed.') end
    local entries = NexaPayrollDatabase.ListEntries(run.data.id) or {}
    local totalPaid, totalFailed = 0, 0
    for _, entry in ipairs(entries) do
        if entry.status ~= NEXA_PAYROLL_ENTRY_STATUS.paid and tonumber(entry.calculated_amount) and tonumber(entry.calculated_amount) > 0 then
            local target = exports.nexa_economy:GetCharacterBankAccount(entry.character_id)
            if target and target.ok then
                local transfer = exports.nexa_economy:Transfer(entry.source_account_id, target.data.id, entry.calculated_amount, { reason = 'Payroll payout', idempotency_key = entry.idempotency_key, correlation_id = entry.correlation_id, source_resource = NEXA_PAYROLL.resourceName })
                if transfer and transfer.ok then
                    NexaPayrollDatabase.UpdateEntryPaid(entry.id, entry.calculated_amount, transfer.data.transaction_id)
                    totalPaid = totalPaid + tonumber(entry.calculated_amount)
                    emit(NEXA_PAYROLL_EVENTS.entryPaid, { entryId = entry.id, runId = run.data.id })
                else
                    totalFailed = totalFailed + tonumber(entry.calculated_amount)
                    emit(NEXA_PAYROLL_EVENTS.entryFailed, { entryId = entry.id, runId = run.data.id })
                end
            end
        end
    end
    local status = totalFailed > 0 and NEXA_PAYROLL_RUN_STATUS.manualReview or NEXA_PAYROLL_RUN_STATUS.completed
    NexaPayrollDatabase.UpdateRun(run.data.id, { status = status, total_paid = totalPaid, total_failed = totalFailed })
    local result = ok({ run_id = run.data.id, total_paid = totalPaid, total_failed = totalFailed, status = status }, 'Payroll executed.')
    audit('payroll.run.execute', context, result, { organization_id = run.data.organization_id, run_id = run.data.id, amount = totalPaid })
    emit(status == NEXA_PAYROLL_RUN_STATUS.completed and NEXA_PAYROLL_EVENTS.runCompleted or NEXA_PAYROLL_EVENTS.reviewRequired, result.data)
    return result
end

function PayrollRuns.Retry(runId, context) return PayrollRuns.Execute(runId, context) end
function PayrollRuns.Cancel(runId, actor, reason) local context = actorContext(actor or { reason = reason }, 'payroll.run.cancel'); if not context.reason then return fail(NEXA_PAYROLL_ERRORS.reasonRequired, 'Reason is required.') end; NexaPayrollDatabase.UpdateRun(normalizeId(runId), { status = NEXA_PAYROLL_RUN_STATUS.cancelled }); return ok({ run_id = runId }, 'Run cancelled.') end

function GetPayrollPolicy(...) return PayrollPolicies.Get(...) end
function ListPayrollPolicies(...) return PayrollPolicies.List(...) end
function CreatePayrollPolicy(...) return PayrollPolicies.Create(...) end
function UpdatePayrollPolicy(...) return PayrollPolicies.Update(...) end
function GetPayrollPeriod(...) return PayrollPeriods.Get(...) end
function GetPayrollRun(...) return PayrollRuns.Get(...) end
function ListPayrollRuns(...) return PayrollRuns.List(...) end
function CalculatePayroll(...) return PayrollRuns.Calculate(...) end
function ExecutePayroll(...) return PayrollRuns.Execute(...) end
function RetryPayroll(...) return PayrollRuns.Retry(...) end
function CancelPayroll(...) return PayrollRuns.Cancel(...) end
function GetPayrollEntry(id) local row, err = NexaPayrollDatabase.GetEntry(normalizeId(id)); return err and fail(NEXA_PAYROLL_ERRORS.databaseError, 'Entry load failed.', err) or (row and ok(row, 'Entry loaded.') or fail(NEXA_PAYROLL_ERRORS.entryNotFound, 'Entry not found.')) end
function ListPayrollEntries(...) local rows, err = NexaPayrollDatabase.ListEntries(...); return err and fail(NEXA_PAYROLL_ERRORS.databaseError, 'Entries load failed.', err) or ok(rows or {}, 'Entries listed.') end
function GetDutyTimeReport(...) return DutyTime.GetReport(...) end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if NexaPayrollConfig.autoMigrate then migrated = NexaPayrollDatabase.Migrate() == true end
    log('Info', 'payroll.start', 'nexa_payroll started.', { migrated = migrated })
end)

exports('GetPayrollPolicy', GetPayrollPolicy)
exports('ListPayrollPolicies', ListPayrollPolicies)
exports('CreatePayrollPolicy', CreatePayrollPolicy)
exports('UpdatePayrollPolicy', UpdatePayrollPolicy)
exports('GetPayrollPeriod', GetPayrollPeriod)
exports('GetPayrollRun', GetPayrollRun)
exports('ListPayrollRuns', ListPayrollRuns)
exports('CalculatePayroll', CalculatePayroll)
exports('ExecutePayroll', ExecutePayroll)
exports('RetryPayroll', RetryPayroll)
exports('CancelPayroll', CancelPayroll)
exports('GetPayrollEntry', GetPayrollEntry)
exports('ListPayrollEntries', ListPayrollEntries)
exports('GetDutyTimeReport', GetDutyTimeReport)
exports('getStatus', function() return { resourceName = NEXA_PAYROLL.resourceName, version = NEXA_PAYROLL.version, migrated = migrated, intervalSeconds = NexaPayrollConfig.defaultIntervalSeconds } end)
exports('getSchema', NexaPayrollDatabase.GetSchema)
