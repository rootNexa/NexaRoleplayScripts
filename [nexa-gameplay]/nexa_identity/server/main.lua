NexaIdentity = NexaIdentity or {}
NexaIdentity.accountsById = NexaIdentity.accountsById or {}
NexaIdentity.accountIdBySource = NexaIdentity.accountIdBySource or {}
NexaIdentity.sourceByAccountId = NexaIdentity.sourceByAccountId or {}

local CORE_RESOURCE = 'nexa-core'

local function getCore()
    if GetResourceState(CORE_RESOURCE) ~= 'started' then
        return nil
    end

    local ok, coreObject = pcall(function()
        return exports[CORE_RESOURCE]:GetCoreObject()
    end)

    if not ok or type(coreObject) ~= 'table' then
        return nil
    end

    return coreObject
end

local function log(level, category, message, context)
    local coreObject = getCore()

    if coreObject and coreObject.Logger and coreObject.Logger[level] then
        coreObject.Logger[level](category, message, context)
        return
    end

    print(('[%s] [%s] %s %s'):format(NEXA_IDENTITY.resourceName, level:lower(), message, json.encode(context or {})))
end

local function emitInternal(eventName, payload, context)
    local coreObject = getCore()

    if coreObject and coreObject.EventBus then
        coreObject.EventBus.Emit(eventName, payload, context or {
            module = NEXA_IDENTITY.resourceName
        })
    end
end

local function response(success, code, message, data, meta)
    return {
        success = success == true,
        code = code or (success and 'OK' or 'INTERNAL_ERROR'),
        message = message or '',
        data = data,
        meta = meta
    }
end

local function decodeJson(value)
    if type(value) ~= 'string' or value == '' then
        return {}
    end

    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or {}
end

local function maskIdentifier(value)
    if type(value) ~= 'string' then
        return nil
    end

    local prefix, body = value:match('^([^:]+):(.+)$')

    if not prefix or not body then
        return '<masked>'
    end

    if #body <= 8 then
        return prefix .. ':<masked>'
    end

    return ('%s:%s...%s'):format(prefix, body:sub(1, 4), body:sub(-4))
end

local function normalizeIdentifier(identifierType, value)
    if type(identifierType) ~= 'string' or type(value) ~= 'string' then
        return nil, nil
    end

    identifierType = identifierType:lower():gsub('%s+', '')
    value = value:lower():gsub('%s+', '')

    if value == '' or not NEXA_IDENTITY_CONFIG.allowedIdentifierTypes[identifierType] then
        return nil, nil
    end

    if value:find(':', 1, true) then
        local prefix, body = value:match('^([^:]+):(.+)$')

        if not prefix or not body or prefix:lower() ~= identifierType then
            return nil, nil
        end

        value = ('%s:%s'):format(identifierType, body)
    else
        value = ('%s:%s'):format(identifierType, value)
    end

    return identifierType, value
end

local function normalizeIdentifiers(session)
    local identifiers = {}

    if type(session) ~= 'table' then
        return identifiers
    end

    if session.license then
        local identifierType, value = normalizeIdentifier('license', session.license)

        if identifierType then
            identifiers[identifierType] = value
        end
    end

    for key, value in pairs(session.identifiers or {}) do
        local identifierType, normalized = normalizeIdentifier(key, value)

        if identifierType then
            identifiers[identifierType] = normalized
        end
    end

    return identifiers
end

local function getPrimaryLicense(identifiers)
    return identifiers.license or identifiers.license2
end

local function publicAccount(account)
    if type(account) ~= 'table' then
        return nil
    end

    return {
        id = tonumber(account.id),
        status = account.status,
        statusReason = account.status_reason,
        createdAt = account.created_at,
        lastLoginAt = account.last_login_at,
        lastLogoutAt = account.last_logout_at,
        updatedAt = account.updated_at,
        version = tonumber(account.version),
        metadata = decodeJson(account.metadata_json)
    }
end

local function cacheAccount(account, source)
    local public = publicAccount(account)

    if not public then
        return nil
    end

    NexaIdentity.accountsById[public.id] = public

    if source then
        NexaIdentity.accountIdBySource[source] = public.id
        NexaIdentity.sourceByAccountId[public.id] = source
    end

    return public
end

local function getInactiveStatusError(status)
    if status == NEXA_IDENTITY.statuses.banned then
        return NEXA_IDENTITY.errors.accountBanned
    end

    if status == NEXA_IDENTITY.statuses.suspended then
        return NEXA_IDENTITY.errors.accountSuspended
    end

    if status == NEXA_IDENTITY.statuses.disabled then
        return NEXA_IDENTITY.errors.accountDisabled
    end

    return nil
end

