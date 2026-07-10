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
    local ready = Nexa.Lifecycle.RequireReady('export:GetPlayer')

    if not ready then
        return nil
    end

    logExport('GetPlayer', source, tonumber(source))
    return Nexa.Players.GetPublic(source)
end

function GetCharacter(source)
    local ready = Nexa.Lifecycle.RequireReady('export:GetCharacter')

    if not ready then
        return nil
    end

    logExport('GetCharacter', source, tonumber(source))
    return Nexa.Characters.GetActive(source)
end

function ListCharacters(source)
    local ready, readyErr = Nexa.Lifecycle.RequireReady('export:ListCharacters')

    if not ready then
        return nil, readyErr
    end

    local rawSource = source
    source = tonumber(source)
    logExport('ListCharacters', rawSource, source)

    if not source or source <= 0 then
        return nil, 'INVALID_SOURCE'
    end

    return Nexa.Characters.List(source)
end

function HasPermission(source, permission)
    local ready = Nexa.Lifecycle.RequireReady('export:HasPermission')

    if not ready then
        return false
    end

    logExport('HasPermission', source, tonumber(source))
    return Nexa.Permissions.Has(source, permission)
end

function GetIdentifier(source)
    local ready = Nexa.Lifecycle.RequireReady('export:GetIdentifier')

    if not ready then
        return nil
    end

    logExport('GetIdentifier', source, tonumber(source))
    return Nexa.Players.GetIdentifier(source)
end

function CreateCharacter(source, data)
    local ready, readyErr = Nexa.Lifecycle.RequireReady('export:CreateCharacter')

    if not ready then
        return nil, readyErr
    end

    local rawSource = source
    source = tonumber(source)
    logExport('CreateCharacter', rawSource, source)

    if not source or source <= 0 then
        return nil, 'INVALID_SOURCE'
    end

    return Nexa.Characters.Create(source, data)
end

function SelectCharacter(source, characterId)
    local ready, readyErr = Nexa.Lifecycle.RequireReady('export:SelectCharacter')

    if not ready then
        return nil, readyErr
    end

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
    local ready, readyErr = Nexa.Lifecycle.RequireReady('export:UpdateCharacter')

    if not ready then
        return nil, readyErr
    end

    local rawSource = source
    source = tonumber(source)
    logExport('UpdateCharacter', rawSource, source)

    if not source or source <= 0 or type(data) ~= 'table' then
        return nil, 'INVALID_INPUT'
    end

    return Nexa.Characters.Update(source, data)
end
