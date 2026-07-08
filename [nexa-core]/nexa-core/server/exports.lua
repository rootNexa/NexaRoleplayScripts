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
    return Nexa.Characters.List(source)
end

function HasPermission(source, permission)
    return Nexa.Permissions.Has(source, permission)
end

function GetIdentifier(source)
    return Nexa.Players.GetIdentifier(source)
end

function CreateCharacter(source, data)
    return Nexa.Characters.Create(source, data)
end

function SelectCharacter(source, characterId)
    return Nexa.Characters.Select(source, characterId)
end

function UpdateCharacter(source, data)
    return Nexa.Characters.Update(source, data)
end
