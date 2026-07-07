local actionLocks = {}

local function nowMs()
    return GetGameTimer()
end

function NexaHousingAcquireLock(source, action, propertyUnitId)
    local key = ('%s:%s:%s'):format(source, action, propertyUnitId)
    local current = actionLocks[key]
    local currentTime = nowMs()

    if current ~= nil and current.expiresAt > currentTime then
        return false
    end

    actionLocks[key] = {
        source = source,
        expiresAt = currentTime + NexaHousingServerConfig.purchaseLockTtlMs
    }

    return true
end

function NexaHousingReleaseLock(source, action, propertyUnitId)
    local key = ('%s:%s:%s'):format(source, action, propertyUnitId)
    local current = actionLocks[key]

    if current ~= nil and current.source == source then
        actionLocks[key] = nil
    end
end

CreateThread(function()
    while true do
        Wait(60000)

        local currentTime = nowMs()

        for key, lock in pairs(actionLocks) do
            if lock.expiresAt <= currentTime then
                actionLocks[key] = nil
            end
        end
    end
end)

CreateThread(function()
    lib.print.info('nexa_housing bereit.')
end)
