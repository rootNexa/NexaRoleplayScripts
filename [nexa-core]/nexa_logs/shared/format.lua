local function encodeMetadata(metadata)
    if metadata == nil then
        return '{}'
    end

    if type(json) == 'table' and type(json.encode) == 'function' then
        return json.encode(metadata)
    end

    return tostring(metadata)
end

function NexaFormatLogEntry(entry)
    return ('[%s] [%s] [%s] %s %s'):format(
        entry.createdAt,
        string.upper(entry.level),
        entry.resourceName,
        entry.message,
        encodeMetadata(entry.metadata)
    )
end
