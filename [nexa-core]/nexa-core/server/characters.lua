Nexa.Characters = {
    activeBySource = {}
}

local function trim(value)
    if type(value) ~= 'string' then
        return nil
    end

    return value:match('^%s*(.-)%s*$')
end

local function validateName(value)
    value = trim(value)

    if not value or #value < Nexa.Config.character.minNameLength or #value > Nexa.Config.character.maxNameLength then
        return nil
    end

    if not value:match("^[%a%s%-']+$") then
        return nil
    end

    return value
end

local function validateDate(value)
    value = trim(value)

    if not value or not value:match('^%d%d%d%d%-%d%d%-%d%d$') then
        return nil
    end

    local year = tonumber(value:sub(1, 4))

    if not year or year < Nexa.Config.character.minBirthYear or year > Nexa.Config.character.maxBirthYear then
        return nil
    end

    return value
end

local function decodeJson(value, fallback)
    if type(value) ~= 'string' or value == '' then
        return fallback
    end

    local ok, result = pcall(json.decode, value)
    return ok and result or fallback
end

local function mapCharacter(row)
    if not row then
        return nil
    end

    return {
        id = row.id,
        playerId = row.player_id,
        firstName = row.first_name,
        lastName = row.last_name,
        birthdate = row.birthdate,
        gender = row.gender,
        metadata = decodeJson(row.metadata, {}),
        createdAt = row.created_at,
        updatedAt = row.updated_at
    }
end

local function validateCharacterPayload(data)
    if type(data) ~= 'table' then
        return nil, 'INVALID_INPUT'
    end

    local firstName = validateName(data.firstName or data.first_name)
    local lastName = validateName(data.lastName or data.last_name)
    local birthdate = validateDate(data.birthdate)
    local gender = trim(data.gender or 'unknown') or 'unknown'

    if not firstName or not lastName or not birthdate then
        return nil, 'INVALID_INPUT'
    end

    if gender ~= 'male' and gender ~= 'female' and gender ~= 'diverse' and gender ~= 'unknown' then
        return nil, 'INVALID_INPUT'
    end

    return {
        firstName = firstName,
        lastName = lastName,
        birthdate = birthdate,
        gender = gender,
        metadata = type(data.metadata) == 'table' and data.metadata or {}
    }, nil
end

local function validateCharacterUpdatePayload(data)
    if type(data) ~= 'table' then
        return nil, 'INVALID_INPUT'
    end

    local payload = {}
    local hasChanges = false

    if data.firstName ~= nil or data.first_name ~= nil then
        local firstName = validateName(data.firstName or data.first_name)

        if not firstName then
            return nil, 'INVALID_INPUT'
        end

        payload.firstName = firstName
        hasChanges = true
    end

    if data.lastName ~= nil or data.last_name ~= nil then
        local lastName = validateName(data.lastName or data.last_name)

        if not lastName then
            return nil, 'INVALID_INPUT'
        end

        payload.lastName = lastName
        hasChanges = true
    end

    if data.birthdate ~= nil then
        local birthdate = validateDate(data.birthdate)

        if not birthdate then
            return nil, 'INVALID_INPUT'
        end

        payload.birthdate = birthdate
        hasChanges = true
    end

    if data.gender ~= nil then
        local gender = trim(data.gender or 'unknown') or 'unknown'

        if gender ~= 'male' and gender ~= 'female' and gender ~= 'diverse' and gender ~= 'unknown' then
            return nil, 'INVALID_INPUT'
        end

        payload.gender = gender
        hasChanges = true
    end

    if data.metadata ~= nil then
        if type(data.metadata) ~= 'table' then
            return nil, 'INVALID_INPUT'
        end

        payload.metadata = data.metadata
        hasChanges = true
    end

    if not hasChanges then
        return nil, 'INVALID_INPUT'
    end

    return payload, nil
end

function Nexa.Characters.GetActive(source)
    return Nexa.Characters.activeBySource[tonumber(source)]
end

