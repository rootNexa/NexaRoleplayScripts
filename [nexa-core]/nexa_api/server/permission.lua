function hasPermission(source, permission)
    return exports.nexa_permissions:has(source, permission)
end

exports('hasPermission', hasPermission)
exports('permission.has', hasPermission)
