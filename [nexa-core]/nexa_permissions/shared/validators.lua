function NexaPermissionsNormalizeSource(source)
    local sourceNumber = tonumber(source)

    if not sourceNumber or sourceNumber <= 0 then
        return nil
    end

    return sourceNumber
end

function NexaPermissionsNormalizePermission(permission)
    if type(permission) ~= 'string' then
        return nil
    end

    local normalized = permission:lower():gsub('%s+', '')

    if normalized == '' or #normalized > NexaPermissionsConfig.MaxPermissionLength then
        return nil
    end

    if not normalized:match('^[a-z0-9_%.:%-%*]+$') then
        return nil
    end

    if normalized:find('%.%.', 1, true) then
        return nil
    end

    return normalized
end

function NexaPermissionsNormalizeRoleName(roleName)
    if type(roleName) ~= 'string' then
        return nil
    end

    local normalized = roleName:lower():gsub('%s+', '')

    if normalized == '' or #normalized > NexaPermissionsConfig.MaxRoleNameLength then
        return nil
    end

    if not normalized:match('^[a-z0-9_%-]+$') then
        return nil
    end

    return normalized
end

function NexaPermissionsIsIdentifier(value)
    return type(value) == 'string' and value:match('^[%w_%-]+:.+') ~= nil
end
