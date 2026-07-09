local function responseOk(data)
    return {
        ok = true,
        data = data,
        error = nil
    }
end

local function responseFail(code, message, details)
    return {
        ok = false,
        data = nil,
        error = {
            code = code,
            message = message,
            details = details
        }
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

local function getApi()
    if GetResourceState('nexa_api') ~= 'started' then
        return nil
    end

    local ok, api = pcall(function()
        return exports.nexa_api:GetApi()
    end)

    if not ok or type(api) ~= 'table' then
        return nil
    end

    return api
end

local function getCharacterSnapshot(api, source)
    if not api or type(api.GetCharacter) ~= 'function' then
        return nil
    end

    local ok, response = pcall(api.GetCharacter, source)

    if not ok or type(response) ~= 'table' or response.ok ~= true then
        return nil
    end

    return response.data
end

local function getReadOnlySnapshot(source)
    local api = getApi()

    return {
        character = getCharacterSnapshot(api, source),
        account = NexaHudFormatAccount({
            account_type = 'private',
            balance = 0,
            currency = 'USD'
        }),
        job = NexaHudFormatJob({}),
        business = NexaHudFormatBusiness({})
    }
end

exports.nexa_api:RegisterServerCallback(NexaHudConfig.snapshotCallback, function(source)
    if not checkRequest(source) then
        return responseFail('RATE_LIMITED', 'Bitte warte einen Moment.', nil)
    end

    return responseOk(getReadOnlySnapshot(source))
end)
