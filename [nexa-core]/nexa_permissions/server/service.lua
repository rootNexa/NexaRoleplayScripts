local assignments = {}

local function getAssignmentKey(source, permission)
    return ('%s:%s'):format(tostring(source), permission)
end

local function hasAce(source, permission)
    return IsPlayerAceAllowed(source, NexaPermissionsConfig.acePrefix .. permission)
end

function hasPermissionInternal(source, permission)
    local valid, code = NexaPermissionsValidatePermission(permission)

    if not valid then
        return false, code
    end

    if hasAce(source, permission) then
        return true, 'OK'
    end

    if assignments[getAssignmentKey(source, permission)] == true then
        return true, 'OK'
    end

    return false, 'NO_PERMISSION'
end

function assignSessionPermission(source, permission, actorResource)
    local valid, code = NexaPermissionsValidatePermission(permission)

    if not valid then
        return false, code
    end

    assignments[getAssignmentKey(source, permission)] = true

    exports.nexa_audit:write({
        eventType = 'permission',
        severity = 'warning',
        action = 'permission.assignSession',
        resourceName = actorResource or GetInvokingResource() or NEXA_PERMISSIONS.resourceName,
        metadata = {
            source = source,
            permission = permission
        }
    })

    return true, 'OK'
end

function removeSessionPermission(source, permission, actorResource)
    local valid, code = NexaPermissionsValidatePermission(permission)

    if not valid then
        return false, code
    end

    assignments[getAssignmentKey(source, permission)] = nil

    exports.nexa_audit:write({
        eventType = 'permission',
        severity = 'warning',
        action = 'permission.removeSession',
        resourceName = actorResource or GetInvokingResource() or NEXA_PERMISSIONS.resourceName,
        metadata = {
            source = source,
            permission = permission
        }
    })

    return true, 'OK'
end
