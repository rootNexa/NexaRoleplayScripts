local function trim(value)
    if type(value) ~= 'string' then
        return ''
    end

    return value:match('^%s*(.-)%s*$') or ''
end

function NexaVehicleDealerTrim(value)
    return trim(value)
end

function NexaVehicleDealerLimitText(value, maxLength)
    local text = trim(value)
    local limit = tonumber(maxLength) or 0

    if limit > 0 and #text > limit then
        return text:sub(1, limit)
    end

    return text
end

function NexaVehicleDealerBuildResponse(success, code, message, data, meta)
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
