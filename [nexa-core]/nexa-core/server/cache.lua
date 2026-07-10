Nexa.Cache = Nexa.Cache or {
    namespaces = {},
    loading = {},
    running = false,
    cleanupIntervalMs = 60000,
    defaults = {
        maxEntries = 512,
        maxValueBytes = 65536
    }
}

local INVALID_VALUE_TYPES = {
    ['function'] = true,
    thread = true,
    userdata = true
}

local function nowMs()
    if GetGameTimer then
        return GetGameTimer()
    end

    return math.floor(os.clock() * 1000)
end

local function cacheLog(level, category, message, context)
    if Nexa.Logger and Nexa.Logger[level] then
        Nexa.Logger[level](category, message, context)
        return
    end

    Nexa.Log(level:lower(), message, context)
end

local function normalizeNamespace(namespace)
    if type(namespace) ~= 'string' then
        return nil
    end

    namespace = namespace:lower():gsub('%s+', '')

    if namespace == '' or #namespace > 64 or not namespace:match('^[a-z0-9_%-%.:]+$') then
        return nil
    end

    return namespace
end

local function normalizeKey(key)
    if type(key) ~= 'string' and type(key) ~= 'number' then
        return nil
    end

    key = tostring(key)

    if key == '' or #key > 160 then
        return nil
    end

    return key
end

local function cloneValue(value, depth, seen)
    local valueType = type(value)

    if INVALID_VALUE_TYPES[valueType] then
        return nil, 'INVALID_VALUE_TYPE'
    end

    if valueType ~= 'table' then
        return value, nil
    end

    if depth > 8 then
        return nil, 'VALUE_TOO_DEEP'
    end

    if seen[value] then
        return nil, 'VALUE_CYCLE'
    end

    seen[value] = true
    local cloned = {}

    for key, nestedValue in pairs(value) do
        local clonedKey, keyErr = cloneValue(key, depth + 1, seen)

        if keyErr then
            return nil, keyErr
        end

        local clonedValue, valueErr = cloneValue(nestedValue, depth + 1, seen)

        if valueErr then
            return nil, valueErr
        end

        cloned[clonedKey] = clonedValue
    end

    seen[value] = nil
    return cloned, nil
end

local function estimateSize(value)
    if value == nil then
        return 0
    end

    local ok, encoded = pcall(json.encode, value)

    if not ok or type(encoded) ~= 'string' then
        return nil, 'SIZE_UNAVAILABLE'
    end

    return #encoded, nil
end

local function getNamespace(namespace, create)
    namespace = normalizeNamespace(namespace)

    if not namespace then
        return nil, 'INVALID_NAMESPACE'
    end

    local state = Nexa.Cache.namespaces[namespace]

    if not state and create then
        state = {
            entries = {},
            order = {},
            stats = {
                namespace = namespace,
                entries = 0,
                hits = 0,
                misses = 0,
                sets = 0,
                deletes = 0,
                clears = 0,
                evictions = 0,
                expirations = 0,
                loads = 0,
                loadErrors = 0
            },
            options = {
                maxEntries = Nexa.Cache.defaults.maxEntries,
                maxValueBytes = Nexa.Cache.defaults.maxValueBytes
            }
        }

        Nexa.Cache.namespaces[namespace] = state
    end

    return state, nil, namespace
end

local function removeFromOrder(state, key)
    for index, value in ipairs(state.order) do
        if value == key then
            table.remove(state.order, index)
            return
        end
    end
end

local function deleteEntry(state, key, reason)
    local entry = state.entries[key]

    if not entry then
        return false
    end

    state.entries[key] = nil
    removeFromOrder(state, key)
    state.stats.entries = math.max(0, state.stats.entries - 1)

    if reason == 'expired' then
        state.stats.expirations = state.stats.expirations + 1
    elseif reason == 'evicted' then
        state.stats.evictions = state.stats.evictions + 1
    else
        state.stats.deletes = state.stats.deletes + 1
    end

    return true
end

local function isExpired(entry)
    return entry.expiresAt ~= nil and entry.expiresAt <= nowMs()
end

local function enforceLimit(state)
    local maxEntries = tonumber(state.options.maxEntries) or Nexa.Cache.defaults.maxEntries

    while maxEntries > 0 and state.stats.entries > maxEntries do
        local oldestKey = table.remove(state.order, 1)

        if not oldestKey then
            break
        end

        if state.entries[oldestKey] then
            state.entries[oldestKey] = nil
            state.stats.entries = math.max(0, state.stats.entries - 1)
            state.stats.evictions = state.stats.evictions + 1
        end
    end
end

