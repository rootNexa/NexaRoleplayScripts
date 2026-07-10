local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

function getTheme()
    return copy(NexaThemeTokens)
end

function getPublicTheme()
    return getTheme()
end

exports('getTheme', getTheme)
exports('getPublicTheme', getPublicTheme)
