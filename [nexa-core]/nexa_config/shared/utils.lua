local function isTable(value)
    return type(value) == 'table'
end

local function copyTable(value)
    if not isTable(value) then
        return value
    end

    local copy = {}

    for key, nestedValue in pairs(value) do
        copy[key] = copyTable(nestedValue)
    end

    return copy
end

local function readPath(source, path)
    if type(path) ~= 'string' or path == '' then
        return nil
    end

    local current = source

    for segment in string.gmatch(path, '[^%.]+') do
        if not isTable(current) then
            return nil
        end

        current = current[segment]
    end

    return copyTable(current)
end

NexaConfigUtils = {
    copyTable = copyTable,
    readPath = readPath
}