function NexaIdentity.GetAccountById(accountId)
    accountId = tonumber(accountId)

    if not accountId or accountId <= 0 then
        return nil, NEXA_IDENTITY.errors.invalidInput
    end

    if NexaIdentity.accountsById[accountId] then
        return NexaIdentity.accountsById[accountId], nil
    end

    local row, err = NexaIdentity.Database.GetAccountById(accountId)

    if err then
        return nil, err
    end

    if not row then
        return nil, NEXA_IDENTITY.errors.accountNotFound
    end

    return cacheAccount(row), nil
end

function NexaIdentity.GetAccountBySource(source)
    source = tonumber(source)

    if not source or source <= 0 then
        return nil, NEXA_IDENTITY.errors.invalidInput
    end

    local accountId = NexaIdentity.accountIdBySource[source]

    if not accountId then
        return nil, NEXA_IDENTITY.errors.accountNotReady
    end

    return NexaIdentity.GetAccountById(accountId)
end

function NexaIdentity.GetAccountIdentifiers(accountId)
    accountId = tonumber(accountId)

    if not accountId or accountId <= 0 then
        return nil, NEXA_IDENTITY.errors.invalidInput
    end

    local rows, err = NexaIdentity.Database.ListIdentifiers(accountId)

    if err then
        return nil, err
    end

    local identifiers = {}

    for _, row in ipairs(rows or {}) do
        identifiers[#identifiers + 1] = {
            id = row.id,
            accountId = row.account_id,
            type = row.identifier_type,
            value = row.identifier_value,
            maskedValue = maskIdentifier(row.identifier_value),
            firstSeenAt = row.first_seen_at,
            lastSeenAt = row.last_seen_at,
            verified = row.verified == 1 or row.verified == true,
            active = row.active == 1 or row.active == true
        }
    end

    return identifiers, nil
end

function NexaIdentity.IsAccountActive(accountId)
    local account, err = NexaIdentity.GetAccountById(accountId)

    if not account then
        return false, err
    end

    return account.status == NEXA_IDENTITY.statuses.active or account.status == NEXA_IDENTITY.statuses.pendingReview, nil
end

function NexaIdentity.RefreshIdentifiers(accountId, identifiers)
    accountId = tonumber(accountId)

    if not accountId or type(identifiers) ~= 'table' then
        return false, NEXA_IDENTITY.errors.invalidInput
    end

    for identifierType, identifierValue in pairs(identifiers) do
        local normalizedType, normalizedValue = normalizeIdentifier(identifierType, identifierValue)

        if normalizedType and normalizedValue then
            local ok, err = NexaIdentity.Database.UpsertIdentifier(accountId, normalizedType, normalizedValue, normalizedType == 'license' or normalizedType == 'license2')

            if not ok then
                return false, err
            end
        end
    end

    return true, nil
end

