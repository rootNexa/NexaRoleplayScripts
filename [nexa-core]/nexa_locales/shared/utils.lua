local function readLocalePath(locale, path)
    if type(path) ~= 'string' or path == '' then
        return nil
    end

    local current = locale

    for segment in string.gmatch(path, '[^%.]+') do
        if type(current) ~= 'table' then
            return nil
        end

        current = current[segment]
    end

    return current
end

NexaLocalesUtils = {
    readPath = readLocalePath
}
