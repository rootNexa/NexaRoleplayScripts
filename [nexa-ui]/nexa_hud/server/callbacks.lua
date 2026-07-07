local function buildResponse(success, code, message, data, meta)
    if GetResourceState('nexa_api') == 'started' then
        return exports.nexa_api:buildResponse(success, code, message, data, meta, nil)
    end

    return {
        success = success,
        code = code,
        message = message,
        data = data,
        meta = meta,
        audit_id = nil
    }
end

local function checkRequest(source)
    if GetResourceState('nexa_security') ~= 'started' then
        return true
    end

    if not exports.nexa_security:validateSource(source) then
        return false
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, NexaHudServerConfig.callbackRateLimit)

    return rateLimit ~= nil and rateLimit.success == true
end

local function firstValue(list)
    if type(list) ~= 'table' then
        return nil
    end

    return list[1]
end

local function getApiResult(exportName, source, payload)
    if GetResourceState('nexa_api') ~= 'started' then
        return nil
    end

    local ok, result = pcall(function()
        return exports.nexa_api[exportName](source, payload or {})
    end)

    if not ok or type(result) ~= 'table' or result.success ~= true then
        return nil
    end

    return result.data
end

local function getReadOnlySnapshot(source)
    local identityData = getApiResult('character.getActive', source)
    local accountData = getApiResult('account.list', source)
    local jobData = getApiResult('job.getCharacter', source, {})
    local businessData = getApiResult('business.list', source)

    local character = identityData and identityData.character or nil
    local accounts = accountData and accountData.accounts or {}
    local businesses = businessData and businessData.businesses or {}

    return {
        character = character,
        account = NexaHudFormatAccount(firstValue(accounts)),
        job = NexaHudFormatJob(jobData and jobData.job or nil),
        business = NexaHudFormatBusiness(firstValue(businesses))
    }
end

lib.callback.register(NexaHudConfig.snapshotCallback, function(source)
    if not checkRequest(source) then
        return buildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil)
    end

    return buildResponse(true, 'OK', 'HUD-Daten wurden geladen.', getReadOnlySnapshot(source), nil)
end)
