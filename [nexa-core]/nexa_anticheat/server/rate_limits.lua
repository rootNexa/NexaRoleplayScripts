local buckets = {}

local function getLimit(eventName)
    return NexaAnticheatServer.rateLimits[eventName] or NexaAnticheatServer.rateLimits.default
end

function NexaAnticheatCheckRateLimit(source, eventName)
    local limit = getLimit(eventName)
    local now = os.time()
    local key = ('%s:%s'):format(tostring(source), eventName)
    local bucket = buckets[key]

    if bucket == nil or now - bucket.startedAt >= limit.windowSeconds then
        buckets[key] = {
            count = 1,
            startedAt = now
        }

        return true, 'OK'
    end

    bucket.count = bucket.count + 1

    if bucket.count > limit.count then
        return false, 'RATE_LIMITED'
    end

    return true, 'OK'
end
