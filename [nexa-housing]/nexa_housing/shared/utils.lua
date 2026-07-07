local function trim(value)
    if type(value) ~= 'string' then
        return ''
    end

    return value:match('^%s*(.-)%s*$') or ''
end

function NexaHousingTrim(value)
    return trim(value)
end

function NexaHousingNormalizeId(value, maxValue)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    number = math.floor(number)

    if maxValue ~= nil and number > maxValue then
        return nil
    end

    return number
end

function NexaHousingBuildResponse(success, code, message, data, meta)
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
