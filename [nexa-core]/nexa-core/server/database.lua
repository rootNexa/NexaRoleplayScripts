Nexa.Database = {
    ready = false,
    migrations = {},
    health = {
        ready = false,
        lastCheckAt = nil,
        lastSuccessAt = nil,
        lastError = nil,
        totalQueries = 0,
        failedQueries = 0,
        slowQueries = 0,
        retriedQueries = 0,
        migrations = {
            applied = 0,
            failed = 0
        }
    }
}

local ERROR_CODES = {
    invalidInput = 'DB_INVALID_INPUT',
    timeout = 'DB_TIMEOUT',
    unavailable = 'DB_UNAVAILABLE',
    queryFailed = 'DB_QUERY_FAILED',
    transactionFailed = 'DB_TRANSACTION_FAILED',
    migrationFailed = 'DB_MIGRATION_FAILED',
    checksumMismatch = 'DB_MIGRATION_CHECKSUM_MISMATCH'
}

local function nowMs()
    if GetGameTimer then
        return GetGameTimer()
    end

    return math.floor(os.clock() * 1000)
end

local function canAwaitPromise()
    return promise ~= nil and Citizen ~= nil and Citizen.Await ~= nil
end

local function sleep(ms)
    if Wait then
        Wait(ms)
    end
end

local function getConfig(path, defaultValue)
    if Nexa.Config and Nexa.Config.Get then
        return Nexa.Config.Get(path, defaultValue)
    end

    return defaultValue
end

local function dbLog(level, category, message, context)
    if Nexa.Logger and Nexa.Logger[level] then
        Nexa.Logger[level](category, message, context)
        return
    end

    if Nexa.Log then
        Nexa.Log(level:lower(), message, context)
    end
end

local function makeError(code, message, category, details)
    return {
        code = code,
        message = message,
        category = category or 'database',
        retryable = details and details.retryable == true or false,
        details = details and details.public or nil
    }
end

local function normalizeSql(sql)
    if type(sql) ~= 'string' or sql:gsub('%s+', '') == '' then
        return nil, makeError(ERROR_CODES.invalidInput, 'SQL muss ein nicht leerer String sein.', 'database.validation')
    end

    return sql, nil
end

local function validateParams(params)
    if params == nil then
        return {}, nil
    end

    if type(params) ~= 'table' then
        return nil, makeError(ERROR_CODES.invalidInput, 'Query-Parameter muessen eine Tabelle sein.', 'database.validation')
    end

    for key, value in pairs(params) do
        local valueType = type(value)

        if valueType == 'function' or valueType == 'thread' or valueType == 'userdata' then
            return nil, makeError(ERROR_CODES.invalidInput, 'Query-Parameter enthalten einen nicht serialisierbaren Wert.', 'database.validation', {
                public = {
                    key = tostring(key),
                    valueType = valueType
                }
            })
        end
    end

    return params, nil
end

local function validateIdentifiers(options)
    if type(options) ~= 'table' or options.identifier == nil then
        return nil
    end

    local identifier = options.identifier
    local whitelist = options.identifierWhitelist

    if type(identifier) ~= 'string' or type(whitelist) ~= 'table' then
        return makeError(ERROR_CODES.invalidInput, 'Dynamische Identifier brauchen eine Whitelist.', 'database.validation')
    end

    for _, allowedIdentifier in ipairs(whitelist) do
        if identifier == allowedIdentifier then
            return nil
        end
    end

    return makeError(ERROR_CODES.invalidInput, 'Dynamischer Identifier ist nicht erlaubt.', 'database.validation')
end

local function isRetryableError(rawError)
    if rawError == nil then
        return false
    end

    local text = tostring(rawError):lower()
    return text:find('deadlock', 1, true)
        or text:find('lock wait timeout', 1, true)
        or text:find('server has gone away', 1, true)
        or text:find('lost connection', 1, true)
        or text:find('connection refused', 1, true)
end

local function mapQueryKind(kind)
    if kind == 'delete' then
        return 'update'
    end

    return kind
end