function Nexa.Characters.List(source)
    source = tonumber(source)
    local player = Nexa.Players.Get(source)

    if not player then
        return nil, 'PLAYER_NOT_FOUND'
    end

    local rows, err = Nexa.Database.FetchAll([[
        SELECT id, player_id, first_name, last_name, birthdate, gender, metadata, created_at, updated_at
        FROM nexa_characters
        WHERE player_id = ? AND deleted_at IS NULL
        ORDER BY id ASC
    ]], { player.id })

    if err then
        return nil, 'DATABASE_ERROR'
    end

    local characters = {}

    for _, row in ipairs(rows or {}) do
        characters[#characters + 1] = mapCharacter(row)
    end

    return characters, nil
end

function Nexa.Characters.Create(source, data)
    source = tonumber(source)
    local player = Nexa.Players.Get(source)

    if not player then
        return nil, 'PLAYER_NOT_FOUND'
    end

    local characters, listError = Nexa.Characters.List(source)

    if listError then
        return nil, listError
    end

    if characters and #characters >= Nexa.Config.character.maxPerPlayer then
        return nil, 'CHARACTER_LIMIT_REACHED'
    end

    local payload, validationError = validateCharacterPayload(data)

    if not payload then
        return nil, validationError
    end

    local metadata = json.encode(payload.metadata)
    local characterId, err = Nexa.Database.Insert([[
        INSERT INTO nexa_characters (player_id, first_name, last_name, birthdate, gender, metadata)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        player.id,
        payload.firstName,
        payload.lastName,
        payload.birthdate,
        payload.gender,
        metadata
    })

    if err then
        return nil, 'DATABASE_ERROR'
    end

    Nexa.Audit('character.created', source, {
        player_id = player.id,
        character_id = characterId
    })

    return Nexa.Characters.GetByIdForPlayer(player.id, characterId), nil
end

function Nexa.Characters.GetByIdForPlayer(playerId, characterId)
    if type(playerId) ~= 'number' or type(characterId) ~= 'number' then
        return nil
    end

    local row = Nexa.Database.FetchOne([[
        SELECT id, player_id, first_name, last_name, birthdate, gender, metadata, created_at, updated_at
        FROM nexa_characters
        WHERE id = ? AND player_id = ? AND deleted_at IS NULL
        LIMIT 1
    ]], { characterId, playerId })

    return mapCharacter(row)
end

function Nexa.Characters.Select(source, characterId)
    source = tonumber(source)
    local player = Nexa.Players.Get(source)
    characterId = tonumber(characterId)

    if not player or not characterId then
        return nil, 'INVALID_INPUT'
    end

    local character = Nexa.Characters.GetByIdForPlayer(player.id, characterId)

    if not character then
        Nexa.Audit('security.character_select_denied', source, {
            player_id = player.id,
            requested_character_id = characterId
        })
        return nil, 'NOT_FOUND'
    end

    player.activeCharacterId = character.id
    Nexa.Characters.activeBySource[source] = character

    Nexa.Audit('character.selected', source, {
        player_id = player.id,
        character_id = character.id
    })

    TriggerClientEvent(Nexa.Constants.events.characterSelected, source, character)
    return character, nil
end

function Nexa.Characters.Update(source, data)
    source = tonumber(source)

    if type(data) ~= 'table' then
        return nil, 'INVALID_INPUT'
    end

    local player = Nexa.Players.Get(source)
    local characterId = tonumber(data.characterId or data.character_id or data.id)

    if not player or not characterId then
        return nil, 'INVALID_INPUT'
    end

    local existing = Nexa.Characters.GetByIdForPlayer(player.id, characterId)

    if not existing then
        Nexa.Audit('security.character_update_denied', source, {
            player_id = player.id,
            requested_character_id = characterId
        })
        return nil, 'NOT_FOUND'
    end

    local payload, validationError = validateCharacterUpdatePayload(data)

    if not payload then
        return nil, validationError
    end

    local firstName = payload.firstName or existing.firstName
    local lastName = payload.lastName or existing.lastName
    local birthdate = payload.birthdate or existing.birthdate
    local gender = payload.gender or existing.gender
    local metadata = payload.metadata ~= nil and payload.metadata or existing.metadata

    local affected, err = Nexa.Database.Update([[
        UPDATE nexa_characters
        SET first_name = ?, last_name = ?, birthdate = ?, gender = ?, metadata = ?
        WHERE id = ? AND player_id = ? AND deleted_at IS NULL
    ]], {
        firstName,
        lastName,
        birthdate,
        gender,
        json.encode(metadata or {}),
        characterId,
        player.id
    })

    if err then
        return nil, 'DATABASE_ERROR'
    end

    if not affected or affected <= 0 then
        return nil, 'NOT_FOUND'
    end

    local character = Nexa.Characters.GetByIdForPlayer(player.id, characterId)

    if Nexa.Characters.activeBySource[source] and Nexa.Characters.activeBySource[source].id == characterId then
        Nexa.Characters.activeBySource[source] = character
        TriggerClientEvent(Nexa.Constants.events.characterSelected, source, character)
    end

    Nexa.Audit('character.updated', source, {
        player_id = player.id,
        character_id = characterId
    })

    return character, nil
end

function Nexa.Characters.Unload(source)
    source = tonumber(source)

    if Nexa.Characters.activeBySource[source] then
        TriggerClientEvent(Nexa.Constants.events.characterUnloaded, source)
    end

    Nexa.Characters.activeBySource[source] = nil
end
