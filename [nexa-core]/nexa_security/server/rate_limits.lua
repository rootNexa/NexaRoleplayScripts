local buckets = {}
local bucketCount = 0

local function getLimit(eventName)
    return NexaSecurityServer.limits[eventName] or NexaSecurityServer.defaultLimit
end

local function getBucketKey(source, eventName)
    return ('%s:%s'):format(tostring(source), eventName)
end

local function purgeExpiredBuckets(now)
    local removed = 0

    for key, bucket in pairs(buckets) do
        local limit = getLimit(bucket.eventName)

        if now - bucket.startedAt >= limit.windowSeconds then
            buckets[key] = nil
            removed = removed + 1
        end
    end

    bucketCount = math.max(0, bucketCount - removed)
end

function checkRateLimitInternal(source, eventName)
    local valid, code = NexaSecurityValidateEventName(eventName)

    if not valid then
        return false, code
    end

    local limit = getLimit(eventName)
    local now = os.time()
    local key = getBucketKey(source, eventName)
    local bucket = buckets[key]

    if bucket == nil or now - bucket.startedAt >= limit.windowSeconds then
        if bucket == nil then
            bucketCount = bucketCount + 1
        end

        buckets[key] = {
            count = 1,
            startedAt = now,
            eventName = eventName
        }

        if bucketCount > NexaSecurityServer.maxBuckets then
            purgeExpiredBuckets(now)
        end

        if bucketCount > NexaSecurityServer.maxBuckets then
            buckets[key] = nil
            bucketCount = bucketCount - 1

            return false, 'RATE_LIMITED'
        end

        return true, 'OK'
    end

    bucket.count = bucket.count + 1

    if bucket.count > limit.count then
        TriggerEvent('nexa:security:internal:rateLimitExceeded', {
            source = source,
            eventName = eventName,
            count = bucket.count,
            windowSeconds = limit.windowSeconds
        })

        return false, 'RATE_LIMITED'
    end

    return true, 'OK'
end