function NexaIdentity.EvaluateMultiAccount(accountId, identifiers, context)
    local signals = {}

    for identifierType, identifierValue in pairs(identifiers or {}) do
        local related, err = NexaIdentity.Database.FindOtherAccountsByIdentifier(accountId, identifierType, identifierValue)

        if err then
            return nil, err
        end

        for _, row in ipairs(related or {}) do
            local strength = 'medium'

            if identifierType == 'license' or identifierType == 'license2' or identifierType == 'discord' or identifierType == 'fivem' then
                strength = 'strong'
            end

            local signal = {
                signalType = ('duplicate_%s'):format(identifierType),
                strength = strength,
                relatedAccountId = tonumber(row.account_id),
                decision = strength == 'strong' and 'pending_review' or 'recorded',
                evidence = {
                    identifierType = identifierType,
                    identifier = maskIdentifier(identifierValue),
                    context = context
                },
                actor = NEXA_IDENTITY.resourceName
            }

            signals[#signals + 1] = signal
            NexaIdentity.Database.RecordReviewSignal(accountId, signal)
        end
    end

    return signals, nil
end

function NexaIdentity.MarkForReview(accountId, reason, evidence)
    local ok, err = NexaIdentity.Database.SetAccountStatus(accountId, NEXA_IDENTITY.statuses.pendingReview, reason, NEXA_IDENTITY.resourceName)

    if not ok then
        return response(false, err, 'Account konnte nicht zur Pruefung markiert werden.')
    end

    NexaIdentity.Invalidate(accountId)
    emitInternal(NEXA_IDENTITY.events.statusChanged, {
        accountId = accountId,
        status = NEXA_IDENTITY.statuses.pendingReview,
        reason = reason,
        evidence = evidence
    })

    return response(true, 'OK', 'Account zur Pruefung markiert.')
end

function NexaIdentity.ClearReview(accountId, actor, reason)
    local ok, err = NexaIdentity.Database.SetAccountStatus(accountId, NEXA_IDENTITY.statuses.active, reason, actor or NEXA_IDENTITY.resourceName)

    if not ok then
        return response(false, err, 'Account-Pruefung konnte nicht aufgehoben werden.')
    end

    NexaIdentity.Invalidate(accountId)
    emitInternal(NEXA_IDENTITY.events.statusChanged, {
        accountId = accountId,
        status = NEXA_IDENTITY.statuses.active,
        reason = reason
    })

    return response(true, 'OK', 'Account-Pruefung aufgehoben.')
end

function NexaIdentity.GetRiskSignals(accountId)
    local signals, err = NexaIdentity.Database.GetRiskSignals(accountId)

    if err then
        return response(false, err, 'Risikosignale konnten nicht geladen werden.')
    end

    return response(true, 'OK', 'Risikosignale geladen.', {
        signals = signals
    })
end

function NexaIdentity.SetAccountStatus(accountId, status, reason, actor)
    if not NEXA_IDENTITY_CONFIG.statuses[status] then
        return response(false, NEXA_IDENTITY.errors.invalidInput, 'Accountstatus ist ungueltig.')
    end

    local ok, err = NexaIdentity.Database.SetAccountStatus(accountId, status, reason, actor or NEXA_IDENTITY.resourceName)

    if not ok then
        return response(false, err, 'Accountstatus konnte nicht gesetzt werden.')
    end

    NexaIdentity.Invalidate(accountId)
    emitInternal(NEXA_IDENTITY.events.statusChanged, {
        accountId = accountId,
        status = status,
        reason = reason
    })

    return response(true, 'OK', 'Accountstatus gesetzt.')
end

function NexaIdentity.Invalidate(accountId)
    accountId = tonumber(accountId)

    if not accountId then
        NexaIdentity.accountsById = {}
        NexaIdentity.accountIdBySource = {}
        NexaIdentity.sourceByAccountId = {}
        return true
    end

    NexaIdentity.accountsById[accountId] = nil

    local source = NexaIdentity.sourceByAccountId[accountId]

    if source then
        NexaIdentity.accountIdBySource[source] = nil
        NexaIdentity.sourceByAccountId[accountId] = nil
    end

    return true
end

function NexaIdentity.ResolveAccount(session)
    if type(session) ~= 'table' then
        return response(false, NEXA_IDENTITY.errors.accountNotReady, 'Session ist nicht verfuegbar.')
    end

    local source = tonumber(session.source)
    local identifiers = normalizeIdentifiers(session)
    local license = getPrimaryLicense(identifiers)

    emitInternal(NEXA_IDENTITY.events.resolving, {
        source = source,
        sessionId = session.id
    })

    if not license then
        emitInternal(NEXA_IDENTITY.events.rejected, {
            source = source,
            reason = NEXA_IDENTITY.errors.identifierMissing
        })
        return response(false, NEXA_IDENTITY.errors.identifierMissing, 'Primaerer License-Identifier fehlt.')
    end

    local accountId, upsertErr = NexaIdentity.Database.UpsertAccount(license, {
        sessionId = session.id,
        source = source
    })

    if not accountId then
        return response(false, upsertErr or NEXA_IDENTITY.errors.resolutionFailed, 'Account konnte nicht aufgeloest werden.')
    end

    local refreshOk, refreshErr = NexaIdentity.RefreshIdentifiers(accountId, identifiers)

    if not refreshOk then
        return response(false, refreshErr or NEXA_IDENTITY.errors.resolutionFailed, 'Identifier konnten nicht aktualisiert werden.')
    end

    local accountRow, accountErr = NexaIdentity.Database.GetAccountById(accountId)

    if accountErr or not accountRow then
        return response(false, accountErr or NEXA_IDENTITY.errors.accountNotFound, 'Account konnte nicht geladen werden.')
    end

    local statusErr = getInactiveStatusError(accountRow.status)

    if statusErr then
        emitInternal(NEXA_IDENTITY.events.rejected, {
            source = source,
            accountId = accountId,
            reason = statusErr
        })

        if source and DropPlayer then
            DropPlayer(source, 'Nexa: Account ist nicht aktiv.')
        end

        return response(false, statusErr, 'Account ist nicht aktiv.')
    end

    local signals, signalErr = NexaIdentity.EvaluateMultiAccount(accountId, identifiers, {
        source = source,
        sessionId = session.id
    })

    if signalErr then
        log('Warn', 'identity.multi_account', 'Multi-Account-Pruefung konnte nicht abgeschlossen werden.', {
            accountId = accountId,
            error = signalErr
        })
    end

    local strongSignals = 0

    for _, signal in ipairs(signals or {}) do
        if signal.strength == 'strong' then
            strongSignals = strongSignals + 1
        end
    end

    if accountRow.status == NEXA_IDENTITY.statuses.active
        and NEXA_IDENTITY_CONFIG.review.markDuplicateStrongSignals
        and strongSignals >= NEXA_IDENTITY_CONFIG.review.strongSignalThreshold then
        NexaIdentity.MarkForReview(accountId, NEXA_IDENTITY.errors.multiAccountReviewRequired, {
            strongSignals = strongSignals
        })
        accountRow.status = NEXA_IDENTITY.statuses.pendingReview
    end

    local account = cacheAccount(accountRow, source)
    session.accountId = account.id
    session.identityReady = true

    emitInternal(NEXA_IDENTITY.events.ready, {
        source = source,
        accountId = account.id,
        status = account.status
    })

    return response(true, 'OK', 'Account aufgeloest.', {
        account = account,
        review = {
            signals = signals or {},
            strongSignals = strongSignals
        }
    })
end

local function resolveSource(source)
    local coreObject = getCore()

    if not coreObject or not coreObject.Sessions then
        return response(false, 'CORE_NOT_STARTED', 'Core ist nicht verfuegbar.')
    end

    local session = coreObject.Sessions.GetBySource(source)

    if not session then
        return response(false, NEXA_IDENTITY.errors.accountNotReady, 'Session ist nicht verfuegbar.')
    end

    return NexaIdentity.ResolveAccount(session)
end

local function onSessionCreated(payload)
    local session = payload and payload.session

    if session and session.source then
        local coreObject = getCore()

        if coreObject and coreObject.Sessions then
            session = coreObject.Sessions.GetBySource(session.source) or session
        end
    end

    if session then
        NexaIdentity.ResolveAccount(session)
    end
end

local function onSessionRemoved(payload)
    local session = payload and payload.session

    if not session then
        return
    end

    local accountId = NexaIdentity.accountIdBySource[tonumber(session.source)]

    if accountId then
        NexaIdentity.Database.MarkLogout(accountId)
        NexaIdentity.Invalidate(accountId)
    end
end

local function registerEventBus()
    local coreObject = getCore()

    if not coreObject or not coreObject.EventBus then
        return false
    end

    coreObject.EventBus.On('nexa:internal:session:created', onSessionCreated, {
        metadata = {
            resource = NEXA_IDENTITY.resourceName
        }
    })
    coreObject.EventBus.On('nexa:internal:session:removed', onSessionRemoved, {
        metadata = {
            resource = NEXA_IDENTITY.resourceName
        }
    })

    return true
end

function GetAccount(sourceOrAccountId)
    local numeric = tonumber(sourceOrAccountId)

    if numeric and NexaIdentity.accountIdBySource[numeric] then
        return NexaIdentity.GetAccountBySource(numeric)
    end

    return NexaIdentity.GetAccountById(numeric)
end

function GetAccountId(source)
    source = tonumber(source)

    if not source then
        return nil, NEXA_IDENTITY.errors.invalidInput
    end

    local accountId = NexaIdentity.accountIdBySource[source]

    if accountId then
        return accountId, nil
    end

    local resolved = resolveSource(source)

    if resolved.success and resolved.data and resolved.data.account then
        return resolved.data.account.id, nil
    end

    return nil, resolved.code
end

function GetAccountStatus(sourceOrAccountId)
    local account, err = GetAccount(sourceOrAccountId)

    if not account then
        return nil, err
    end

    return account.status, nil
end

function IsAccountReady(source)
    source = tonumber(source)

    if not source then
        return false
    end

    local accountId = NexaIdentity.accountIdBySource[source]

    if not accountId then
        return false
    end

    local active = NexaIdentity.IsAccountActive(accountId)
    return active == true
end

exports('GetAccount', GetAccount)
exports('GetAccountId', GetAccountId)
exports('GetAccountStatus', GetAccountStatus)
exports('IsAccountReady', IsAccountReady)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    local migrationsOk, migrationErr = NexaIdentity.Database.RegisterMigrations()

    if not migrationsOk then
        log('Error', 'identity.start', 'Identity-Migrationen fehlgeschlagen.', {
            error = migrationErr
        })
        return
    end

    registerEventBus()

    local coreObject = getCore()

    if coreObject and coreObject.Sessions then
        for _, playerSource in ipairs(GetPlayers()) do
            local session = coreObject.Sessions.GetBySource(tonumber(playerSource))

            if session then
                NexaIdentity.ResolveAccount(session)
            end
        end
    end

    log('Info', 'identity.start', 'nexa_identity gestartet.', {
        version = NEXA_IDENTITY.version
    })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for accountId in pairs(NexaIdentity.accountsById) do
        NexaIdentity.Database.MarkLogout(accountId)
    end

    NexaIdentity.Invalidate()
end)
