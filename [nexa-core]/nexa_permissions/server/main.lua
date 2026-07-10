local RESOURCE = GetCurrentResourceName()

local function isDevelopment()
    return NexaPermissionsConfig.DevMode == true or GetConvar('nexa:environment', 'development') == 'development'
end

local function commandAllowed(source)
    if source == 0 then
        return true
    end

    if isDevelopment() then
        return true
    end

    local response = NexaPermissions.Has(source, NexaPermissionsServer.CommandPermission)
    return response.ok and response.data.allowed == true
end

local function printResult(prefix, response)
    print(('[%s] %s %s'):format(RESOURCE, prefix, json.encode(response)))
end

local function registerCommands()
    RegisterCommand('nexaperms', function(source)
        if not commandAllowed(source) then
            printResult('nexaperms', {
                ok = false,
                error = 'FORBIDDEN'
            })
            return
        end

        printResult('nexaperms', NexaPermissions.ListRegisteredPermissions())
    end, false)

    RegisterCommand('nexahas', function(source, args)
        if not commandAllowed(source) then
            printResult('nexahas', {
                ok = false,
                error = 'FORBIDDEN'
            })
            return
        end

        printResult('nexahas', NexaPermissions.Has(source, args[1]))
    end, false)

    RegisterCommand('nexaroles', function(source)
        if not commandAllowed(source) then
            printResult('nexaroles', {
                ok = false,
                error = 'FORBIDDEN'
            })
            return
        end

        printResult('nexaroles', NexaPermissions.ListRoles())
    end, false)

    RegisterCommand('nexaassignrole', function(source, args)
        if not commandAllowed(source) then
            printResult('nexaassignrole', {
                ok = false,
                error = 'FORBIDDEN'
            })
            return
        end

        printResult('nexaassignrole', NexaPermissions.AssignRole(source, args[1], args[2], table.concat(args, ' ', 3)))
    end, false)

    RegisterCommand('nexaremoverole', function(source, args)
        if not commandAllowed(source) then
            printResult('nexaremoverole', {
                ok = false,
                error = 'FORBIDDEN'
            })
            return
        end

        printResult('nexaremoverole', NexaPermissions.RemoveRole(source, args[1], args[2], table.concat(args, ' ', 3)))
    end, false)

    RegisterCommand('nexareloadperms', function(source)
        if not commandAllowed(source) then
            printResult('nexareloadperms', {
                ok = false,
                error = 'FORBIDDEN'
            })
            return
        end

        printResult('nexareloadperms', NexaPermissions.ReloadPermissions())
    end, false)
end

local function normalizeExportArgs(...)
    local args = { ... }

    if type(args[1]) == 'table' then
        table.remove(args, 1)
    end

    return table.unpack(args)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    NexaPermissions.Start()

    if NexaPermissionsServer.CommandsEnabled then
        registerCommands()
    end
end)

AddEventHandler('playerDropped', function()
    local droppedSource = source

    if droppedSource then
        NexaPermissions.AdminDuty.Clear(tonumber(droppedSource), 'Player disconnected')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    for source in pairs(NexaPermissions.adminDutyBySource) do
        NexaPermissions.AdminDuty.Clear(source, 'nexa_permissions stopped')
    end
end)

function Has(...)
    local source, permission = normalizeExportArgs(...)
    return NexaPermissions.Has(source, permission)
end

function HasAny(...)
    local source, permissions = normalizeExportArgs(...)
    return NexaPermissions.HasAny(source, permissions)
end

function HasAll(...)
    local source, permissions = normalizeExportArgs(...)
    return NexaPermissions.HasAll(source, permissions)
end

function GetPermissions(...)
    local source = normalizeExportArgs(...)
    return NexaPermissions.GetPermissions(source)
end

function GetRoles(...)
    local source = normalizeExportArgs(...)
    return NexaPermissions.GetRoles(source)
end

function GetDecisionTrace(...)
    local actor, target, permission = normalizeExportArgs(...)
    return NexaPermissions.GetDecisionTrace(actor, target, permission)
end

function GetRole(...)
    local roleName = normalizeExportArgs(...)
    return NexaPermissions.GetRole(roleName)
end

function ListRoles(...)
    normalizeExportArgs(...)
    return NexaPermissions.ListRoles()
end

function ListRegisteredPermissions(...)
    normalizeExportArgs(...)
    return NexaPermissions.ListRegisteredPermissions()
end

function AssignRole(...)
    local actor, target, role, reason = normalizeExportArgs(...)
    return NexaPermissions.AssignRole(actor, target, role, reason)
end

function RemoveRole(...)
    local actor, target, role, reason = normalizeExportArgs(...)
    return NexaPermissions.RemoveRole(actor, target, role, reason)
end

function GrantPermission(...)
    local actor, target, permission, reason = normalizeExportArgs(...)
    return NexaPermissions.GrantPermission(actor, target, permission, reason)
end

function DenyPermission(...)
    local actor, target, permission, reason = normalizeExportArgs(...)
    return NexaPermissions.DenyPermission(actor, target, permission, reason)
end

function RevokePermission(...)
    local actor, target, permission, reason = normalizeExportArgs(...)
    return NexaPermissions.RevokePermission(actor, target, permission, reason)
end

function RegisterPermission(...)
    local permission, actor, reason = normalizeExportArgs(...)
    return NexaPermissions.RegisterPermission(permission, actor, reason)
end

function RegisterRole(...)
    local role, actor, reason = normalizeExportArgs(...)
    return NexaPermissions.RegisterRole(role, actor, reason)
end

function SetRoleInheritance(...)
    local role, inheritedRole, actor, reason = normalizeExportArgs(...)
    return NexaPermissions.SetRoleInheritance(role, inheritedRole, actor, reason)
end

function SetAdminDuty(...)
    local source, state, actor, reason = normalizeExportArgs(...)
    return NexaPermissions.AdminDuty.Set(source, state, actor, reason)
end

function GetAdminDuty(...)
    local source = normalizeExportArgs(...)
    return NexaPermissions.AdminDuty.Get(source)
end

function IsAdminOnDuty(...)
    local source = normalizeExportArgs(...)
    return NexaPermissions.AdminDuty.IsOnDuty(source)
end

function ClearAdminDuty(...)
    local source, reason = normalizeExportArgs(...)
    return NexaPermissions.AdminDuty.Clear(source, reason)
end

function AssignRoleToPlayer(...)
    local sourceOrIdentifier, roleName = normalizeExportArgs(...)
    return NexaPermissions.AssignRoleToPlayer(sourceOrIdentifier, roleName)
end

function RemoveRoleFromPlayer(...)
    local sourceOrIdentifier, roleName = normalizeExportArgs(...)
    return NexaPermissions.RemoveRoleFromPlayer(sourceOrIdentifier, roleName)
end

function ReloadPermissions(...)
    normalizeExportArgs(...)
    return NexaPermissions.ReloadPermissions()
end

function GetPermissionCache(...)
    local source = normalizeExportArgs(...)
    return NexaPermissions.GetPermissionCache(source)
end
