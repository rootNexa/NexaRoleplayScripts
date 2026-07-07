local activeCharacters = {}

local characterLimits = {
    maxCharactersPerPlayer = 3,
    minNameLength = 2,
    maxNameLength = 32,
    minAge = 18,
    maxAge = 90
}

local allowedGenders = {
    male = true,
    female = true,
    diverse = true
}

local function respond(success, code, message, data, meta, auditId)
    return NexaApiResponse(success, code, message, data, meta, auditId)
end

local function logApi(level, message, metadata)
    if GetResourceState('nexa_logs') ~= 'started' then
        return
    end

    exports.nexa_logs[level](NEXA_API.resourceName, message, metadata)
end

local function debugLog(message, metadata)
    if GetConvar('nexa:identityDebug', 'false') ~= 'true' then
        return
    end

    print(('[nexa_api:character] %s %s'):format(message, metadata and json.encode(metadata) or ''))
end

local function writeCharacterAudit(action, source, playerId, characterId, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'character',
        severity = 'info',
        actorPlayerId = playerId,
        actorCharacterId = characterId,
        targetType = 'character',
        targetId = characterId,
        action = action,
        resourceName = NEXA_API.resourceName,
        metadata = metadata or {
            source = source
        }
    })

    return result and result.audit_id or nil
end

local function validateSourceValue(source)
    local sourceNumber = tonumber(source)

    if sourceNumber == nil or sourceNumber <= 0 then
        return false
    end

    return true
end

local function getIdentifierType(identifier)
    local separator = identifier:find(':', 1, true)

    if separator == nil then
        return 'unknown'
    end

    return identifier:sub(1, separator - 1)
end

