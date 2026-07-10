NexaCharacters = NexaCharacters or {}
NexaCharacters.Database = {}

local CORE_RESOURCE = 'nexa-core'

local function getCore()
    if GetResourceState(CORE_RESOURCE) ~= 'started' then
        return nil, 'CORE_NOT_STARTED'
    end

    local ok, coreObject = pcall(function()
        return exports[CORE_RESOURCE]:GetCoreObject()
    end)

    if not ok or type(coreObject) ~= 'table' or type(coreObject.Database) ~= 'table' then
        return nil, 'CORE_DATABASE_UNAVAILABLE'
    end

    return coreObject, nil
end

local function getDatabase()
    local coreObject, err = getCore()

    if not coreObject then
        return nil, err
    end

    return coreObject.Database, nil
end

local function dbError(err)
    if type(err) == 'table' then
        return err.code or NEXA_CHARACTERS.errors.database
    end

    return err or NEXA_CHARACTERS.errors.database
end

function NexaCharacters.Database.RegisterMigrations()
    local coreObject, err = getCore()

    if not coreObject then
        return false, err
    end

    local db = coreObject.Database

    db.RegisterMigration({
        id = '020_characters_domain_columns',
        description = 'Extend nexa_characters for account-owned character domain',
        transaction = false,
        statements = {
            [[ALTER TABLE nexa_characters ADD COLUMN IF NOT EXISTS account_id BIGINT UNSIGNED NULL AFTER player_id]],
            [[ALTER TABLE nexa_characters ADD COLUMN IF NOT EXISTS slot INT UNSIGNED NULL AFTER account_id]],
            [[ALTER TABLE nexa_characters ADD COLUMN IF NOT EXISTS status VARCHAR(32) NOT NULL DEFAULT 'active' AFTER slot]],
            [[ALTER TABLE nexa_characters ADD COLUMN IF NOT EXISTS height INT UNSIGNED NULL AFTER gender]],
            [[ALTER TABLE nexa_characters ADD COLUMN IF NOT EXISTS weight INT UNSIGNED NULL AFTER height]],
            [[ALTER TABLE nexa_characters ADD COLUMN IF NOT EXISTS nationality VARCHAR(64) NULL AFTER weight]],
            [[ALTER TABLE nexa_characters ADD COLUMN IF NOT EXISTS backstory TEXT NULL AFTER nationality]],
            [[ALTER TABLE nexa_characters ADD COLUMN IF NOT EXISTS phone_number VARCHAR(32) NULL AFTER backstory]],
            [[ALTER TABLE nexa_characters ADD COLUMN IF NOT EXISTS version INT UNSIGNED NOT NULL DEFAULT 1 AFTER metadata]],
            [[ALTER TABLE nexa_characters ADD COLUMN IF NOT EXISTS last_selected_at TIMESTAMP NULL DEFAULT NULL AFTER version]],
            [[CREATE INDEX IF NOT EXISTS idx_nexa_characters_account ON nexa_characters (account_id)]],
            [[CREATE INDEX IF NOT EXISTS idx_nexa_characters_status ON nexa_characters (status)]],
            [[CREATE UNIQUE INDEX IF NOT EXISTS uq_nexa_characters_account_slot ON nexa_characters (account_id, slot)]]
        }
    })

    return db.RunMigrations()
end

function NexaCharacters.Database.GetAccountStorage(accountId)
    local db, err = getDatabase()

    if not db then
        return nil, err
    end

    local row, queryErr = db.Single([[
        SELECT id, legacy_player_id
        FROM nexa_accounts
        WHERE id = ?
        LIMIT 1
    ]], { accountId }, {
        category = 'characters.account_storage'
    })

    if queryErr then
        return nil, dbError(queryErr)
    end

    return row, nil
end

function NexaCharacters.Database.ListForAccount(accountId)
    local db, err = getDatabase()

    if not db then
        return nil, err
    end

    local rows, queryErr = db.Query([[
        SELECT id, player_id, account_id, slot, status, first_name, last_name, birthdate, gender,
               height, weight, nationality, backstory, phone_number, metadata, version,
               last_selected_at, created_at, updated_at, deleted_at
        FROM nexa_characters
        WHERE account_id = ? AND deleted_at IS NULL AND status <> 'deleted'
        ORDER BY slot ASC, id ASC
    ]], { accountId }, {
        category = 'characters.list'
    })

    if queryErr then
        return nil, dbError(queryErr)
    end

    return rows or {}, nil
end

