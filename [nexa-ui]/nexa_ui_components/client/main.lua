local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

function getComponents()
    return copy(NexaUiComponents)
end

function getStylesheet()
    return NexaUiComponents.stylesheet
end

exports('getComponents', getComponents)
exports('getStylesheet', getStylesheet)
