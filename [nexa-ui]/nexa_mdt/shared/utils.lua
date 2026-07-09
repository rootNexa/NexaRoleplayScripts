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

local function trim(value)
    if type(value) ~= 'string' then
        return ''
    end

    return value:match('^%s*(.-)%s*$') or ''
end

function NexaMdtCopyTable(value)
    return copyTable(value)
end

function NexaMdtTrim(value)
    return trim(value)
end

function NexaMdtLimitText(value, maxLength)
    local text = trim(value)
    local limit = tonumber(maxLength) or 0

    if limit > 0 and #text > limit then
        return text:sub(1, limit)
    end

    return text
end

function NexaMdtBuildResponse(success, code, message, data, meta)
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

function NexaMdtNormalizeType(mdtType)
    if type(mdtType) == 'string' and MDT_TYPES[mdtType] ~= nil then
        return mdtType
    end

    return NexaMdtConfig.defaultMdtType or MDT_TYPES.police
end

function NexaMdtGetModulesForType(mdtType)
    local normalizedType = NexaMdtNormalizeType(mdtType)
    local moduleIds = MDT_TYPE_MODULES[normalizedType] or {}
    local modules = {
        {
            id = 'overview',
            label = MDT_MODULE_LABELS.overview or 'Uebersicht'
        }
    }

    for _, moduleId in ipairs(moduleIds) do
        modules[#modules + 1] = {
            id = moduleId,
            label = MDT_MODULE_LABELS[moduleId] or moduleId
        }
    end

    return modules
end