function NexaCharacters.Database.GetById(characterId)
    local db, err = getDatabase()

    if not db then
        return nil, err
    end

    local row, queryErr = db.Single([[
        SELECT id, player_id, account_id, slot, status, first_name, last_name, birthdate, gender,
               height, weight, nationality, backstory, phone_number, metadata, version,
               last_selected_at, created_at, updated_at, deleted_at
        FROM nexa_characters
        WHERE id = ?
        LIMIT 1
    ]], { characterId }, {
        category = 'characters.get'
    })

    if queryErr then
        return nil, dbError(queryErr)
    end

    return row, nil
end

function NexaCharacters.Database.FindSlot(accountId, slot)
    local db, err = getDatabase()

    if not db then
        return nil, err
    end

    local row, queryErr = db.Single([[
        SELECT id
        FROM nexa_characters
        WHERE account_id = ? AND slot = ? AND deleted_at IS NULL AND status <> 'deleted'
        LIMIT 1
    ]], { accountId, slot }, {
        category = 'characters.slot'
    })

    if queryErr then
        return nil, dbError(queryErr)
    end

    return row, nil
end

function NexaCharacters.Database.Insert(accountId, legacyPlayerId, payload)
    local db, err = getDatabase()

    if not db then
        return nil, err
    end

    local characterId, insertErr = db.Insert([[
        INSERT INTO nexa_characters (
            player_id, account_id, slot, status, first_name, last_name, birthdate, gender,
            height, weight, nationality, backstory, phone_number, metadata, version
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
    ]], {
        legacyPlayerId,
        accountId,
        payload.slot,
        NEXA_CHARACTERS.statuses.active,
        payload.firstName,
        payload.lastName,
        payload.birthdate,
        payload.gender,
        payload.height,
        payload.weight,
        payload.nationality,
        payload.backstory,
        payload.phoneNumber,
        json.encode(payload.metadata or {})
    }, {
        category = 'characters.create'
    })

    if insertErr then
        return nil, dbError(insertErr)
    end

    return tonumber(characterId), nil
end

function NexaCharacters.Database.Update(characterId, changes)
    local db, err = getDatabase()

    if not db then
        return false, err
    end

    local fields = {}
    local params = {}
    local map = {
        firstName = 'first_name',
        lastName = 'last_name',
        birthdate = 'birthdate',
        gender = 'gender',
        height = 'height',
        weight = 'weight',
        nationality = 'nationality',
        backstory = 'backstory',
        phoneNumber = 'phone_number',
        status = 'status'
    }

    for key, column in pairs(map) do
        if changes[key] ~= nil then
            fields[#fields + 1] = column .. ' = ?'
            params[#params + 1] = changes[key]
        end
    end

    if changes.metadata ~= nil then
        fields[#fields + 1] = 'metadata = ?'
        params[#params + 1] = json.encode(changes.metadata)
    end

    if #fields == 0 then
        return false, NEXA_CHARACTERS.errors.invalidInput
    end

    fields[#fields + 1] = 'updated_at = CURRENT_TIMESTAMP'
    fields[#fields + 1] = 'version = version + 1'
    params[#params + 1] = characterId

    local affected, updateErr = db.Update(('UPDATE nexa_characters SET %s WHERE id = ?'):format(table.concat(fields, ', ')), params, {
        category = 'characters.update'
    })

    if updateErr then
        return false, dbError(updateErr)
    end

    return affected and affected > 0, affected and affected > 0 and nil or NEXA_CHARACTERS.errors.notFound
end

function NexaCharacters.Database.MarkSelected(characterId)
    local db, err = getDatabase()

    if not db then
        return false, err
    end

    local _, updateErr = db.Update([[
        UPDATE nexa_characters
        SET last_selected_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], { characterId }, {
        category = 'characters.select'
    })

    if updateErr then
        return false, dbError(updateErr)
    end

    return true, nil
end

function NexaCharacters.Database.SoftDelete(characterId, reason)
    local db, err = getDatabase()

    if not db then
        return false, err
    end

    local _, updateErr = db.Update([[
        UPDATE nexa_characters
        SET status = 'deleted', deleted_at = CURRENT_TIMESTAMP, metadata = JSON_SET(COALESCE(metadata, JSON_OBJECT()), '$.deleteReason', ?)
        WHERE id = ? AND deleted_at IS NULL
    ]], { reason, characterId }, {
        category = 'characters.delete'
    })

    if updateErr then
        return false, dbError(updateErr)
    end

    return true, nil
end
