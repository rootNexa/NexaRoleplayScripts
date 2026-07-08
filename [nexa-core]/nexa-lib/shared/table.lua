NexaLib.Table = NexaLib.Table or {}

function NexaLib.Table.shallowCopy(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}

    for key, item in pairs(value) do
        copy[key] = item
    end

    return copy
end

function NexaLib.Table.deepCopy(value, seen)
    if type(value) ~= 'table' then
        return value
    end

    seen = seen or {}

    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy

    for key, item in pairs(value) do
        copy[NexaLib.Table.deepCopy(key, seen)] = NexaLib.Table.deepCopy(item, seen)
    end

    return copy
end

function NexaLib.Table.count(value)
    if type(value) ~= 'table' then
        return 0
    end

    local total = 0

    for _ in pairs(value) do
        total = total + 1
    end

    return total
end

function NexaLib.Table.contains(value, needle)
    if type(value) ~= 'table' then
        return false
    end

    for _, item in pairs(value) do
        if item == needle then
            return true
        end
    end

    return false
end

function NexaLib.Table.merge(base, overlay)
    local result = NexaLib.Table.shallowCopy(base or {})

    if type(overlay) ~= 'table' then
        return result
    end

    for key, value in pairs(overlay) do
        result[key] = value
    end

    return result
end
