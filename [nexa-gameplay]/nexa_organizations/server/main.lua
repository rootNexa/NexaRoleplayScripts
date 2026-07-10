local migrated = false

OrganizationTypes = { entries = {} }
Organizations = { ready = false }
Ranks = {}
Memberships = {}
OrganizationPermissions = {}
OrganizationModules = {}
OrganizationAccounts = {}
OrganizationStorages = {}
OrganizationGarages = {}

local function response(success, code, message, data, meta)
    return {
        ok = success == true,
        success = success == true,
        code = code or (success and 'OK' or NEXA_ORGANIZATION_ERRORS.invalidInput),
        message = message or '',
        data = data,
        meta = meta,
        error = success == true and nil or { code = code, message = message }
    }
end

local function ok(data, message, meta)
    return response(true, 'OK', message or 'OK', data, meta)
end

local function fail(code, message, meta)
    return response(false, code, message or code, nil, meta)
end

local function encode(value)
    local encodedOk, encoded = pcall(json.encode, value or {})
    return encodedOk and encoded or '{}'
end

local function decode(value, fallback)
    if type(value) ~= 'string' or value == '' then
        return fallback
    end
    local okDecode, decoded = pcall(json.decode, value)
    return okDecode and decoded or fallback
end

local function getCore()
    if GetResourceState('nexa-core') ~= 'started' then
        return nil
    end
    local okCore, core = pcall(function()
        return exports['nexa-core']:GetCoreObject()
    end)
    return okCore and core or nil
end

local function log(level, category, message, context)
    local core = getCore()
    if core and core.Logger and core.Logger[level] then
        core.Logger[level](category, message, context)
        return
    end
    print(('[%s] [%s] %s %s'):format(NEXA_ORGANIZATIONS.resourceName, level, message, encode(context)))
end

local function emit(eventName, payload)
    local core = getCore()
    if core and core.EventBus then
        core.EventBus.Emit(eventName, payload, { resource = NEXA_ORGANIZATIONS.resourceName })
    end
end

local function normalizeId(value)
    local id = tonumber(value)
    return id and id > 0 and id % 1 == 0 and math.floor(id) or nil
end

