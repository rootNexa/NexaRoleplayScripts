local IS_SERVER = IsDuplicityVersion and IsDuplicityVersion() == true

local function getConvarValue(name, defaultValue)
    if GetConvar then
        return GetConvar(name, defaultValue)
    end

    return defaultValue
end

local function getConvarBool(name, defaultValue)
    local fallback = defaultValue and 'true' or 'false'
    local value = getConvarValue(name, fallback)

    return value == 'true' or value == '1' or value == 'yes'
end

local function getConvarInt(name, defaultValue)
    return tonumber(getConvarValue(name, tostring(defaultValue))) or defaultValue
end

local function deepClone(value, seen)
    if type(value) ~= 'table' then
        return value
    end

    seen = seen or {}

    if seen[value] then
        return seen[value]
    end

    local clone = {}
    seen[value] = clone

    for key, nestedValue in pairs(value) do
        clone[deepClone(key, seen)] = deepClone(nestedValue, seen)
    end

    return clone
end

local function deepMerge(base, override)
    local merged = deepClone(base or {})

    if type(override) ~= 'table' then
        return merged
    end

    for key, value in pairs(override) do
        if type(value) == 'table' and type(merged[key]) == 'table' then
            merged[key] = deepMerge(merged[key], value)
        else
            merged[key] = deepClone(value)
        end
    end

    return merged
end

local function freeze(value, seen)
    if type(value) ~= 'table' then
        return value
    end

    seen = seen or {}

    if seen[value] then
        return seen[value]
    end

    local proxy = {}
    local source = {}
    seen[value] = proxy

    for key, nestedValue in pairs(value) do
        source[key] = freeze(nestedValue, seen)
    end

    return setmetatable(proxy, {
        __index = source,
        __newindex = function()
            error('NexaConfig ist immutable.', 2)
        end,
        __pairs = function()
            return next, source, nil
        end,
        __len = function()
            return #source
        end,
        __metatable = false
    })
end

