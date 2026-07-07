local function copyTable(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}

    for key, item in pairs(value) do
        copy[key] = copyTable(item)
    end

    return copy
end

function NexaTabletCopyTable(value)
    return copyTable(value)
end

function NexaTabletBuildResponse(success, code, message, data, meta)
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