local function normalizeString(value, maxLength)
    if type(value) ~= 'string' then
        return nil
    end
    local normalized = value:gsub('^%s+', ''):gsub('%s+$', '')
    if normalized == '' or (maxLength and #normalized > maxLength) then
        return nil
    end
    return normalized
end

local function normalizeSlug(value, maxLength)
    value = normalizeString(value, maxLength or 64)
    if not value then
        return nil
    end
    value = value:lower()
    if value:find('^[a-z0-9_%-]+$') == nil then
        return nil
    end
    return value
end

local function normalizeBool(value, defaultValue)
    if value == nil then
        return defaultValue
    end
    return value == true or tonumber(value) == 1
end

local function correlationId(prefix)
    return ('%s:%s:%s:%s'):format(prefix or 'org', os.time(), GetGameTimer and GetGameTimer() or 0, math.random(100000, 999999))
end

local function contextOf(actor, action)
    actor = type(actor) == 'table' and actor or {}
    return {
        action = action,
        actor_account_id = normalizeId(actor.actor_account_id or actor.account_id),
        actor_character_id = normalizeId(actor.actor_character_id or actor.character_id),
        reason = normalizeString(actor.reason, 255),
        source_resource = normalizeString(actor.source_resource or GetInvokingResource() or NEXA_ORGANIZATIONS.resourceName, 64),
        correlation_id = normalizeString(actor.correlation_id, 128) or correlationId(action)
    }
end

local function audit(action, context, result, payload)
    payload = payload or {}
    NexaOrganizationsDatabase.InsertAudit({
        organization_id = payload.organization_id,
        action = action,
        actor_account_id = context.actor_account_id,
        actor_character_id = context.actor_character_id,
        target_character_id = payload.target_character_id,
        rank_id = payload.rank_id,
        before_state = payload.before_state,
        after_state = payload.after_state,
        reason = context.reason,
        result = result.ok and 'success' or 'failed',
        error_code = result.ok and nil or result.code,
        source_resource = context.source_resource,
        correlation_id = context.correlation_id,
        metadata = payload.metadata
    })
end

local function normalizeOrganization(row)
    if type(row) ~= 'table' then
        return row
    end
    row.id = normalizeId(row.id)
    row.owner_character_id = normalizeId(row.owner_character_id)
    row.economy_account_id = normalizeId(row.economy_account_id)
    row.settings = decode(row.settings, {})
    row.metadata = decode(row.metadata, {})
    row.version = tonumber(row.version) or 1
    return row
end

local function normalizeRank(row)
    if type(row) ~= 'table' then
        return row
    end
    row.id = normalizeId(row.id)
    row.organization_id = normalizeId(row.organization_id)
    row.position = tonumber(row.position) or 0
    row.is_leadership = normalizeBool(row.is_leadership, false)
    row.is_owner_rank = normalizeBool(row.is_owner_rank, false)
    row.permissions = decode(row.permissions, {})
    row.salary_policy = decode(row.salary_policy, {})
    row.metadata = decode(row.metadata, {})
    return row
end

local function normalizeMember(row)
    if type(row) ~= 'table' then
        return row
    end
    row.id = normalizeId(row.id)
    row.organization_id = normalizeId(row.organization_id)
    row.character_id = normalizeId(row.character_id)
    row.rank_id = normalizeId(row.rank_id)
    row.metadata = decode(row.metadata, {})
    return row
end

function OrganizationTypes.Validate(name, definition)
    name = normalizeSlug(name or (definition and definition.name), 32)
    if not name then
        return fail(NEXA_ORGANIZATION_ERRORS.typeInvalid, 'Organization type is invalid.')
    end
    return ok(name, 'Organization type is valid.')
end

function OrganizationTypes.Register(definition)
    if type(definition) ~= 'table' then
        return fail(NEXA_ORGANIZATION_ERRORS.typeInvalid, 'Organization type definition is invalid.')
    end
    local valid = OrganizationTypes.Validate(definition.name, definition)
    if not valid.ok then
        return valid
    end
    local name = valid.data
    OrganizationTypes.entries[name] = {
        name = name,
        label = normalizeString(definition.label, 96) or name,
        description = normalizeString(definition.description, 255) or '',
        government = definition.government == true,
        duty_required = definition.duty_required == true,
        account_allowed = definition.account_allowed ~= false,
        storage_allowed = definition.storage_allowed ~= false,
        garage_allowed = definition.garage_allowed ~= false,
        armory_allowed = definition.armory_allowed == true,
        dispatch_allowed = definition.dispatch_allowed == true,
        mdt_allowed = definition.mdt_allowed == true,
        radio_allowed = definition.radio_allowed == true,
        billing_allowed = definition.billing_allowed == true,
        payroll_allowed = definition.payroll_allowed == true,
        illegal = definition.illegal == true,
        modules = definition.modules or {}
    }
    return ok(OrganizationTypes.entries[name], 'Organization type registered.')
end

function OrganizationTypes.Get(name)
    return OrganizationTypes.entries[normalizeSlug(name, 32)]
end

function OrganizationTypes.List()
    local list = {}
    for _, entry in pairs(OrganizationTypes.entries) do
        list[#list + 1] = entry
    end
    table.sort(list, function(left, right) return left.name < right.name end)
    return list
end

function OrganizationTypes.IsRegistered(name)
    return OrganizationTypes.Get(name) ~= nil
end

local function registerDefaultTypes()
    local defaults = {
        police = { label = 'Police', government = true, duty_required = true, dispatch_allowed = true, mdt_allowed = true, radio_allowed = true, account_allowed = true, storage_allowed = true, garage_allowed = true, armory_allowed = true, modules = { 'mdt', 'dispatch', 'garage', 'storage', 'armory', 'radio', 'impound', 'evidence' } },
        ems = { label = 'EMS', government = true, duty_required = true, dispatch_allowed = true, mdt_allowed = true, radio_allowed = true, medical = true, modules = { 'mdt', 'dispatch', 'garage', 'storage', 'medical', 'radio' } },
        government = { label = 'Government', government = true, duty_required = true, billing_allowed = true, modules = { 'documents', 'licenses', 'billing' } },
        gang = { label = 'Gang', illegal = true, duty_required = false, modules = { 'storage', 'garage' } },
        business = { label = 'Business', billing_allowed = true, payroll_allowed = true, modules = { 'billing', 'storage', 'garage' } },
        media = { label = 'Media', modules = { 'documents', 'radio' } },
        taxi = { label = 'Taxi', duty_required = true, garage_allowed = true, modules = { 'garage', 'billing', 'radio' } },
        mechanic = { label = 'Mechanic', duty_required = true, garage_allowed = true, storage_allowed = true, modules = { 'garage', 'storage', 'billing' } },
        custom = { label = 'Custom' },
        security = { label = 'Security', duty_required = true, dispatch_allowed = true, radio_allowed = true, modules = { 'dispatch', 'radio', 'garage' } },
        fire_department = { label = 'Fire Department', government = true, duty_required = true, dispatch_allowed = true, radio_allowed = true, modules = { 'dispatch', 'radio', 'garage', 'medical' } }
    }
    for name, definition in pairs(defaults) do
        definition.name = name
        OrganizationTypes.Register(definition)
    end
end

local function validateRankSet(ranks)
    ranks = type(ranks) == 'table' and ranks or {}
    if #ranks < NexaOrganizationsConfig.minRanks then
        return fail(NEXA_ORGANIZATION_ERRORS.rankLimitMin, 'At least five ranks are required.')
    end
    if #ranks > NexaOrganizationsConfig.maxRanks then
        return fail(NEXA_ORGANIZATION_ERRORS.rankLimitMax, 'Too many ranks.')
    end
    local ownerRanks = 0
    for _, rank in ipairs(ranks) do
        if rank.is_owner_rank == true then
            ownerRanks = ownerRanks + 1
        end
    end
    if ownerRanks ~= 1 then
        return fail(NEXA_ORGANIZATION_ERRORS.ownerRankRequired, 'Exactly one owner rank is required.')
    end
    return nil
end

local function getOrganizationOrFail(organizationId)
    organizationId = normalizeId(organizationId)
    if not organizationId then
        return nil, fail(NEXA_ORGANIZATION_ERRORS.notFound, 'Organization not found.')
    end
    local row, err = NexaOrganizationsDatabase.GetOrganization(organizationId)
    if err then
        return nil, fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Organization could not be loaded.', err)
    end
    row = normalizeOrganization(row)
    return row, row and nil or fail(NEXA_ORGANIZATION_ERRORS.notFound, 'Organization not found.')
end

function Organizations.Create(definition, actor)
    definition = type(definition) == 'table' and definition or {}
    local context = contextOf(actor, 'create_organization')
    local name = normalizeSlug(definition.name, 64)
    local label = normalizeString(definition.label, 128)
    local organizationType = normalizeSlug(definition.organization_type or definition.organizationType, 32)
    if not name then return fail(NEXA_ORGANIZATION_ERRORS.nameInvalid, 'Organization name is invalid.') end
    if not label then return fail(NEXA_ORGANIZATION_ERRORS.invalidInput, 'Organization label is required.') end
    if not OrganizationTypes.IsRegistered(organizationType) then return fail(NEXA_ORGANIZATION_ERRORS.typeInvalid, 'Organization type is invalid.') end
    local existing = NexaOrganizationsDatabase.GetOrganizationByName(name)
    if existing then return fail(NEXA_ORGANIZATION_ERRORS.alreadyExists, 'Organization already exists.') end

    local organizationId, err = NexaOrganizationsDatabase.InsertOrganization({
        name = name,
        label = label,
        organization_type = organizationType,
        status = NEXA_ORGANIZATION_STATUS.draft,
        owner_character_id = normalizeId(definition.owner_character_id),
        settings = definition.settings or {},
        metadata = definition.metadata or {},
        created_by = context.actor_character_id
    })
    if err then return fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Organization could not be created.', err) end
    local result = ok({ id = organizationId }, 'Organization created.')
    audit('organization.create', context, result, { organization_id = organizationId, after_state = definition })
    emit(NEXA_ORGANIZATION_EVENTS.created, { organizationId = organizationId })
    return result
end

function Organizations.Get(organizationId)
    local organization, invalid = getOrganizationOrFail(organizationId)
    return invalid or ok(organization, 'Organization loaded.')
end

function Organizations.GetByName(name)
    name = normalizeSlug(name, 64)
    if not name then return fail(NEXA_ORGANIZATION_ERRORS.nameInvalid, 'Organization name is invalid.') end
    local row, err = NexaOrganizationsDatabase.GetOrganizationByName(name)
    if err then return fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Organization could not be loaded.', err) end
    row = normalizeOrganization(row)
    return row and ok(row, 'Organization loaded.') or fail(NEXA_ORGANIZATION_ERRORS.notFound, 'Organization not found.')
end

function Organizations.List(filters)
    local rows, err = NexaOrganizationsDatabase.ListOrganizations(filters)
    if err then return fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Organizations could not be listed.', err) end
    for index, row in ipairs(rows or {}) do rows[index] = normalizeOrganization(row) end
    return ok(rows or {}, 'Organizations listed.')
end

function Organizations.Update(organizationId, changes, actor)
    changes = type(changes) == 'table' and changes or {}
    local context = contextOf(actor, 'update_organization')
    local organization, invalid = getOrganizationOrFail(organizationId)
    if invalid then return invalid end
    local _, err = NexaOrganizationsDatabase.UpdateOrganization(organization.id, changes)
    local result = err and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Organization could not be updated.', err) or ok({ id = organization.id }, 'Organization updated.')
    audit('organization.update', context, result, { organization_id = organization.id, before_state = organization, after_state = changes })
    return result
end

local function setOrganizationStatus(organizationId, status, actor, action, eventName)
    local context = contextOf(actor, action)
    if (action ~= 'organization.activate') and not context.reason then
        return fail(NEXA_ORGANIZATION_ERRORS.reasonRequired, 'Reason is required.')
    end
    local organization, invalid = getOrganizationOrFail(organizationId)
    if invalid then return invalid end
    if status == NEXA_ORGANIZATION_STATUS.active then
        local ranks = Ranks.List(organization.id)
        local rankInvalid = validateRankSet(ranks.ok and ranks.data or {})
        if rankInvalid then return rankInvalid end
    end
    local _, err = NexaOrganizationsDatabase.UpdateOrganization(organization.id, { status = status })
    local result = err and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Organization status could not be changed.', err) or ok({ id = organization.id, status = status }, 'Organization status changed.')
    audit(action, context, result, { organization_id = organization.id, before_state = organization, after_state = { status = status } })
    if result.ok and eventName then emit(eventName, { organizationId = organization.id, status = status }) end
    return result
end

function Organizations.Activate(organizationId, actor) return setOrganizationStatus(organizationId, NEXA_ORGANIZATION_STATUS.active, actor, 'organization.activate', NEXA_ORGANIZATION_EVENTS.activated) end
function Organizations.Suspend(organizationId, actor, reason) actor = actor or {}; actor.reason = actor.reason or reason; return setOrganizationStatus(organizationId, NEXA_ORGANIZATION_STATUS.suspended, actor, 'organization.suspend', NEXA_ORGANIZATION_EVENTS.suspended) end
function Organizations.Archive(organizationId, actor, reason) actor = actor or {}; actor.reason = actor.reason or reason; return setOrganizationStatus(organizationId, NEXA_ORGANIZATION_STATUS.archived, actor, 'organization.archive') end
function Organizations.Restore(organizationId, actor, reason) actor = actor or {}; actor.reason = actor.reason or reason; return setOrganizationStatus(organizationId, NEXA_ORGANIZATION_STATUS.draft, actor, 'organization.restore') end
function Organizations.Delete(organizationId, actor, reason)
    local context = contextOf(actor or { reason = reason }, 'organization.delete')
    if not context.reason then return fail(NEXA_ORGANIZATION_ERRORS.reasonRequired, 'Reason is required.') end
    local organization, invalid = getOrganizationOrFail(organizationId)
    if invalid then return invalid end
    local _, err = NexaOrganizationsDatabase.SoftDeleteOrganization(organization.id)
    local result = err and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Organization could not be deleted.', err) or ok({ id = organization.id }, 'Organization deleted.')
    audit('organization.delete', context, result, { organization_id = organization.id, before_state = organization })
    return result
end

function Ranks.Create(organizationId, definition, actor)
    local context = contextOf(actor, 'rank.create')
    local organization, invalid = getOrganizationOrFail(organizationId)
    if invalid then return invalid end
    definition = type(definition) == 'table' and definition or {}
    local ranks = Ranks.List(organization.id)
    if ranks.ok and #ranks.data >= NexaOrganizationsConfig.maxRanks then return fail(NEXA_ORGANIZATION_ERRORS.rankLimitMax, 'Too many ranks.') end
    local rankKey = normalizeSlug(definition.rank_key or definition.name or definition.key, 64)
    local label = normalizeString(definition.label, 128)
    local position = tonumber(definition.position)
    if not rankKey or not label or not position then return fail(NEXA_ORGANIZATION_ERRORS.invalidInput, 'Rank definition is invalid.') end
    local rankId, err = NexaOrganizationsDatabase.InsertRank({
        organization_id = organization.id,
        rank_key = rankKey,
        label = label,
        position = math.floor(position),
        is_leadership = definition.is_leadership == true,
        is_owner_rank = definition.is_owner_rank == true,
        permissions = definition.permissions or {},
        salary_policy = definition.salary_policy or {},
        metadata = definition.metadata or {}
    })
    local result = err and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Rank could not be created.', err) or ok({ id = rankId }, 'Rank created.')
    audit('rank.create', context, result, { organization_id = organization.id, rank_id = rankId, after_state = definition })
    return result
end

function Ranks.Get(rankId)
    rankId = normalizeId(rankId)
    if not rankId then return fail(NEXA_ORGANIZATION_ERRORS.rankNotFound, 'Rank not found.') end
    local row, err = NexaOrganizationsDatabase.GetRank(rankId)
    if err then return fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Rank could not be loaded.', err) end
    row = normalizeRank(row)
    return row and ok(row, 'Rank loaded.') or fail(NEXA_ORGANIZATION_ERRORS.rankNotFound, 'Rank not found.')
end

function Ranks.List(organizationId)
    local rows, err = NexaOrganizationsDatabase.ListRanks(normalizeId(organizationId))
    if err then return fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Ranks could not be loaded.', err) end
    for index, row in ipairs(rows or {}) do rows[index] = normalizeRank(row) end
    return ok(rows or {}, 'Ranks listed.')
end

function Ranks.Update(rankId, changes, actor)
    local context = contextOf(actor, 'rank.update')
    local rank = Ranks.Get(rankId)
    if not rank.ok then return rank end
    local _, err = NexaOrganizationsDatabase.UpdateRank(rank.data.id, changes or {})
    local result = err and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Rank could not be updated.', err) or ok({ id = rank.data.id }, 'Rank updated.')
    audit('rank.update', context, result, { organization_id = rank.data.organization_id, rank_id = rank.data.id, before_state = rank.data, after_state = changes })
    return result
end

function Ranks.Delete(rankId, actor, reason)
    local context = contextOf(actor or { reason = reason }, 'rank.delete')
    if not context.reason then return fail(NEXA_ORGANIZATION_ERRORS.reasonRequired, 'Reason is required.') end
    return fail(NEXA_ORGANIZATION_ERRORS.hierarchyForbidden, 'Rank deletion requires member migration and is not available in foundation.')
end

function Ranks.HasPermission(rankId, permission)
    local rank = Ranks.Get(rankId)
    if not rank.ok then return false end
    return rank.data.permissions and rank.data.permissions[permission] == true
end

function Ranks.ValidateHierarchy(actorRank, targetRank, action)
    actorRank = type(actorRank) == 'table' and actorRank or (Ranks.Get(actorRank).data)
    targetRank = type(targetRank) == 'table' and targetRank or (Ranks.Get(targetRank).data)
    if not actorRank or not targetRank then return false, NEXA_ORGANIZATION_ERRORS.rankNotFound end
    if actorRank.is_owner_rank then return true end
    if targetRank.is_owner_rank then return false, NEXA_ORGANIZATION_ERRORS.hierarchyForbidden end
    if actorRank.position <= targetRank.position then return false, NEXA_ORGANIZATION_ERRORS.hierarchyForbidden end
    return true
end

function Memberships.GetByCharacter(characterId)
    local row, err = NexaOrganizationsDatabase.GetActiveMemberByCharacter(normalizeId(characterId))
    if err then return fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Membership could not be loaded.', err) end
    row = normalizeMember(row)
    return row and ok(row, 'Membership loaded.') or fail(NEXA_ORGANIZATION_ERRORS.memberNotFound, 'Membership not found.')
end

function Memberships.Get(organizationId, characterId)
    local row, err = NexaOrganizationsDatabase.GetMember(normalizeId(organizationId), normalizeId(characterId))
    if err then return fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Membership could not be loaded.', err) end
    row = normalizeMember(row)
    return row and ok(row, 'Membership loaded.') or fail(NEXA_ORGANIZATION_ERRORS.memberNotFound, 'Membership not found.')
end

function Memberships.List(organizationId)
    local rows, err = NexaOrganizationsDatabase.ListMembers(normalizeId(organizationId))
    if err then return fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Members could not be listed.', err) end
    for index, row in ipairs(rows or {}) do rows[index] = normalizeMember(row) end
    return ok(rows or {}, 'Members listed.')
end

function Memberships.Invite(actor, organizationId, targetCharacterId, rankId, context)
    local ctx = contextOf(context or actor, 'member.invite')
    organizationId, targetCharacterId, rankId = normalizeId(organizationId), normalizeId(targetCharacterId), normalizeId(rankId)
    if not organizationId or not targetCharacterId or not rankId then return fail(NEXA_ORGANIZATION_ERRORS.invalidInput, 'Invitation input is invalid.') end
    local existing = Memberships.GetByCharacter(targetCharacterId)
    if existing.ok then return fail(NEXA_ORGANIZATION_ERRORS.characterAlreadyAssigned, 'Character already has an active organization.') end
    local invitationId, err = NexaOrganizationsDatabase.InsertInvitation({
        organization_id = organizationId,
        target_character_id = targetCharacterId,
        rank_id = rankId,
        invited_by_character_id = ctx.actor_character_id,
        status = NEXA_ORGANIZATION_INVITATION_STATUS.pending,
        expires_at = os.time() + NexaOrganizationsConfig.invitationTtlSeconds,
        metadata = {}
    })
    local result = err and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Invitation could not be created.', err) or ok({ invitation_id = invitationId }, 'Invitation created.')
    audit('member.invite', ctx, result, { organization_id = organizationId, target_character_id = targetCharacterId, rank_id = rankId })
    return result
end

function Memberships.Accept(targetSource, invitationId)
    local invitation, err = NexaOrganizationsDatabase.GetInvitation(normalizeId(invitationId))
    if err then return fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Invitation could not be loaded.', err) end
    if not invitation or invitation.status ~= NEXA_ORGANIZATION_INVITATION_STATUS.pending then return fail(NEXA_ORGANIZATION_ERRORS.invitationNotFound, 'Invitation not found.') end
    local targetCharacterId = normalizeId(invitation.target_character_id)
    local existing = Memberships.GetByCharacter(targetCharacterId)
    if existing.ok then return fail(NEXA_ORGANIZATION_ERRORS.characterAlreadyAssigned, 'Character already has an active organization.') end
    NexaOrganizationsDatabase.UpdateInvitationStatus(invitation.id, NEXA_ORGANIZATION_INVITATION_STATUS.accepted)
    local memberId, memberErr = NexaOrganizationsDatabase.InsertMember({
        organization_id = invitation.organization_id,
        character_id = targetCharacterId,
        rank_id = invitation.rank_id,
        status = NEXA_ORGANIZATION_MEMBER_STATUS.active,
        invited_by = invitation.invited_by_character_id,
        updated_by = targetCharacterId,
        metadata = {}
    })
    local result = memberErr and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Member could not be created.', memberErr) or ok({ member_id = memberId }, 'Invitation accepted.')
    audit('member.accept', contextOf({ character_id = targetCharacterId }, 'member.accept'), result, { organization_id = invitation.organization_id, target_character_id = targetCharacterId, rank_id = invitation.rank_id })
    emit(NEXA_ORGANIZATION_EVENTS.memberJoined, { organizationId = invitation.organization_id, characterId = targetCharacterId })
    return result
end

function Memberships.Decline(targetSource, invitationId)
    local invitation = NexaOrganizationsDatabase.GetInvitation(normalizeId(invitationId))
    if not invitation then return fail(NEXA_ORGANIZATION_ERRORS.invitationNotFound, 'Invitation not found.') end
    NexaOrganizationsDatabase.UpdateInvitationStatus(invitation.id, NEXA_ORGANIZATION_INVITATION_STATUS.declined)
    return ok({ invitation_id = invitation.id }, 'Invitation declined.')
end

function Memberships.Remove(actor, organizationId, targetCharacterId, reason)
    local ctx = contextOf(actor or { reason = reason }, 'member.remove')
    if not ctx.reason then return fail(NEXA_ORGANIZATION_ERRORS.reasonRequired, 'Reason is required.') end
    local _, err = NexaOrganizationsDatabase.UpdateMemberStatus(normalizeId(organizationId), normalizeId(targetCharacterId), NEXA_ORGANIZATION_MEMBER_STATUS.removed, ctx.actor_character_id)
    local result = err and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Member could not be removed.', err) or ok({ organization_id = organizationId, character_id = targetCharacterId }, 'Member removed.')
    audit('member.remove', ctx, result, { organization_id = organizationId, target_character_id = targetCharacterId })
    emit(NEXA_ORGANIZATION_EVENTS.memberLeft, { organizationId = organizationId, characterId = targetCharacterId })
    return result
end

function Memberships.Leave(source, reason)
    return fail(NEXA_ORGANIZATION_ERRORS.invalidInput, 'Leave requires source-bound character resolution in a live server context.')
end

function Memberships.Promote(actor, organizationId, targetCharacterId, rankId, reason)
    local ctx = contextOf(actor or { reason = reason }, 'member.promote')
    if not ctx.reason then return fail(NEXA_ORGANIZATION_ERRORS.reasonRequired, 'Reason is required.') end
    local _, err = NexaOrganizationsDatabase.UpdateMemberRank(normalizeId(organizationId), normalizeId(targetCharacterId), normalizeId(rankId), ctx.actor_character_id)
    local result = err and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Member rank could not be changed.', err) or ok({ organization_id = organizationId, character_id = targetCharacterId, rank_id = rankId }, 'Member promoted.')
    audit('member.promote', ctx, result, { organization_id = organizationId, target_character_id = targetCharacterId, rank_id = rankId })
    emit(NEXA_ORGANIZATION_EVENTS.memberRankChanged, result.data)
    return result
end

function Memberships.Demote(actor, organizationId, targetCharacterId, rankId, reason)
    local ctx = contextOf(actor or { reason = reason }, 'member.demote')
    ctx.reason = ctx.reason or reason
    return Memberships.Promote(ctx, organizationId, targetCharacterId, rankId, ctx.reason)
end

function Memberships.Suspend(actor, organizationId, targetCharacterId, reason)
    local ctx = contextOf(actor or { reason = reason }, 'member.suspend')
    if not ctx.reason then return fail(NEXA_ORGANIZATION_ERRORS.reasonRequired, 'Reason is required.') end
    local _, err = NexaOrganizationsDatabase.UpdateMemberStatus(normalizeId(organizationId), normalizeId(targetCharacterId), NEXA_ORGANIZATION_MEMBER_STATUS.suspended, ctx.actor_character_id)
    return err and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Member could not be suspended.', err) or ok({ organization_id = organizationId, character_id = targetCharacterId }, 'Member suspended.')
end

function Memberships.Restore(actor, organizationId, targetCharacterId, reason)
    local ctx = contextOf(actor or { reason = reason }, 'member.restore')
    if not ctx.reason then return fail(NEXA_ORGANIZATION_ERRORS.reasonRequired, 'Reason is required.') end
    local _, err = NexaOrganizationsDatabase.UpdateMemberStatus(normalizeId(organizationId), normalizeId(targetCharacterId), NEXA_ORGANIZATION_MEMBER_STATUS.active, ctx.actor_character_id)
    return err and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Member could not be restored.', err) or ok({ organization_id = organizationId, character_id = targetCharacterId }, 'Member restored.')
end

function OrganizationPermissions.Has(characterId, permission, context)
    permission = normalizeString(permission, 96)
    if not permission then return false end
    local member = Memberships.GetByCharacter(characterId)
    if not member.ok then return false end
    local rank = Ranks.Get(member.data.rank_id)
    return rank.ok and rank.data.permissions and rank.data.permissions[permission] == true or false
end

function OrganizationPermissions.Get(characterId)
    local member = Memberships.GetByCharacter(characterId)
    if not member.ok then return {} end
    local rank = Ranks.Get(member.data.rank_id)
    return rank.ok and rank.data.permissions or {}
end

function OrganizationPermissions.GetDecisionTrace(characterId, permission, context)
    local member = Memberships.GetByCharacter(characterId)
    if not member.ok then return { allowed = false, reason = 'NO_MEMBERSHIP' } end
    local rank = Ranks.Get(member.data.rank_id)
    local allowed = rank.ok and rank.data.permissions and rank.data.permissions[permission] == true or false
    return { allowed = allowed, permission = permission, member = member.data, rank = rank.ok and rank.data or nil }
end

function OrganizationAccounts.Ensure(organizationId, context)
    local organization, invalid = getOrganizationOrFail(organizationId)
    if invalid then return invalid end
    if organization.economy_account_id then return ok({ account_id = organization.economy_account_id }, 'Organization account already linked.') end
    if GetResourceState('nexa_economy') ~= 'started' then return fail(NEXA_ORGANIZATION_ERRORS.invalidInput, 'Economy is not started.') end
    local account = exports.nexa_economy:GetAccount(('organization:%s:organization:bank'):format(organization.id))
    if not account or not account.ok then
        return fail(NEXA_ORGANIZATION_ERRORS.invalidInput, 'Economy organization account creation is deferred to economy account API.')
    end
    NexaOrganizationsDatabase.UpdateOrganization(organization.id, { economy_account_id = account.data.id })
    return ok({ account_id = account.data.id }, 'Organization account linked.')
end

function OrganizationModules.Register(moduleDefinition)
    moduleDefinition = type(moduleDefinition) == 'table' and moduleDefinition or {}
    local name = normalizeSlug(moduleDefinition.name, 64)
    if not name then return fail(NEXA_ORGANIZATION_ERRORS.moduleInvalid, 'Module is invalid.') end
    NEXA_ORGANIZATION_MODULES[name] = true
    return ok({ name = name }, 'Module registered.')
end

function OrganizationModules.Enable(organizationId, moduleName, config, actor)
    moduleName = normalizeSlug(moduleName, 64)
    if not NEXA_ORGANIZATION_MODULES[moduleName] then return fail(NEXA_ORGANIZATION_ERRORS.moduleInvalid, 'Module is invalid.') end
    local moduleId, err = NexaOrganizationsDatabase.InsertModule({ organization_id = normalizeId(organizationId), module_name = moduleName, enabled = true, config = config or {} })
    local result = err and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Module could not be enabled.', err) or ok({ id = moduleId, module_name = moduleName }, 'Module enabled.')
    audit('module.enable', contextOf(actor, 'module.enable'), result, { organization_id = organizationId, metadata = { module = moduleName } })
    if result.ok then emit(NEXA_ORGANIZATION_EVENTS.moduleEnabled, { organizationId = organizationId, moduleName = moduleName }) end
    return result
end

function OrganizationModules.Disable(organizationId, moduleName, actor)
    return OrganizationModules.Enable(organizationId, moduleName, { disabled = true }, actor)
end

function OrganizationModules.GetEnabled(organizationId)
    local rows, err = NexaOrganizationsDatabase.ListModules(normalizeId(organizationId))
    return err and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Modules could not be listed.', err) or ok(rows or {}, 'Modules listed.')
end

function OrganizationModules.IsEnabled(organizationId, moduleName)
    local modules = OrganizationModules.GetEnabled(organizationId)
    if not modules.ok then return false end
    for _, module in ipairs(modules.data) do
        if module.module_name == moduleName and normalizeBool(module.enabled, false) then return true end
    end
    return false
end

function OrganizationStorages.Register(organizationId, definition, actor)
    definition = type(definition) == 'table' and definition or {}
    local storageKey = normalizeSlug(definition.storage_key or definition.key, 64)
    if not storageKey then return fail(NEXA_ORGANIZATION_ERRORS.invalidInput, 'Storage key is invalid.') end
    local storageId, err = NexaOrganizationsDatabase.InsertStorage({ organization_id = normalizeId(organizationId), storage_key = storageKey, storage_type = normalizeSlug(definition.storage_type or 'general', 32), inventory_id = normalizeId(definition.inventory_id), duty_required = definition.duty_required == true, permissions = definition.permissions or {}, metadata = definition.metadata or {} })
    return err and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Storage could not be registered.', err) or ok({ id = storageId }, 'Storage registered.')
end

function OrganizationStorages.Get(organizationId, storageKey) return fail(NEXA_ORGANIZATION_ERRORS.invalidInput, 'Storage lookup is deferred in foundation.') end
function OrganizationStorages.List(organizationId) return fail(NEXA_ORGANIZATION_ERRORS.invalidInput, 'Storage listing is deferred in foundation.') end
function OrganizationStorages.CanAccess(actor, storage, action) return false end

function OrganizationGarages.Register(organizationId, definition, actor)
    definition = type(definition) == 'table' and definition or {}
    local garageKey = normalizeSlug(definition.garage_key or definition.key, 64)
    if not garageKey then return fail(NEXA_ORGANIZATION_ERRORS.invalidInput, 'Garage key is invalid.') end
    local garageId, err = NexaOrganizationsDatabase.InsertGarage({ organization_id = normalizeId(organizationId), garage_key = garageKey, garage_type = normalizeSlug(definition.garage_type or 'general', 32), position = definition.position or {}, spawn_points = definition.spawn_points or {}, allowed_ranks = definition.allowed_ranks or {}, duty_required = definition.duty_required == true, vehicle_classes = definition.vehicle_classes or {}, metadata = definition.metadata or {} })
    return err and fail(NEXA_ORGANIZATION_ERRORS.databaseError, 'Garage could not be registered.', err) or ok({ id = garageId }, 'Garage registered.')
end

function OrganizationGarages.Get(organizationId, garageKey) return fail(NEXA_ORGANIZATION_ERRORS.invalidInput, 'Garage lookup is deferred in foundation.') end
function OrganizationGarages.List(organizationId) return fail(NEXA_ORGANIZATION_ERRORS.invalidInput, 'Garage listing is deferred in foundation.') end
function OrganizationGarages.CanUse(actor, garage, context) return false end

local function registerCallbacks()
    local core = getCore()
    if not core or not core.Callbacks then return end
    core.Callbacks.RegisterNetwork('nexa:organizations:cb:getOwnOrganization', function(source)
        local character = exports.nexa_characters:GetActiveCharacter(source)
        local data = type(character) == 'table' and (character.data or character) or {}
        local actualCharacter = data.character or data
        local characterId = normalizeId(actualCharacter.id or actualCharacter.character_id)
        if not characterId then return fail(NEXA_ORGANIZATION_ERRORS.invalidInput, 'No active character.') end
        return Memberships.GetByCharacter(characterId)
    end, { rateLimitMs = 1000 })
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    registerDefaultTypes()
    if NexaOrganizationsConfig.autoMigrate then
        local migrateOk, migrateErr = NexaOrganizationsDatabase.Migrate()
        migrated = migrateOk == true
        if not migrated then log('Error', 'organizations.migration', 'Organizations migration failed.', { error = migrateErr }) end
    end
    registerCallbacks()
    Organizations.ready = migrated
    log('Info', 'organizations.start', 'nexa_organizations started.', { migrated = migrated })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Organizations.ready = false
    log('Info', 'organizations.stop', 'nexa_organizations stopped.')
end)

function GetOrganization(...) return Organizations.Get(...) end
function GetOrganizationByName(...) return Organizations.GetByName(...) end
function ListOrganizations(...) return Organizations.List(...) end
function GetOrganizationMembers(...) return Memberships.List(...) end
function GetOrganizationRanks(...) return Ranks.List(...) end
function GetCharacterOrganization(characterId) return Memberships.GetByCharacter(characterId) end
function HasOrganizationPermission(characterId, permission, context) return OrganizationPermissions.Has(characterId, permission, context) end
function InviteMember(...) return Memberships.Invite(...) end
function AcceptInvitation(...) return Memberships.Accept(...) end
function RemoveMember(...) return Memberships.Remove(...) end
function PromoteMember(...) return Memberships.Promote(...) end
function DemoteMember(...) return Memberships.Demote(...) end
function CreateOrganization(...) return Organizations.Create(...) end
function UpdateOrganization(...) return Organizations.Update(...) end
function ActivateOrganization(...) return Organizations.Activate(...) end
function SuspendOrganization(...) return Organizations.Suspend(...) end
function RegisterStorage(...) return OrganizationStorages.Register(...) end
function RegisterGarage(...) return OrganizationGarages.Register(...) end
function EnableModule(...) return OrganizationModules.Enable(...) end
function DisableModule(...) return OrganizationModules.Disable(...) end

exports('GetOrganization', GetOrganization)
exports('GetOrganizationByName', GetOrganizationByName)
exports('ListOrganizations', ListOrganizations)
exports('GetOrganizationMembers', GetOrganizationMembers)
exports('GetOrganizationRanks', GetOrganizationRanks)
exports('GetCharacterOrganization', GetCharacterOrganization)
exports('HasOrganizationPermission', HasOrganizationPermission)
exports('InviteMember', InviteMember)
exports('AcceptInvitation', AcceptInvitation)
exports('RemoveMember', RemoveMember)
exports('PromoteMember', PromoteMember)
exports('DemoteMember', DemoteMember)
exports('CreateOrganization', CreateOrganization)
exports('UpdateOrganization', UpdateOrganization)
exports('ActivateOrganization', ActivateOrganization)
exports('SuspendOrganization', SuspendOrganization)
exports('RegisterStorage', RegisterStorage)
exports('RegisterGarage', RegisterGarage)
exports('EnableModule', EnableModule)
exports('DisableModule', DisableModule)
exports('getStatus', function()
    return { resourceName = NEXA_ORGANIZATIONS.resourceName, version = NEXA_ORGANIZATIONS.version, ready = Organizations.ready, migrated = migrated, organizationTypes = OrganizationTypes.List() }
end)
exports('getSchema', NexaOrganizationsDatabase.GetSchema)