local function splitPath(path)
    if type(path) ~= 'string' or path == '' then
        return {}
    end

    local parts = {}

    for part in path:gmatch('[^%.]+') do
        parts[#parts + 1] = part
    end

    return parts
end

local function getPathValue(snapshot, path)
    local current = snapshot

    for _, part in ipairs(splitPath(path)) do
        if type(current) ~= 'table' then
            return nil, false
        end

        current = current[part]

        if current == nil then
            return nil, false
        end
    end

    return current, true
end

local function copyPublicValue(value)
    return deepClone(value)
end

local schema = {
    type = 'object',
    unknown = 'error',
    fields = {
        debug = {
            type = 'boolean',
            default = false,
            public = true
        },
        environment = {
            type = 'string',
            required = true,
            default = 'development',
            allowed = { 'development', 'staging', 'production', 'test' },
            public = true
        },
        defaultPermissionRole = {
            type = 'string',
            required = true,
            default = 'user',
            public = false,
            serverOnly = true
        },
        identifierPriority = {
            type = 'array',
            required = true,
            itemType = 'string',
            minItems = 1,
            default = { 'license', 'license2', 'fivem', 'steam', 'discord' },
            public = false,
            serverOnly = true
        },
        character = {
            type = 'object',
            required = true,
            public = true,
            fields = {
                maxPerPlayer = {
                    type = 'number',
                    required = true,
                    default = 4,
                    min = 1,
                    max = 16,
                    public = true
                },
                minNameLength = {
                    type = 'number',
                    required = true,
                    default = 2,
                    min = 1,
                    max = 16,
                    public = true
                },
                maxNameLength = {
                    type = 'number',
                    required = true,
                    default = 32,
                    min = 2,
                    max = 64,
                    public = true
                },
                minBirthYear = {
                    type = 'number',
                    required = true,
                    default = 1900,
                    min = 1850,
                    max = 2100,
                    public = true
                },
                maxBirthYear = {
                    type = 'number',
                    required = true,
                    default = 2010,
                    min = 1850,
                    max = 2100,
                    public = true
                }
            }
        },
        callbacks = {
            type = 'object',
            required = true,
            public = true,
            fields = {
                defaultCooldownMs = {
                    type = 'number',
                    required = true,
                    default = 1000,
                    min = 0,
                    max = 60000,
                    public = true
                },
                timeoutMs = {
                    type = 'number',
                    required = true,
                    default = 10000,
                    min = 100,
                    max = 120000,
                    public = true
                }
            }
        },
        database = {
            type = 'object',
            required = true,
            public = false,
            serverOnly = true,
            fields = {
                timeoutMs = {
                    type = 'number',
                    required = true,
                    default = 10000,
                    min = 100,
                    max = 120000,
                    public = false,
                    serverOnly = true
                },
                slowQueryMs = {
                    type = 'number',
                    required = true,
                    default = 500,
                    min = 0,
                    max = 60000,
                    public = false,
                    serverOnly = true
                },
                retry = {
                    type = 'object',
                    required = true,
                    public = false,
                    serverOnly = true,
                    fields = {
                        maxAttempts = {
                            type = 'number',
                            required = true,
                            default = 2,
                            min = 1,
                            max = 5,
                            public = false,
                            serverOnly = true
                        },
                        delayMs = {
                            type = 'number',
                            required = true,
                            default = 100,
                            min = 0,
                            max = 5000,
                            public = false,
                            serverOnly = true
                        }
                    }
                }
            }
        },
        logging = {
            type = 'object',
            required = true,
            public = true,
            fields = {
                level = {
                    type = 'string',
                    required = true,
                    default = 'info',
                    allowed = { 'debug', 'info', 'warn', 'error', 'audit', 'security' },
                    public = true
                }
            }
        },
        validation = {
            type = 'object',
            required = true,
            public = false,
            fields = {
                unknownFields = {
                    type = 'string',
                    required = true,
                    default = 'warn',
                    allowed = { 'warn', 'error', 'ignore' },
                    public = false,
                    serverOnly = true
                }
            }
        },
        server = {
            type = 'object',
            required = false,
            public = false,
            serverOnly = true,
            fields = {
                secrets = {
                    type = 'object',
                    required = false,
                    public = false,
                    serverOnly = true,
                    fields = {
                        bootstrapToken = {
                            type = 'string',
                            required = false,
                            default = '',
                            public = false,
                            serverOnly = true,
                            secret = true
                        }
                    }
                }
            }
        }
    }
}

local defaults = {
    debug = false,
    environment = 'development',
    defaultPermissionRole = 'user',
    identifierPriority = { 'license', 'license2', 'fivem', 'steam', 'discord' },
    character = {
        maxPerPlayer = 4,
        minNameLength = 2,
        maxNameLength = 32,
        minBirthYear = 1900,
        maxBirthYear = 2010
    },
    callbacks = {
        defaultCooldownMs = 1000,
        timeoutMs = 10000
    },
    database = {
        timeoutMs = 10000,
        slowQueryMs = 500,
        retry = {
            maxAttempts = 2,
            delayMs = 100
        }
    },
    logging = {
        level = 'info'
    },
    validation = {
        unknownFields = 'warn'
    }
}

local environmentOverrides = {
    production = {
        debug = false,
        logging = {
            level = 'info'
        }
    },
    test = {
        callbacks = {
            defaultCooldownMs = 0,
            timeoutMs = 1000
        }
    }
}

local environment = getConvarValue('nexa:environment', defaults.environment)
local runtimeConfig = {
    debug = getConvarBool('nexa:debug', defaults.debug),
    environment = environment,
    character = {
        maxPerPlayer = getConvarInt('nexa:maxCharacters', defaults.character.maxPerPlayer)
    },
    logging = {
        level = getConvarValue('nexa:logLevel', getConvarBool('nexa:debug', defaults.debug) and 'debug' or defaults.logging.level)
    },
    database = {
        timeoutMs = getConvarInt('nexa:dbTimeoutMs', defaults.database.timeoutMs),
        slowQueryMs = getConvarInt('nexa:dbSlowQueryMs', defaults.database.slowQueryMs),
        retry = {
            maxAttempts = getConvarInt('nexa:dbRetryMaxAttempts', defaults.database.retry.maxAttempts),
            delayMs = getConvarInt('nexa:dbRetryDelayMs', defaults.database.retry.delayMs)
        }
    },
    validation = {
        unknownFields = getConvarValue('nexa:configUnknownFields', defaults.validation.unknownFields)
    }
}

if IS_SERVER then
    runtimeConfig.server = {
        secrets = {
            bootstrapToken = getConvarValue('nexa:bootstrapToken', '')
        }
    }
end

local rawConfig = deepMerge(defaults, environmentOverrides[environment] or {})
rawConfig = deepMerge(rawConfig, runtimeConfig)

local function addIssue(target, path, code, message)
    target[#target + 1] = {
        path = path,
        code = code,
        message = message
    }
end

local function typeMatches(value, expectedType)
    if expectedType == 'array' then
        if type(value) ~= 'table' then
            return false
        end

        local count = 0

        for key in pairs(value) do
            if type(key) ~= 'number' then
                return false
            end

            count = count + 1
        end

        return count == #value
    end

    return type(value) == expectedType
end

local function isAllowed(value, allowed)
    if type(allowed) ~= 'table' then
        return true
    end

    for _, allowedValue in ipairs(allowed) do
        if value == allowedValue then
            return true
        end
    end

    return false
end

local function validateNode(value, nodeSchema, path, options, errors, warnings)
    if value == nil then
        if nodeSchema.required then
            addIssue(errors, path, 'REQUIRED', 'Pflichtwert fehlt.')
        end

        return
    end

    if nodeSchema.serverOnly and not IS_SERVER then
        return
    end

    if not typeMatches(value, nodeSchema.type) then
        addIssue(errors, path, 'TYPE', ('Erwartet %s, erhalten %s.'):format(nodeSchema.type, type(value)))
        return
    end

    if nodeSchema.allowed and not isAllowed(value, nodeSchema.allowed) then
        addIssue(errors, path, 'ALLOWED', 'Wert ist nicht erlaubt.')
    end

    if nodeSchema.type == 'number' then
        if nodeSchema.min and value < nodeSchema.min then
            addIssue(errors, path, 'MIN', ('Wert muss mindestens %s sein.'):format(nodeSchema.min))
        end

        if nodeSchema.max and value > nodeSchema.max then
            addIssue(errors, path, 'MAX', ('Wert darf hoechstens %s sein.'):format(nodeSchema.max))
        end
    end

    if nodeSchema.type == 'array' then
        if nodeSchema.minItems and #value < nodeSchema.minItems then
            addIssue(errors, path, 'MIN_ITEMS', ('Liste braucht mindestens %s Eintraege.'):format(nodeSchema.minItems))
        end

        if nodeSchema.itemType then
            for index, item in ipairs(value) do
                if type(item) ~= nodeSchema.itemType then
                    addIssue(errors, ('%s.%s'):format(path, index), 'ITEM_TYPE', ('Listeneintrag muss %s sein.'):format(nodeSchema.itemType))
                end
            end
        end
    end

    if nodeSchema.type ~= 'object' then
        return
    end

    local fields = nodeSchema.fields or {}

    for fieldName, fieldSchema in pairs(fields) do
        validateNode(value[fieldName], fieldSchema, path == '' and fieldName or ('%s.%s'):format(path, fieldName), options, errors, warnings)
    end

    for fieldName in pairs(value) do
        if not fields[fieldName] then
            local mode = options.unknownFields or 'warn'
            local issueTarget = mode == 'error' and errors or warnings

            if mode ~= 'ignore' then
                addIssue(issueTarget, path == '' and fieldName or ('%s.%s'):format(path, fieldName), 'UNKNOWN_FIELD', 'Unbekanntes Konfigurationsfeld.')
            end
        end
    end
end

local function validateSnapshot(snapshot, options)
    local errors = {}
    local warnings = {}
    options = options or {}
    options.unknownFields = options.unknownFields or getPathValue(snapshot, 'validation.unknownFields') or defaults.validation.unknownFields

    validateNode(snapshot, schema, '', options, errors, warnings)

    local minNameLength = getPathValue(snapshot, 'character.minNameLength')
    local maxNameLength = getPathValue(snapshot, 'character.maxNameLength')

    if minNameLength and maxNameLength and minNameLength > maxNameLength then
        addIssue(errors, 'character', 'RANGE', 'minNameLength darf nicht groesser als maxNameLength sein.')
    end

    local minBirthYear = getPathValue(snapshot, 'character.minBirthYear')
    local maxBirthYear = getPathValue(snapshot, 'character.maxBirthYear')

    if minBirthYear and maxBirthYear and minBirthYear > maxBirthYear then
        addIssue(errors, 'character', 'RANGE', 'minBirthYear darf nicht groesser als maxBirthYear sein.')
    end

    return #errors == 0, errors, warnings
end

local function makePublicSnapshot(snapshot, nodeSchema)
    if nodeSchema.secret or nodeSchema.serverOnly or nodeSchema.public == false then
        return nil
    end

    if nodeSchema.type ~= 'object' then
        return copyPublicValue(snapshot)
    end

    local output = {}

    for fieldName, fieldSchema in pairs(nodeSchema.fields or {}) do
        if snapshot[fieldName] ~= nil then
            local publicValue = makePublicSnapshot(snapshot[fieldName], fieldSchema)

            if publicValue ~= nil then
                output[fieldName] = publicValue
            end
        end
    end

    return output
end

local function removeServerOnlyValues(snapshot, nodeSchema)
    if IS_SERVER or type(snapshot) ~= 'table' or type(nodeSchema) ~= 'table' then
        return snapshot
    end

    local output = {}

    for fieldName, value in pairs(snapshot) do
        local fieldSchema = nodeSchema.fields and nodeSchema.fields[fieldName] or nil

        if not fieldSchema or not fieldSchema.serverOnly then
            if fieldSchema and fieldSchema.type == 'object' then
                output[fieldName] = removeServerOnlyValues(value, fieldSchema)
            else
                output[fieldName] = deepClone(value)
            end
        end
    end

    return output
end

rawConfig = removeServerOnlyValues(rawConfig, schema)

local validationOk, validationErrors, validationWarnings = validateSnapshot(rawConfig)
local frozenSnapshot = freeze(deepClone(rawConfig))
local publicSnapshot = freeze(makePublicSnapshot(rawConfig, schema) or {})

local Config = {
    _schema = freeze(deepClone(schema)),
    _raw = frozenSnapshot,
    _public = publicSnapshot,
    _validation = freeze({
        ok = validationOk,
        errors = validationErrors,
        warnings = validationWarnings
    })
}

function Config.Get(path, defaultValue)
    local value, exists = getPathValue(Config._raw, path)

    if not exists then
        return defaultValue
    end

    return value
end

function Config.Has(path)
    local _, exists = getPathValue(Config._raw, path)
    return exists
end

function Config.GetSection(path)
    local value, exists = getPathValue(Config._raw, path)

    if not exists or type(value) ~= 'table' then
        return nil
    end

    return value
end

function Config.Validate()
    return Config._validation.ok, deepClone(Config._validation.errors), deepClone(Config._validation.warnings)
end

function Config.GetEnvironment()
    return Config.Get('environment', defaults.environment)
end

function Config.GetPublicSnapshot()
    return Config._public
end

function Config._ValidateSnapshot(snapshot, options)
    return validateSnapshot(snapshot, options)
end

for key, value in pairs(frozenSnapshot) do
    Config[key] = value
end

NexaConfig = freeze(Config)
