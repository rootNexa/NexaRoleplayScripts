local function trim(value)
    if type(value) ~= 'string' then
        return nil
    end

    return value:gsub('^%s+', ''):gsub('%s+$', '')
end

function NexaAdminNormalizeReason(value, required)
    local reason = trim(value)

    if reason == nil or reason == '' then
        return required == true and nil or nil
    end

    reason = reason:gsub('[<>]', '')

    if #reason > NexaAdminConfig.maxReasonLength then
        reason = reason:sub(1, NexaAdminConfig.maxReasonLength)
    end

    return reason
end

function NexaAdminNormalizeText(value, maxLength, required)
    local text = trim(value)

    if text == nil or text == '' then
        return required == true and nil or nil
    end

    text = text:gsub('[<>]', '')
    maxLength = tonumber(maxLength) or 512

    if #text > maxLength then
        text = text:sub(1, maxLength)
    end

    return text
end

function NexaAdminNormalizeSource(value)
    local source = tonumber(value)
    return source and source > 0 and math.floor(source) or nil
end

function NexaAdminNormalizeId(value)
    local id = tonumber(value)
    return id and id > 0 and math.floor(id) or nil
end

function NexaAdminNormalizeDurationMinutes(value)
    local duration = tonumber(value)

    if not duration then
        return nil
    end

    duration = math.floor(duration)

    if duration <= 0 or duration > NexaAdminConfig.maxTempBanMinutes then
        return nil
    end

    return duration
end

function NexaAdminNormalizeCoords(payload)
    if type(payload) ~= 'table' then
        return nil
    end

    local x = tonumber(payload.x)
    local y = tonumber(payload.y)
    local z = tonumber(payload.z)
    local heading = tonumber(payload.heading or 0.0)
    local max = NexaAdminConfig.maxCoordinate

    if not x or not y or not z or not heading then
        return nil
    end

    if math.abs(x) > max or math.abs(y) > max or math.abs(z) > max then
        return nil
    end

    return {
        x = x,
        y = y,
        z = z,
        heading = heading
    }
end

function NexaAdminIsValidVisibility(value)
    return value == 'support' or value == 'admin' or value == 'senior_admin' or value == 'head_admin' or value == 'owner'
end