local function getSourceIdentifiers(source)
    local identifiers = {}
    local count = GetNumPlayerIdentifiers(source)

    for index = 0, count - 1 do
        local identifier = GetPlayerIdentifier(source, index)

        if type(identifier) == 'string' and identifier ~= '' then
            identifiers[#identifiers + 1] = identifier
        end
    end

    return identifiers
end

local function getPrimaryIdentifier(source)
    local license = GetPlayerIdentifierByType(source, 'license')

    if type(license) == 'string' and license ~= '' then
        return license
    end

    local identifiers = getSourceIdentifiers(source)
    return identifiers[1]
end

local function getPlayerByIdentifiers(identifiers)
    if #identifiers == 0 then
        return nil
    end

    local placeholders = {}
    local params = {}

    for index, identifier in ipairs(identifiers) do
        placeholders[index] = '?'
        params[index] = identifier
    end

    return MySQL.single.await(([[
        SELECT p.id, p.primary_identifier, p.display_name, p.is_banned
        FROM players p
        INNER JOIN player_identifiers pi ON pi.player_id = p.id
        WHERE pi.value IN (%s)
        LIMIT 1
    ]]):format(table.concat(placeholders, ',')), params)
end

local function syncPlayerIdentifiers(playerId, identifiers)
    for _, identifier in ipairs(identifiers) do
        MySQL.insert.await([[
            INSERT INTO player_identifiers (player_id, type, value, first_seen_at, last_seen_at)
            VALUES (?, ?, ?, NOW(), NOW())
            ON DUPLICATE KEY UPDATE player_id = VALUES(player_id), last_seen_at = NOW()
        ]], {
            playerId,
            getIdentifierType(identifier),
            identifier
        })
    end
end

local function resolvePlayer(source, createIfMissing)
    if not validateSourceValue(source) then
        return nil, 'INVALID_INPUT'
    end

    local identifiers = getSourceIdentifiers(source)
    local primaryIdentifier = getPrimaryIdentifier(source)

    if primaryIdentifier == nil or #identifiers == 0 then
        return nil, 'INVALID_INPUT'
    end

    local player = getPlayerByIdentifiers(identifiers)

    if player == nil and createIfMissing then
        local displayName = GetPlayerName(source)
        local playerId = MySQL.insert.await([[
            INSERT INTO players (primary_identifier, display_name, first_joined_at, last_seen_at, created_at, updated_at)
            VALUES (?, ?, NOW(), NOW(), NOW(), NOW())
        ]], {
            primaryIdentifier,
            displayName
        })

        player = {
            id = playerId,
            primary_identifier = primaryIdentifier,
            display_name = displayName,
            is_banned = 0
        }
    elseif player ~= nil then
        MySQL.update.await('UPDATE players SET display_name = ?, last_seen_at = NOW(), updated_at = NOW() WHERE id = ?', {
            GetPlayerName(source),
            player.id
        })
    end

    if player == nil then
        return nil, 'NOT_FOUND'
    end

    syncPlayerIdentifiers(player.id, identifiers)

    return player, 'OK'
end

local function normalizeText(value)
    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' then
        return nil
    end

    return trimmed
end

local function validationError(field, reason, expected, value)
    return {
        field = field,
        reason = reason,
        expected = expected,
        value = value,
        valueType = type(value)
    }
end

local function isNameValid(field, value)
    local normalized = normalizeText(value)

    if normalized == nil then
        return false, nil, validationError(field, 'missing_or_blank', ('string length %d-%d matching letters/spaces/hyphen/apostrophe'):format(characterLimits.minNameLength, characterLimits.maxNameLength), value)
    end

    if #normalized < characterLimits.minNameLength or #normalized > characterLimits.maxNameLength then
        return false, nil, validationError(field, 'length', ('%d-%d characters'):format(characterLimits.minNameLength, characterLimits.maxNameLength), value)
    end

    if normalized:find('[^%a%s%-\']') ~= nil then
        return false, nil, validationError(field, 'pattern', "letters/spaces/hyphen/apostrophe only", value)
    end

    return true, normalized
end

local function isBirthdateValid(value)
    if type(value) ~= 'string' then
        return false, validationError('birthdate', 'type', 'YYYY-MM-DD string', value)
    end

    if not value:match('^%d%d%d%d%-%d%d%-%d%d$') then
        return false, validationError('birthdate', 'format', 'YYYY-MM-DD', value)
    end

    local year = tonumber(value:sub(1, 4))
    local month = tonumber(value:sub(6, 7))
    local day = tonumber(value:sub(9, 10))

    if year == nil or month == nil or day == nil or month < 1 or month > 12 or day < 1 or day > 31 then
        return false, validationError('birthdate', 'calendar_date', 'valid calendar date YYYY-MM-DD', value)
    end

    local currentYear = tonumber(os.date('%Y'))
    local age = currentYear - year

    if age < characterLimits.minAge or age > characterLimits.maxAge then
        return false, validationError('birthdate', 'age_range', ('age %d-%d'):format(characterLimits.minAge, characterLimits.maxAge), value)
    end

    return true, nil
end

local function validateCreatePayload(payload)
    if type(payload) ~= 'table' then
        return nil, 'INVALID_INPUT', validationError('payload', 'type', 'table', payload)
    end

    local firstValid, firstname, firstError = isNameValid('firstname', payload.firstname)
    local lastValid, lastname, lastError = isNameValid('lastname', payload.lastname)

    if not firstValid then
        return nil, 'INVALID_INPUT', firstError
    end

    if not lastValid then
        return nil, 'INVALID_INPUT', lastError
    end

    local birthdateValid, birthdateError = isBirthdateValid(payload.birthdate)

    if not birthdateValid then
        return nil, 'INVALID_INPUT', birthdateError
    end

    local gender = normalizeText(payload.gender)

    if gender == nil then
        return nil, 'INVALID_INPUT', validationError('gender', 'missing_or_blank', 'male, female, or diverse', payload.gender)
    end

    gender = gender:lower()

    if not allowedGenders[gender] then
        return nil, 'INVALID_INPUT', validationError('gender', 'enum', 'male, female, or diverse', payload.gender)
    end

    local nationality = normalizeText(payload.nationality or 'San Andreas')

    if nationality ~= nil and #nationality > 64 then
        return nil, 'INVALID_INPUT', validationError('nationality', 'max_length', '64 characters or fewer', payload.nationality)
    end

    return {
        firstname = firstname,
        lastname = lastname,
        birthdate = payload.birthdate,
        gender = gender,
        nationality = nationality
    }, 'OK'
end

local function buildCitizenId()
    return ('NX%s%04d'):format(os.date('%y%m%d%H%M%S'), math.random(0, 9999))
end

local function generateCitizenId()
    for _ = 1, 10 do
        local citizenId = buildCitizenId()
        local existing = MySQL.scalar.await('SELECT id FROM characters WHERE citizenid = ? LIMIT 1', {
            citizenId
        })

        if existing == nil then
            return citizenId
        end
    end

    return nil
end

local function mapCharacter(row)
    if row == nil then
        return nil
    end

    return {
        id = row.id,
        player_id = row.player_id,
        citizenid = row.citizenid,
        firstname = row.firstname,
        lastname = row.lastname,
        birthdate = row.birthdate,
        gender = row.gender,
        nationality = row.nationality,
        phone_number = row.phone_number,
        is_active = row.is_active == true or row.is_active == 1,
        created_at = row.created_at,
        updated_at = row.updated_at,
        deleted_at = row.deleted_at
    }
end

local function getCharacterForPlayer(playerId, characterId)
    return mapCharacter(MySQL.single.await([[
        SELECT id, player_id, citizenid, firstname, lastname, birthdate, gender, nationality,
            phone_number, is_active, created_at, updated_at, deleted_at
        FROM characters
        WHERE id = ? AND player_id = ? AND is_active = TRUE AND deleted_at IS NULL
        LIMIT 1
    ]], {
        characterId,
        playerId
    }))
end

local function getSpawnPayload(characterId)
    local defaultSpawn = {
        type = 'default',
        coords = {
            x = -1037.61,
            y = -2737.61,
            z = 20.17,
            heading = 330.0
        }
    }

    local metadata = MySQL.single.await([[
        SELECT meta_value
        FROM character_metadata
        WHERE character_id = ? AND meta_key = 'spawn'
        LIMIT 1
    ]], {
        characterId
    })

    if metadata == nil or metadata.meta_value == nil then
        return defaultSpawn
    end

    local decoded = json.decode(metadata.meta_value)

    if type(decoded) ~= 'table' or type(decoded.coords) ~= 'table' then
        return defaultSpawn
    end

    local coords = decoded.coords

    if tonumber(coords.x) == nil or tonumber(coords.y) == nil or tonumber(coords.z) == nil then
        return defaultSpawn
    end

    return {
        type = decoded.type or 'stored',
        coords = {
            x = tonumber(coords.x),
            y = tonumber(coords.y),
            z = tonumber(coords.z),
            heading = tonumber(coords.heading) or defaultSpawn.coords.heading
        }
    }
end

function listCharacters(source)
    local player, code = resolvePlayer(source, true)

    if player == nil then
        return respond(false, code, 'Spieler konnte nicht aufgeloest werden.', nil, nil, nil)
    end

    local rows = MySQL.query.await([[
        SELECT id, player_id, citizenid, firstname, lastname, birthdate, gender, nationality,
            phone_number, is_active, created_at, updated_at, deleted_at
        FROM characters
        WHERE player_id = ? AND is_active = TRUE AND deleted_at IS NULL
        ORDER BY created_at ASC
    ]], {
        player.id
    })

    local characters = {}

    for _, row in ipairs(rows or {}) do
        characters[#characters + 1] = mapCharacter(row)
    end

    return respond(true, 'OK', 'Charaktere wurden geladen.', {
        characters = characters
    }, {
        maxCharacters = characterLimits.maxCharactersPerPlayer
    }, nil)
end

function createCharacter(source, payload)
    local player, playerCode = resolvePlayer(source, true)

    if player == nil then
        return respond(false, playerCode, 'Spieler konnte nicht aufgeloest werden.', nil, nil, nil)
    end

    local data, code, validation = validateCreatePayload(payload)

    if data == nil then
        debugLog('INVALID_INPUT createCharacter validation failed', {
            source = source,
            validation = validation,
            payload = payload
        })
        return respond(false, code, 'Ungueltige Charakterdaten.', nil, nil, nil)
    end

    local characterCount = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM characters
        WHERE player_id = ? AND is_active = TRUE AND deleted_at IS NULL
    ]], {
        player.id
    })

    if tonumber(characterCount) >= characterLimits.maxCharactersPerPlayer then
        return respond(false, 'CONFLICT', 'Maximale Charakteranzahl erreicht.', nil, nil, nil)
    end

    local citizenId = generateCitizenId()

    if citizenId == nil then
        return respond(false, 'CONFLICT', 'Charakter-ID konnte nicht erzeugt werden.', nil, nil, nil)
    end

    local success, result = pcall(function()
        return MySQL.transaction.await({
            {
                query = [[
                    INSERT INTO characters (player_id, citizenid, firstname, lastname, birthdate, gender, nationality, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
                ]],
                values = {
                    player.id,
                    citizenId,
                    data.firstname,
                    data.lastname,
                    data.birthdate,
                    data.gender,
                    data.nationality
                }
            },
            {
                query = [[
                    INSERT INTO character_status (character_id, health, armor, hunger, thirst, stress, is_dead, last_updated_at)
                    SELECT id, 200, 0, 100, 100, 0, FALSE, NOW()
                    FROM characters
                    WHERE citizenid = ?
                    LIMIT 1
                ]],
                values = {
                    citizenId
                }
            }
        })
    end)

    if not success or result == false then
        logApi('error', 'Charakter konnte nicht erstellt werden.', {
            source = source,
            error = result
        })

        return respond(false, 'DATABASE_ERROR', 'Charakter konnte nicht erstellt werden.', nil, nil, nil)
    end

    local character = mapCharacter(MySQL.single.await([[
        SELECT id, player_id, citizenid, firstname, lastname, birthdate, gender, nationality,
            phone_number, is_active, created_at, updated_at, deleted_at
        FROM characters
        WHERE citizenid = ?
        LIMIT 1
    ]], {
        citizenId
    }))

    local auditId = writeCharacterAudit('character.create', source, player.id, character and character.id or nil, {
        source = source,
        citizenid = citizenId
    })

    logApi('info', 'Charakter wurde erstellt.', {
        source = source,
        characterId = character and character.id or nil,
        citizenid = citizenId
    })

    TriggerEvent('nexa:character:internal:created', source, character)

    return respond(true, 'CREATED', 'Charakter wurde erstellt.', {
        character = character
    }, nil, auditId)
end

function selectCharacter(source, characterId)
    local player, playerCode = resolvePlayer(source, true)

    if player == nil then
        return respond(false, playerCode, 'Spieler konnte nicht aufgeloest werden.', nil, nil, nil)
    end

    local normalizedCharacterId = tonumber(characterId)

    if normalizedCharacterId == nil or normalizedCharacterId <= 0 then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Charakter.', nil, nil, nil)
    end

    local character = getCharacterForPlayer(player.id, normalizedCharacterId)

    if character == nil then
        return respond(false, 'NOT_FOUND', 'Charakter wurde nicht gefunden.', nil, nil, nil)
    end

    activeCharacters[source] = character

    local spawn = getSpawnPayload(character.id)
    local auditId = writeCharacterAudit('character.select', source, player.id, character.id, {
        source = source,
        citizenid = character.citizenid
    })

    logApi('info', 'Charakter wurde ausgewaehlt.', {
        source = source,
        characterId = character.id,
        citizenid = character.citizenid
    })

    local payload = {
        character = character,
        spawn = spawn
    }

    TriggerEvent('nexa:character:internal:selected', source, payload)
    if type(allowGodmodeException) == 'function' then
        pcall(allowGodmodeException, source, 'spawn_protection', {
            action = 'character.select',
            characterId = character.id,
            auditId = auditId
        })
    end
    TriggerClientEvent('nexa:identity:client:spawnPrepared', source, payload)

    return respond(true, 'OK', 'Charakter wurde ausgewaehlt.', payload, nil, auditId)
end

function deleteCharacter(source, characterId)
    local player, playerCode = resolvePlayer(source, true)

    if player == nil then
        return respond(false, playerCode, 'Spieler konnte nicht aufgeloest werden.', nil, nil, nil)
    end

    local normalizedCharacterId = tonumber(characterId)

    if normalizedCharacterId == nil or normalizedCharacterId <= 0 then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Charakter.', nil, nil, nil)
    end

    local character = getCharacterForPlayer(player.id, normalizedCharacterId)

    if character == nil then
        return respond(false, 'NOT_FOUND', 'Charakter wurde nicht gefunden.', nil, nil, nil)
    end

    local updated = MySQL.update.await([[
        UPDATE characters
        SET is_active = FALSE, deleted_at = NOW(), updated_at = NOW()
        WHERE id = ? AND player_id = ? AND is_active = TRUE
    ]], {
        character.id,
        player.id
    })

    if updated == nil or updated < 1 then
        return respond(false, 'DATABASE_ERROR', 'Charakter konnte nicht geloescht werden.', nil, nil, nil)
    end

    if activeCharacters[source] ~= nil and activeCharacters[source].id == character.id then
        activeCharacters[source] = nil
    end

    local auditId = writeCharacterAudit('character.delete', source, player.id, character.id, {
        source = source,
        citizenid = character.citizenid
    })

    logApi('info', 'Charakter wurde deaktiviert.', {
        source = source,
        characterId = character.id,
        citizenid = character.citizenid
    })

    TriggerEvent('nexa:character:internal:deleted', source, character)

    return respond(true, 'UPDATED', 'Charakter wurde deaktiviert.', {
        character = character
    }, nil, auditId)
end

function getActiveCharacter(source)
    local character = activeCharacters[source]

    if character == nil then
        return respond(false, 'CHARACTER_NOT_LOADED', 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    return respond(true, 'OK', 'Aktiver Charakter wurde geladen.', {
        character = character
    }, nil, nil)
end

function getIdentity(characterId)
    local normalizedCharacterId = tonumber(characterId)

    if normalizedCharacterId == nil or normalizedCharacterId <= 0 then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Charakter.', nil, nil, nil)
    end

    local character = mapCharacter(MySQL.single.await([[
        SELECT id, player_id, citizenid, firstname, lastname, birthdate, gender, nationality,
            phone_number, is_active, created_at, updated_at, deleted_at
        FROM characters
        WHERE id = ? AND is_active = TRUE AND deleted_at IS NULL
        LIMIT 1
    ]], {
        normalizedCharacterId
    }))

    if character == nil then
        return respond(false, 'NOT_FOUND', 'Identitaet wurde nicht gefunden.', nil, nil, nil)
    end

    local phone = MySQL.single.await([[
        SELECT number
        FROM phone_numbers
        WHERE character_id = ? AND is_active = TRUE
        ORDER BY created_at DESC
        LIMIT 1
    ]], {
        normalizedCharacterId
    })

    character.phone_number = character.phone_number or (phone and phone.number or nil)

    return respond(true, 'OK', 'Identitaet wurde geladen.', {
        identity = character
    }, nil, nil)
end

function validateCitizenId(citizenId)
    if type(citizenId) ~= 'string' or #citizenId < 6 or #citizenId > 64 then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Charakter-ID.', nil, nil, nil)
    end

    local characterId = MySQL.scalar.await('SELECT id FROM characters WHERE citizenid = ? AND is_active = TRUE AND deleted_at IS NULL LIMIT 1', {
        citizenId
    })

    if characterId == nil then
        return respond(false, 'NOT_FOUND', 'Charakter-ID wurde nicht gefunden.', nil, nil, nil)
    end

    return respond(true, 'OK', 'Charakter-ID ist gueltig.', {
        characterId = characterId
    }, nil, nil)
end

AddEventHandler('playerDropped', function()
    activeCharacters[source] = nil
end)

math.randomseed(os.time())

exports('listCharacters', listCharacters)
exports('character.list', listCharacters)
exports('createCharacter', createCharacter)
exports('character.create', createCharacter)
exports('selectCharacter', selectCharacter)
exports('character.select', selectCharacter)
exports('deleteCharacter', deleteCharacter)
exports('character.delete', deleteCharacter)
exports('getActiveCharacter', getActiveCharacter)
exports('character.getActive', getActiveCharacter)
exports('getIdentity', getIdentity)
exports('identity.get', getIdentity)
exports('validateCitizenId', validateCitizenId)
exports('character.validateCitizenId', validateCitizenId)
