function has(source, permission)
    local allowed, code = hasPermissionInternal(source, permission)

    return {
        success = allowed,
        code = code,
        message = allowed and 'Berechtigung vorhanden.' or 'Berechtigung fehlt.',
        data = {
            source = source,
            permission = permission
        },
        meta = nil,
        audit_id = nil
    }
end

function hasAny(source, permissions)
    if type(permissions) ~= 'table' then
        return {
            success = false,
            code = 'INVALID_INPUT',
            message = 'Berechtigungsliste ist ungueltig.',
            data = nil,
            meta = nil,
            audit_id = nil
        }
    end

    for _, permission in ipairs(permissions) do
        local allowed = hasPermissionInternal(source, permission)

        if allowed then
            return {
                success = true,
                code = 'OK',
                message = 'Mindestens eine Berechtigung ist vorhanden.',
                data = {
                    source = source,
                    permission = permission
                },
                meta = nil,
                audit_id = nil
            }
        end
    end

    return {
        success = false,
        code = 'NO_PERMISSION',
        message = 'Keine passende Berechtigung vorhanden.',
        data = {
            source = source
        },
        meta = nil,
        audit_id = nil
    }
end

function getRoles(source)
    return {
        success = true,
        code = 'OK',
        message = 'Session-Rollen wurden geladen.',
        data = {
            source = source,
            roles = {}
        },
        meta = {
            persistentRolesAvailable = false
        },
        audit_id = nil
    }
end

function assignRole(source, permission)
    local allowed, code = assignSessionPermission(source, permission)

    return {
        success = allowed,
        code = code,
        message = allowed and 'Berechtigung wurde fuer diese Session vergeben.' or 'Berechtigung konnte nicht vergeben werden.',
        data = {
            source = source,
            permission = permission
        },
        meta = {
            persistent = false
        },
        audit_id = nil
    }
end

function removeRole(source, permission)
    local allowed, code = removeSessionPermission(source, permission)

    return {
        success = allowed,
        code = code,
        message = allowed and 'Berechtigung wurde fuer diese Session entfernt.' or 'Berechtigung konnte nicht entfernt werden.',
        data = {
            source = source,
            permission = permission
        },
        meta = {
            persistent = false
        },
        audit_id = nil
    }
end

exports('has', has)
exports('hasAny', hasAny)
exports('getRoles', getRoles)
exports('assignRole', assignRole)
exports('removeRole', removeRole)
