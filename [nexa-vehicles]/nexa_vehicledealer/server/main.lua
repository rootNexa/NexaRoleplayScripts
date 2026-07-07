local purchaseLocks = {}

local function nowMs()
    return GetGameTimer()
end

function NexaVehicleDealerAcquirePurchaseLock(source, dealerId, catalogId)
    local key = ('%s:%s:%s'):format(source, dealerId, catalogId)
    local current = purchaseLocks[key]
    local currentTime = nowMs()

    if current ~= nil and current.expiresAt > currentTime then
        return false
    end

    purchaseLocks[key] = {
        source = source,
        expiresAt = currentTime + NexaVehicleDealerServerConfig.purchaseLockTtlMs
    }

    return true
end

function NexaVehicleDealerReleasePurchaseLock(source, dealerId, catalogId)
    local key = ('%s:%s:%s'):format(source, dealerId, catalogId)
    local current = purchaseLocks[key]

    if current ~= nil and current.source == source then
        purchaseLocks[key] = nil
    end
end

CreateThread(function()
    while true do
        Wait(60000)

        local currentTime = nowMs()

        for key, lock in pairs(purchaseLocks) do
            if lock.expiresAt <= currentTime then
                purchaseLocks[key] = nil
            end
        end
    end
end)
