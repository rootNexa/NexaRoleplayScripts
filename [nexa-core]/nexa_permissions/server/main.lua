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

        printResult('nexaperms', NexaPermissions.GetPermissionCache(source))
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

        printResult('nexaroles', NexaPermissions.GetRoles(source))
    end, false)

    RegisterCommand('nexaassignrole', function(source, args)
        if not commandAllowed(source) then
            printResult('nexaassignrole', {
                ok = false,
                error = 'FORBIDDEN'
            })
            return
        end

        printResult('nexaassignrole', NexaPermissions.AssignRoleToPlayer(args[1], args[2]))
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
        NexaPermissions.cacheBySource[tonumber(droppedSource)] = nil
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

function GetRoles(...)
    local source = normalizeExportArgs(...)
    return NexaPermissions.GetRoles(source)
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
