function NexaPermissionsValidatePermission(permission)
    if type(permission) ~= 'string' or permission == '' then
        return false, 'INVALID_PERMISSION'
    end

    local maxLength = exports.nexa_config:get('limits.maxPermissionLength', 96)

    if #permission > maxLength then
        return false, 'PERMISSION_TOO_LONG'
    end

    local domain = permission:match('^([%w_]+)%.')

    if domain == nil or not NexaPermissionsConfig.domains[domain] then
        return false, 'UNKNOWN_PERMISSION_DOMAIN'
    end

    return true, 'OK'
end