local function callOxmysql(kind, sql, params, timeoutMs)
    local methodName = mapQueryKind(kind)
    local method = MySQL and MySQL[methodName]

    if not method then
        return nil, makeError(ERROR_CODES.unavailable, 'oxmysql Methode ist nicht verfuegbar.', 'database.health')
    end

    if canAwaitPromise() and type(method) == 'function' then
        local pending = promise.new()
        local completed = false

        if SetTimeout then
            SetTimeout(timeoutMs, function()
                if completed then
                    return
                end

                completed = true
                pending:resolve({
                    timeout = true
                })
            end)
        end

        local ok, callErr = pcall(function()
            method(sql, params, function(result)
                if completed then
                    return
                end

                completed = true
                pending:resolve({
                    result = result
                })
            end)
        end)

        if not ok then
            completed = true
            return nil, makeError(ERROR_CODES.queryFailed, 'Datenbankabfrage konnte nicht gestartet werden.', 'database.query', {
                retryable = isRetryableError(callErr)
            })
        end

        local response = Citizen.Await(pending)

        if response and response.timeout then
            return nil, makeError(ERROR_CODES.timeout, 'Datenbankabfrage hat das Zeitlimit erreicht.', 'database.timeout', {
                retryable = false
            })
        end

        return response and response.result or nil, nil
    end

    local awaitMethod = method.await

    if not awaitMethod then
        return nil, makeError(ERROR_CODES.unavailable, 'oxmysql Await-Methode ist nicht verfuegbar.', 'database.health')
    end

    local startedAt = nowMs()
    local ok, result = pcall(awaitMethod, sql, params)

    if not ok then
        return nil, makeError(ERROR_CODES.queryFailed, 'Datenbankabfrage fehlgeschlagen.', 'database.query', {
            retryable = isRetryableError(result)
        })
    end

    if nowMs() - startedAt > timeoutMs then
        return nil, makeError(ERROR_CODES.timeout, 'Datenbankabfrage hat das Zeitlimit ueberschritten.', 'database.timeout')
    end

    return result, nil
end

local function logSlowQuery(category, elapsedMs, options)
    local slowQueryMs = options.slowQueryMs

    if slowQueryMs == nil then
        slowQueryMs = getConfig('database.slowQueryMs', 500)
    end

    if slowQueryMs > 0 and elapsedMs >= slowQueryMs then
        Nexa.Database.health.slowQueries = Nexa.Database.health.slowQueries + 1
        dbLog('Warn', 'database.slow_query', 'Langsame Datenbankabfrage.', {
            category = category,
            elapsedMs = elapsedMs,
            slowQueryMs = slowQueryMs
        })
    end
end

local function run(kind, sql, params, options)
    options = options or {}
    local category = options.category or ('database.%s'):format(kind)
    local normalizedSql, sqlErr = normalizeSql(sql)

    if sqlErr then
        return nil, sqlErr
    end

    local normalizedParams, paramsErr = validateParams(params)

    if paramsErr then
        return nil, paramsErr
    end

    local identifierErr = validateIdentifiers(options)

    if identifierErr then
        return nil, identifierErr
    end

    local timeoutMs = tonumber(options.timeoutMs) or getConfig('database.timeoutMs', 10000)
    local maxAttempts = tonumber(options.retries) or getConfig('database.retry.maxAttempts', 2)
    local retryDelayMs = tonumber(options.retryDelayMs) or getConfig('database.retry.delayMs', 100)
    local startedAt = nowMs()
    local attempt = 0
    local result, err

    repeat
        attempt = attempt + 1
        Nexa.Database.health.totalQueries = Nexa.Database.health.totalQueries + 1
        result, err = callOxmysql(kind, normalizedSql, normalizedParams, timeoutMs)

        if not err then
            local elapsedMs = nowMs() - startedAt
            logSlowQuery(category, elapsedMs, options)
            return result, nil
        end

        if err.retryable and attempt < maxAttempts then
            Nexa.Database.health.retriedQueries = Nexa.Database.health.retriedQueries + 1
            sleep(retryDelayMs)
        else
            break
        end
    until false

    Nexa.Database.health.failedQueries = Nexa.Database.health.failedQueries + 1
    Nexa.Database.health.lastError = err
    dbLog('Error', category, 'Datenbankoperation fehlgeschlagen.', {
        code = err.code,
        message = err.message,
        retryable = err.retryable,
        attempts = attempt
    })

    return nil, err
