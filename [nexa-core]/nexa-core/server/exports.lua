function GetCoreObject()
    return Nexa
end

function GetPlayer(source)
    return Nexa.Players.GetPublic(source)
end

function GetCharacter(source)
    return Nexa.Characters.GetActive(source)
end

function ListCharacters(source)
    source = tonumber(source)

    if not source or source <= 0 then
        return nil, 'INVALID_SOURCE'
    end

    return Nexa.Characters.List(source)
end

function HasPermission(source, permission)
    return Nexa.Permissions.Has(source, permission)
end

function GetIdentifier(source)
    return Nexa.Players.GetIdentifier(source)
end

function CreateCharacter(source, data)
    source = tonumber(source)

    if not source or source <= 0 then
        return nil, 'INVALID_SOURCE'
    end

    return Nexa.Characters.Create(source, data)
end

function SelectCharacter(source, characterId)
    source = tonumber(source)
    characterId = tonumber(characterId)

    if not source or source <= 0 or not characterId or characterId <= 0 then
        return nil, 'INVALID_INPUT'
    end

    return Nexa.Characters.Select(source, characterId)
end

function UpdateCharacter(source, data)
    source = tonumber(source)

    if not source or source <= 0 or type(data) ~= 'table' then
        return nil, 'INVALID_INPUT'
    end

    return Nexa.Characters.Update(source, data)
end
