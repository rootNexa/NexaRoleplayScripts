local migrated = false

local function logInfo(message, metadata)
    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info(NEXA_JOBSCREATOR.resourceName, message, metadata or {})
        return
    end

    print(('[%s] %s'):format(NEXA_JOBSCREATOR.resourceName, message))
end

local function logError(message, metadata)
    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:error(NEXA_JOBSCREATOR.resourceName, message, metadata or {})
        return
    end

    print(('[%s] ERROR: %s'):format(NEXA_JOBSCREATOR.resourceName, message))
end

local function runMigrations()
    if not NexaJobsCreatorConfig.autoMigrate then
        logInfo('JobsCreator gestartet, Migrationen sind deaktiviert.', {
            version = NEXA_JOBSCREATOR.version
        })
        return
    end

    local ok, errorMessage = NexaJobsCreatorDatabase.Migrate()
    migrated = ok == true

    if migrated then
        logInfo('JobsCreator Foundation gestartet.', {
            version = NEXA_JOBSCREATOR.version,
            autoMigrate = true
        })
        return
    end

    logError('JobsCreator Migration fehlgeschlagen.', {
        error = errorMessage
    })
end

local function getStatus()
    return {
        resourceName = NEXA_JOBSCREATOR.resourceName,
        version = NEXA_JOBSCREATOR.version,
        migrated = migrated,
        organizationTypes = NexaJobsCreatorSupportedTypes,
        mdtTypes = NexaJobsCreatorMdtTypes
    }
end

local function isSupportedOrganizationType(organizationType)
    return type(organizationType) == 'string' and NexaJobsCreatorSupportedTypes[organizationType] == true
end

local function isSupportedMdtType(mdtType)
    return type(mdtType) == 'string' and NexaJobsCreatorMdtTypes[mdtType] == true
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    runMigrations()
end)

exports('getStatus', getStatus)
exports('getSchema', NexaJobsCreatorDatabase.GetSchema)
exports('isSupportedOrganizationType', isSupportedOrganizationType)
exports('isSupportedMdtType', isSupportedMdtType)