end

function Nexa.Database.Query(sql, params, options)
    return run('query', sql, params, options)
end

function Nexa.Database.Single(sql, params, options)
    local rows, err = Nexa.Database.Query(sql, params, options)

    if err then
        return nil, err
    end

    return rows and rows[1] or nil, nil
end

function Nexa.Database.Scalar(sql, params, options)
    return run('scalar', sql, params, options)
end

function Nexa.Database.Insert(sql, params, options)
    return run('insert', sql, params, options)
end

function Nexa.Database.Update(sql, params, options)
    return run('update', sql, params, options)
end

function Nexa.Database.Delete(sql, params, options)
    return run('delete', sql, params, options)
end

function Nexa.Database.Transaction(queries, options)
    options = options or {}

    if type(queries) ~= 'table' or #queries == 0 then
        return false, makeError(ERROR_CODES.invalidInput, 'Transaktion braucht mindestens eine Query.', 'database.transaction')
    end

    local normalizedQueries = {}

    for index, query in ipairs(queries) do
        if type(query) == 'table' then
            local sql, sqlErr = normalizeSql(query.query or query.sql)

            if sqlErr then
                return false, sqlErr
            end

            local params, paramsErr = validateParams(query.params or query.parameters or {})

            if paramsErr then
                return false, paramsErr
            end

            normalizedQueries[#normalizedQueries + 1] = {
                query = sql,
                params = params
            }
        elseif type(query) ~= 'string' then
            return false, makeError(ERROR_CODES.invalidInput, 'Transaktionsqueries muessen Strings oder Tabellen sein.', 'database.transaction', {
                public = {
                    index = index
                }
            })
        else
            normalizedQueries[#normalizedQueries + 1] = query
        end
    end

    local timeoutMs = tonumber(options.timeoutMs) or getConfig('database.timeoutMs', 10000)
    local startedAt = nowMs()
    local ok, result, resultErr = pcall(function()
        if canAwaitPromise() and type(MySQL.transaction) == 'function' then
            local pending = promise.new()
            local completed = false

            if SetTimeout then
                SetTimeout(timeoutMs, function()
                    if completed then
                        return
                    end

                    completed = true

                    local timeoutResponse = {
                        timeout = true
                    }

                    pending:resolve(timeoutResponse)
                end)
            end

            MySQL.transaction(normalizedQueries, function(success)
                if completed then
                    return
                end

                completed = true

                local transactionResponse = {
                    success = success
                }

                pending:resolve(transactionResponse)
            end)

            local response = Citizen.Await(pending)

            if response and response.timeout then
                return nil, makeError(ERROR_CODES.timeout, 'Datenbanktransaktion hat das Zeitlimit erreicht.', 'database.timeout')
            end

            return response and response.success == true, nil
        end

        return MySQL.transaction.await(normalizedQueries), nil
    end)

    if not ok then
        local err = makeError(ERROR_CODES.transactionFailed, 'Datenbanktransaktion fehlgeschlagen.', 'database.transaction', {
            retryable = isRetryableError(result)
        })
        Nexa.Database.health.failedQueries = Nexa.Database.health.failedQueries + 1
        Nexa.Database.health.lastError = err
        return false, err
    end

    local success, err = result, resultErr

    if type(result) == 'table' then
        success = result[1]
        err = result[2]
    end

    if err then
        Nexa.Database.health.failedQueries = Nexa.Database.health.failedQueries + 1
        Nexa.Database.health.lastError = err
        return false, err
    end

    if success ~= true then
        local txErr = makeError(ERROR_CODES.transactionFailed, 'Datenbanktransaktion wurde zurueckgerollt.', 'database.transaction')
        Nexa.Database.health.failedQueries = Nexa.Database.health.failedQueries + 1
        Nexa.Database.health.lastError = txErr
        return false, txErr
    end

    logSlowQuery(options.category or 'database.transaction', nowMs() - startedAt, options)
    return true, nil
end

function Nexa.Database.IsReady()
    return Nexa.Database.ready == true
end

function Nexa.Database.GetHealth()
    local health = {}

    for key, value in pairs(Nexa.Database.health) do
        if type(value) == 'table' then
            local nested = {}

            for nestedKey, nestedValue in pairs(value) do
                nested[nestedKey] = nestedValue
            end

            health[key] = nested
        else
            health[key] = value
        end
    end

    health.ready = Nexa.Database.ready == true
    return health
end

function Nexa.Database.FetchOne(sql, params, options)
    return Nexa.Database.Single(sql, params, options)
end

function Nexa.Database.FetchAll(sql, params, options)
    return Nexa.Database.Query(sql, params, options)
end

function Nexa.Database.Execute(sql, params, options)
    return Nexa.Database.Query(sql, params, options)
end

function Nexa.Database.CheckReady()
    Nexa.Database.health.lastCheckAt = os.time()
    local result, err = Nexa.Database.Scalar('SELECT 1', {}, {
        category = 'database.health',
        retries = 1
    })

    Nexa.Database.ready = result == 1
    Nexa.Database.health.ready = Nexa.Database.ready

    if Nexa.Database.ready then
        Nexa.Database.health.lastSuccessAt = os.time()
        Nexa.Database.health.lastError = nil
        return true
    end

    Nexa.Database.health.lastError = err
    return false
end

local function checksum(value)
    local hash = 5381

    for index = 1, #value do
        hash = ((hash * 33) + value:byte(index)) % 4294967296
    end

    return tostring(hash)
end

local function migrationContent(migration)
    local parts = {
        migration.id,
        migration.description or ''
    }

    for _, statement in ipairs(migration.statements or {}) do
        parts[#parts + 1] = statement
    end

    return table.concat(parts, '\n')
end

function Nexa.Database.RegisterMigration(migration)
    if type(migration) ~= 'table' or type(migration.id) ~= 'string' or migration.id == '' or type(migration.statements) ~= 'table' or #migration.statements == 0 then
        return false, makeError(ERROR_CODES.invalidInput, 'Migration ist ungueltig.', 'database.migration')
    end

    migration.checksum = migration.checksum or checksum(migrationContent(migration))
    Nexa.Database.migrations[#Nexa.Database.migrations + 1] = migration
    table.sort(Nexa.Database.migrations, function(left, right)
        return left.id < right.id
    end)
    return true, nil
end

local function ensureMigrationTable()
    return Nexa.Database.Query([[
        CREATE TABLE IF NOT EXISTS nexa_core_migrations (
            id VARCHAR(128) NOT NULL,
            description VARCHAR(255) NOT NULL,
            checksum VARCHAR(64) NOT NULL,
            status VARCHAR(32) NOT NULL,
            executed_at TIMESTAMP NULL DEFAULT NULL,
            error_message TEXT NULL,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], {}, {
        category = 'database.migration'
    })
end

local function findAppliedMigration(id)
    return Nexa.Database.Single([[
        SELECT id, description, checksum, status, executed_at
        FROM nexa_core_migrations
        WHERE id = ?
        LIMIT 1
    ]], { id }, {
        category = 'database.migration'
    })
end

local function markMigration(migration, status, errorMessage)
    return Nexa.Database.Update([[
        INSERT INTO nexa_core_migrations (id, description, checksum, status, executed_at, error_message)
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, ?)
        ON DUPLICATE KEY UPDATE
            description = VALUES(description),
            checksum = VALUES(checksum),
            status = VALUES(status),
            executed_at = VALUES(executed_at),
            error_message = VALUES(error_message)
    ]], {
        migration.id,
        migration.description or '',
        migration.checksum,
        status,
        errorMessage
    }, {
        category = 'database.migration'
    })
end

local function applyMigration(migration)
    local applied, findErr = findAppliedMigration(migration.id)

    if findErr then
        return false, findErr
    end

    if applied and applied.status == 'applied' then
        if applied.checksum ~= migration.checksum then
            return false, makeError(ERROR_CODES.checksumMismatch, 'Angewendete Migration wurde nachtraeglich veraendert.', 'database.migration', {
                public = {
                    id = migration.id
                }
            })
        end

        return true, nil, true
    end

    local canUseTransaction = migration.transaction ~= false

    if canUseTransaction then
        local queries = {}

        for _, statement in ipairs(migration.statements) do
            queries[#queries + 1] = {
                query = statement,
                params = {}
            }
        end

        local ok, err = Nexa.Database.Transaction(queries, {
            category = 'database.migration',
            retries = 1
        })

        if not ok then
            markMigration(migration, 'failed', err and err.message or 'Migration fehlgeschlagen.')
            return false, makeError(ERROR_CODES.migrationFailed, 'Migration fehlgeschlagen.', 'database.migration', {
                public = {
                    id = migration.id
                }
            })
        end
    else
        for _, statement in ipairs(migration.statements) do
            local _, err = Nexa.Database.Query(statement, {}, {
                category = 'database.migration',
                retries = 1
            })

            if err then
                markMigration(migration, 'failed', err.message)
                return false, makeError(ERROR_CODES.migrationFailed, 'Migration fehlgeschlagen.', 'database.migration', {
                    public = {
                        id = migration.id
                    }
                })
            end
        end
    end

    local _, markErr = markMigration(migration, 'applied', nil)

    if markErr then
        return false, markErr
    end

    Nexa.Database.health.migrations.applied = Nexa.Database.health.migrations.applied + 1
    return true, nil, false
end

function Nexa.Database.RunMigrations()
    local _, tableErr = ensureMigrationTable()

    if tableErr then
        return false, tableErr
    end

    for _, migration in ipairs(Nexa.Database.migrations) do
        local ok, err = applyMigration(migration)

        if not ok then
            Nexa.Database.health.migrations.failed = Nexa.Database.health.migrations.failed + 1
            Nexa.Database.health.lastError = err
            return false, err
        end
    end

    return true, nil
end

Nexa.Database.RegisterMigration({
    id = '001_foundation',
    description = 'Create core foundation tables',
    transaction = false,
    statements = {
        [[
            CREATE TABLE IF NOT EXISTS nexa_players (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                identifier VARCHAR(128) NOT NULL,
                identifier_type VARCHAR(32) NOT NULL,
                display_name VARCHAR(64) NOT NULL,
                last_seen_at TIMESTAMP NULL DEFAULT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_nexa_players_identifier (identifier),
                KEY idx_nexa_players_identifier_type (identifier_type),
                KEY idx_nexa_players_last_seen_at (last_seen_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS nexa_characters (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                player_id BIGINT UNSIGNED NOT NULL,
                first_name VARCHAR(32) NOT NULL,
                last_name VARCHAR(32) NOT NULL,
                birthdate DATE NOT NULL,
                gender ENUM('male', 'female', 'diverse', 'unknown') NOT NULL DEFAULT 'unknown',
                metadata JSON NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                deleted_at TIMESTAMP NULL DEFAULT NULL,
                PRIMARY KEY (id),
                KEY idx_nexa_characters_player_id (player_id),
                KEY idx_nexa_characters_name (last_name, first_name),
                KEY idx_nexa_characters_deleted_at (deleted_at),
                CONSTRAINT fk_nexa_characters_player
                    FOREIGN KEY (player_id) REFERENCES nexa_players (id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS nexa_permissions (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                player_id BIGINT UNSIGNED NOT NULL,
                permission VARCHAR(96) NOT NULL,
                value TINYINT(1) NOT NULL DEFAULT 1,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_nexa_permissions_player_permission (player_id, permission),
                KEY idx_nexa_permissions_permission (permission),
                CONSTRAINT fk_nexa_permissions_player
                    FOREIGN KEY (player_id) REFERENCES nexa_players (id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS nexa_audit_log (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                action VARCHAR(96) NOT NULL,
                actor_source INT NULL,
                player_id BIGINT UNSIGNED NULL,
                character_id BIGINT UNSIGNED NULL,
                resource VARCHAR(64) NOT NULL,
                context JSON NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY idx_nexa_audit_log_action (action),
                KEY idx_nexa_audit_log_player_id (player_id),
                KEY idx_nexa_audit_log_character_id (character_id),
                KEY idx_nexa_audit_log_created_at (created_at),
                CONSTRAINT fk_nexa_audit_log_player
                    FOREIGN KEY (player_id) REFERENCES nexa_players (id)
                    ON DELETE SET NULL,
                CONSTRAINT fk_nexa_audit_log_character
                    FOREIGN KEY (character_id) REFERENCES nexa_characters (id)
                    ON DELETE SET NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]
    }
})
