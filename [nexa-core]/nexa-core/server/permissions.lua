Nexa.Permissions = {
    cache = {}
}

local function normalizePermission(permission)
    if type(permission) ~= 'string' then
        return nil
    end

    permission = permission:lower():gsub('%s+', '')

    if permission == '' or #permission > 96 or not permission:match('^[a-z0-9_%.:%-]+$') then
        return nil
    end

    return permission
end

function Nexa.Permissions.Load(playerId)
    if type(playerId) ~= 'number' then
        return {}
    end

    local rows, err = Nexa.Database.FetchAll(
        'SELECT permission, value FROM nexa_permissions WHERE player_id = ?',
        { playerId }
    )

    if err then
        Nexa.Log('error', 'Permissions konnten nicht geladen werden.', {
            player_id = playerId
        })
        return {}
    end

    local permissions = {}

    for _, row in ipairs(rows or {}) do
        permissions[row.permission] = row.value == 1
    end

    Nexa.Permissions.cache[playerId] = permissions
    return permissions
end

function Nexa.Permissions.Has(source, permission)
    local normalized = normalizePermission(permission)

    if not normalized then
        return false
    end

    local player = Nexa.Players.Get(source)

    if not player then
        return false
    end

    if IsPlayerAceAllowed(source, normalized) then
        return true
    end

    local permissions = Nexa.Permissions.cache[player.id] or Nexa.Permissions.Load(player.id)
    return permissions[normalized] == true
end

function Nexa.Permissions.Set(playerId, permission, value, actor)
    local normalized = normalizePermission(permission)

    if type(playerId) ~= 'number' or not normalized or type(value) ~= 'boolean' then
        return false, 'INVALID_INPUT'
    end

    local affected, err = Nexa.Database.Update([[
        INSERT INTO nexa_permissions (player_id, permission, value)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE value = VALUES(value), updated_at = CURRENT_TIMESTAMP
    ]], { playerId, normalized, value and 1 or 0 })

    if err then
        return false, 'DATABASE_ERROR'
    end

    Nexa.Permissions.cache[playerId] = nil
    Nexa.Audit('permission.set', actor, {
        player_id = playerId,
        permission = normalized,
        value = value
    })

    return affected ~= nil, nil
end