function Nexa.Cache.Set(namespace, key, value, options)
    options = options or {}
    local state, nsErr = getNamespace(namespace, true)
    key = normalizeKey(key)

    if not state or not key then
        return false, nsErr or 'INVALID_KEY'
    end

    if options.secret == true then
        return false, 'SECRET_CACHE_BLOCKED'
    end

    local cloned, cloneErr = cloneValue(value, 0, {})

    if cloneErr then
        return false, cloneErr
    end

    local size, sizeErr = estimateSize(cloned)

    if sizeErr then
        return false, sizeErr
    end

    local maxValueBytes = tonumber(options.maxValueBytes) or state.options.maxValueBytes

    if maxValueBytes > 0 and size > maxValueBytes then
        return false, 'VALUE_TOO_LARGE'
    end

    local ttlMs = tonumber(options.ttlMs)
    local expiresAt = ttlMs and ttlMs > 0 and nowMs() + ttlMs or nil
    local existed = state.entries[key] ~= nil

    state.entries[key] = {
        value = cloned,
        size = size,
        createdAt = nowMs(),
        touchedAt = nowMs(),
        expiresAt = expiresAt
    }

    if not existed then
        state.order[#state.order + 1] = key
        state.stats.entries = state.stats.entries + 1
    end

    if options.maxEntries then
        state.options.maxEntries = tonumber(options.maxEntries) or state.options.maxEntries
    end

    state.stats.sets = state.stats.sets + 1
    enforceLimit(state)
    return true, nil
end

function Nexa.Cache.Get(namespace, key)
    local state = getNamespace(namespace, false)
    key = normalizeKey(key)

    if not state or not key then
        return nil, 'NOT_FOUND'
    end

    local entry = state.entries[key]

    if not entry then
        state.stats.misses = state.stats.misses + 1
        return nil, 'MISS'
    end

    if isExpired(entry) then
        deleteEntry(state, key, 'expired')
        state.stats.misses = state.stats.misses + 1
        return nil, 'EXPIRED'
    end

    entry.touchedAt = nowMs()
    state.stats.hits = state.stats.hits + 1
    return cloneValue(entry.value, 0, {})
end

function Nexa.Cache.Has(namespace, key)
    local state = getNamespace(namespace, false)
    key = normalizeKey(key)

    if not state or not key then
        return false
    end

    local entry = state.entries[key]

    if not entry then
        return false
    end

    if isExpired(entry) then
        deleteEntry(state, key, 'expired')
        return false
    end

    return true
end

function Nexa.Cache.Delete(namespace, key)
    local state = getNamespace(namespace, false)
    key = normalizeKey(key)

    if not state or not key then
        return false, 'NOT_FOUND'
    end

    return deleteEntry(state, key, 'delete'), nil
end

function Nexa.Cache.Clear(namespace)
    if namespace == nil then
        for _, state in pairs(Nexa.Cache.namespaces) do
            state.entries = {}
            state.order = {}
            state.stats.entries = 0
            state.stats.clears = state.stats.clears + 1
        end

        return true, nil
    end

    local state = getNamespace(namespace, false)

    if not state then
        return false, 'NOT_FOUND'
    end

    state.entries = {}
    state.order = {}
    state.stats.entries = 0
    state.stats.clears = state.stats.clears + 1
    return true, nil
end

function Nexa.Cache.GetOrLoad(namespace, key, loader, options)
    if type(loader) ~= 'function' then
        return nil, 'INVALID_LOADER'
    end

    local cached = Nexa.Cache.Get(namespace, key)

    if cached ~= nil then
        return cached, nil, true
    end

    local normalizedNamespace = normalizeNamespace(namespace)
    local normalizedKey = normalizeKey(key)

    if not normalizedNamespace or not normalizedKey then
        return nil, 'INVALID_INPUT'
    end

    local loadKey = ('%s:%s'):format(normalizedNamespace, normalizedKey)
    local pending = Nexa.Cache.loading[loadKey]

    if pending and promise and Citizen and Citizen.Await then
        local result = Citizen.Await(pending)
        return result.value, result.err, result.cached == true
    elseif pending then
        return nil, 'LOAD_IN_PROGRESS'
    end

    local pendingPromise = promise and promise.new and promise.new() or nil

    if pendingPromise then
        Nexa.Cache.loading[loadKey] = pendingPromise
    else
        Nexa.Cache.loading[loadKey] = true
    end

    local state = getNamespace(namespace, true)

    if state then
        state.stats.loads = state.stats.loads + 1
    end

    local ok, loadedValue, loadErr = pcall(loader, normalizedNamespace, normalizedKey)
    local result

    if not ok or loadErr ~= nil then
        if state then
            state.stats.loadErrors = state.stats.loadErrors + 1
        end

        result = {
            value = nil,
            err = loadErr or tostring(loadedValue) or 'LOAD_FAILED'
        }
    else
        local setOk, setErr = Nexa.Cache.Set(namespace, key, loadedValue, options)

        if not setOk then
            result = {
                value = nil,
                err = setErr
            }
        else
            result = {
                value = loadedValue,
                err = nil,
                cached = false
            }
        end
    end

    if pendingPromise then
        pendingPromise:resolve(result)
    end

    Nexa.Cache.loading[loadKey] = nil

    if result.err then
        cacheLog('Warn', 'cache.loader', 'Cache Loader fehlgeschlagen.', {
            namespace = normalizedNamespace,
            key = normalizedKey,
            error = result.err
        })
    end

    return result.value, result.err, result.cached == true
end

function Nexa.Cache.GetStats(namespace)
    local state = getNamespace(namespace, false)

    if not state then
        return {
            namespace = namespace,
            entries = 0,
            hits = 0,
            misses = 0,
            sets = 0,
            deletes = 0,
            clears = 0,
            evictions = 0,
            expirations = 0,
            loads = 0,
            loadErrors = 0
        }
    end

    local stats = {}

    for key, value in pairs(state.stats) do
        stats[key] = value
    end

    return stats
end

function Nexa.Cache.Cleanup()
    for _, state in pairs(Nexa.Cache.namespaces) do
        for key, entry in pairs(state.entries) do
            if isExpired(entry) then
                deleteEntry(state, key, 'expired')
            end
        end

        enforceLimit(state)
    end

    return true, nil
end

function Nexa.Cache.Start()
    if Nexa.Cache.running then
        return true, nil
    end

    Nexa.Cache.running = true

    if CreateThread then
        CreateThread(function()
            while Nexa.Cache.running do
                Wait(Nexa.Cache.cleanupIntervalMs)
                Nexa.Cache.Cleanup()
            end
        end)
    end

    return true, nil
end

function Nexa.Cache.Stop()
    Nexa.Cache.running = false
    Nexa.Cache.loading = {}
    Nexa.Cache.Cleanup()
    return true, nil
end
