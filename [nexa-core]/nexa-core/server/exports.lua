local function debugSource(value)
    return {
        value = value,
        valueType = type(value),
        tonumberValue = tonumber(value)
    }
end

local function logExport(name, source, normalizedSource)
    Nexa.Log('info', 'Core export entry.', {
        export = name,
        source = debugSource(source),
        normalizedSource = normalizedSource
    })
end

function GetCoreObject()
    return Nexa
end

function GetPlayer(source)
    logExport('GetPlayer', source, tonumber(source))
    return Nexa.Players.GetPublic(source)
end

function GetCharacter(source)
    logExport('GetCharacter', source, tonumber(source))
    return Nexa.Characters.GetActive(source)
end

function ListCharacters(source)
    local rawSource = source
    source = tonumber(source)
    logExport('ListCharacters', rawSource, source)

    if not source or source <= 0 then
        return nil, 'INVALID_SOURCE'
    end

    return Nexa.Characters.List(source)
end

function HasPermission(source, permission)
    logExport('HasPermission', source, tonumber(source))
    return Nexa.Permissions.Has(source, permission)
end

function GetIdentifier(source)
    logExport('GetIdentifier', source, tonumber(source))
    return Nexa.Players.GetIdentifier(source)
end

function CreateCharacter(source, data)
    local rawSource = source
    source = tonumber(source)
    logExport('CreateCharacter', rawSource, source)

    if not source or source <= 0 then
        return nil, 'INVALID_SOURCE'
    end

    return Nexa.Characters.Create(source, data)
end

function SelectCharacter(source, characterId)
    local rawSource = source
    source = tonumber(source)
    characterId = tonumber(characterId)
    logExport('SelectCharacter', rawSource, source)

    if not source or source <= 0 or not characterId or characterId <= 0 then
        return nil, 'INVALID_INPUT'
    end

    return Nexa.Characters.Select(source, characterId)
end

function UpdateCharacter(source, data)
    local rawSource = source
    source = tonumber(source)
    logExport('UpdateCharacter', rawSource, source)

    if not source or source <= 0 or type(data) ~= 'table' then
        return nil, 'INVALID_INPUT'
    end

    return Nexa.Characters.Update(source, data)
end
