NexaEconomyDatabase = {}

local function getCoreDatabase()
    if GetResourceState('nexa-core') ~= 'started' then
        return nil
    end

    local ok, core = pcall(function()
        return exports['nexa-core']:GetCoreObject()
    end)

    if not ok or not core or not core.Database then
        return nil
    end

    return core.Database
end

local function encode(value)
    local ok, encoded = pcall(json.encode, value or {})
    return ok and encoded or '{}'
end

local function db()
    return getCoreDatabase()
end

function NexaEconomyDatabase.Migrate()
    local database = db()

    if not database or not database.RegisterMigration then
        return false, 'Core database is not ready.'
    end

    database.RegisterMigration({
        id = '080_economy_foundation',
        description = 'Create Nexa economy accounts ledger transactions reservations and sagas.',
        transaction = false,
        up = function()
            database.Query([[
                CREATE TABLE IF NOT EXISTS nexa_economy_accounts (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    account_key VARCHAR(96) UNIQUE NOT NULL,
                    owner_type VARCHAR(32) NOT NULL,
                    owner_id VARCHAR(64) NOT NULL,
                    account_type VARCHAR(32) NOT NULL,
                    currency VARCHAR(32) NOT NULL DEFAULT 'bank',
                    label VARCHAR(128) NULL,
                    balance BIGINT NOT NULL DEFAULT 0,
                    reserved_balance BIGINT NOT NULL DEFAULT 0,
                    status VARCHAR(32) NOT NULL DEFAULT 'active',
                    metadata_json LONGTEXT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    INDEX idx_economy_accounts_owner (owner_type, owner_id),
                    INDEX idx_economy_accounts_type (account_type),
                    INDEX idx_economy_accounts_status (status)
                )
            ]], {}, { category = 'economy.migration.accounts' })

            database.Query([[
                CREATE TABLE IF NOT EXISTS nexa_economy_transactions (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    transaction_key VARCHAR(128) UNIQUE NOT NULL,
                    transaction_type VARCHAR(32) NOT NULL,
                    status VARCHAR(32) NOT NULL,
                    source_account_id INT NULL,
                    target_account_id INT NULL,
                    amount BIGINT NOT NULL,
                    currency VARCHAR(32) NOT NULL DEFAULT 'bank',
                    idempotency_key VARCHAR(128) NULL,
                    reason VARCHAR(255) NULL,
                    metadata_json LONGTEXT NULL,
                    error_code VARCHAR(64) NULL,
                    correlation_id VARCHAR(128) NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    UNIQUE KEY uq_economy_transactions_idempotency (idempotency_key),
                    INDEX idx_economy_transactions_source (source_account_id),
                    INDEX idx_economy_transactions_target (target_account_id),
                    INDEX idx_economy_transactions_status (status)
                )
            ]], {}, { category = 'economy.migration.transactions' })

            database.Query([[
                CREATE TABLE IF NOT EXISTS nexa_economy_ledger (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    transaction_id INT NOT NULL,
                    account_id INT NOT NULL,
                    entry_type VARCHAR(32) NOT NULL,
                    amount BIGINT NOT NULL,
                    balance_before BIGINT NOT NULL,
                    balance_after BIGINT NOT NULL,
                    reserved_before BIGINT NOT NULL DEFAULT 0,
                    reserved_after BIGINT NOT NULL DEFAULT 0,
                    currency VARCHAR(32) NOT NULL DEFAULT 'bank',
                    category VARCHAR(64) NULL,
                    reason VARCHAR(255) NULL,
                    correlation_id VARCHAR(128) NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    INDEX idx_economy_ledger_transaction (transaction_id),
                    INDEX idx_economy_ledger_account (account_id)
                )
            ]], {}, { category = 'economy.migration.ledger' })

            database.Query([[
                CREATE TABLE IF NOT EXISTS nexa_economy_reservations (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    reservation_key VARCHAR(128) UNIQUE NOT NULL,
                    account_id INT NOT NULL,
                    amount BIGINT NOT NULL,
                    currency VARCHAR(32) NOT NULL DEFAULT 'bank',
                    status VARCHAR(32) NOT NULL,
                    reason VARCHAR(255) NULL,
                    expires_at TIMESTAMP NULL,
                    captured_transaction_id INT NULL,
                    released_transaction_id INT NULL,
                    metadata_json LONGTEXT NULL,
                    correlation_id VARCHAR(128) NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    INDEX idx_economy_reservations_account (account_id),
                    INDEX idx_economy_reservations_status (status)
                )
            ]], {}, { category = 'economy.migration.reservations' })

            database.Query([[
                CREATE TABLE IF NOT EXISTS nexa_economy_audit (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    action VARCHAR(64) NOT NULL,
                    actor_source INT NULL,
                    actor_character_id INT NULL,
                    account_id INT NULL,
                    amount BIGINT NULL,
                    result VARCHAR(32) NOT NULL,
                    error_code VARCHAR(64) NULL,
                    reason VARCHAR(255) NULL,
                    metadata_json LONGTEXT NULL,
                    correlation_id VARCHAR(128) NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    INDEX idx_economy_audit_action (action),
                    INDEX idx_economy_audit_account (account_id)
                )
            ]], {}, { category = 'economy.migration.audit' })

            database.Query([[
                CREATE TABLE IF NOT EXISTS nexa_economy_sagas (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    saga_key VARCHAR(128) UNIQUE NOT NULL,
                    saga_type VARCHAR(64) NOT NULL,
                    status VARCHAR(32) NOT NULL,
                    source VARCHAR(64) NULL,
                    metadata_json LONGTEXT NULL,
                    error_code VARCHAR(64) NULL,
                    correlation_id VARCHAR(128) NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
                )
            ]], {}, { category = 'economy.migration.sagas' })

            database.Query([[
                CREATE TABLE IF NOT EXISTS nexa_economy_saga_steps (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    saga_id INT NOT NULL,
                    step_name VARCHAR(64) NOT NULL,
                    status VARCHAR(32) NOT NULL,
                    metadata_json LONGTEXT NULL,
                    error_code VARCHAR(64) NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    INDEX idx_economy_saga_steps_saga (saga_id)
                )
            ]], {}, { category = 'economy.migration.saga_steps' })

            return true
        end
    })

    return database.RunMigrations()
end

local function single(sql, params, category)
    local database = db()
    if not database then
        return nil, { code = NEXA_ECONOMY_ERRORS.databaseError, message = 'Core database unavailable.' }
    end
    return database.Single(sql, params or {}, { category = category or 'economy.single' })
end

local function query(sql, params, category)
    local database = db()
    if not database then
        return nil, { code = NEXA_ECONOMY_ERRORS.databaseError, message = 'Core database unavailable.' }
    end
    return database.Query(sql, params or {}, { category = category or 'economy.query' })
end

local function insert(sql, params, category)
    local database = db()
    if not database then
        return nil, { code = NEXA_ECONOMY_ERRORS.databaseError, message = 'Core database unavailable.' }
    end
    return database.Insert(sql, params or {}, { category = category or 'economy.insert' })
end

local function update(sql, params, category)
    local database = db()
    if not database then
        return nil, { code = NEXA_ECONOMY_ERRORS.databaseError, message = 'Core database unavailable.' }
    end
    return database.Update(sql, params or {}, { category = category or 'economy.update' })
end

function NexaEconomyDatabase.Transaction(queries, options)
    local database = db()
    if not database or not database.Transaction then
        return nil, { code = NEXA_ECONOMY_ERRORS.databaseError, message = 'Core database transaction unavailable.' }
    end
    return database.Transaction(queries, options or { category = 'economy.transaction' })
end

function NexaEconomyDatabase.InsertAccount(payload)
    return insert([[
        INSERT INTO nexa_economy_accounts
            (account_key, owner_type, owner_id, account_type, currency, label, balance, reserved_balance, status, metadata_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.account_key, payload.owner_type, payload.owner_id, payload.account_type, payload.currency,
        payload.label, payload.balance or 0, payload.reserved_balance or 0, payload.status, encode(payload.metadata)
    }, 'economy.accounts.insert')
end

function NexaEconomyDatabase.GetAccount(id)
    return single('SELECT * FROM nexa_economy_accounts WHERE id = ? LIMIT 1', { id }, 'economy.accounts.get')
end

function NexaEconomyDatabase.GetAccountByKey(accountKey)
    return single('SELECT * FROM nexa_economy_accounts WHERE account_key = ? LIMIT 1', { accountKey }, 'economy.accounts.get_key')
end

function NexaEconomyDatabase.GetAccountByOwner(ownerType, ownerId, accountType)
    return single([[
        SELECT * FROM nexa_economy_accounts
        WHERE owner_type = ? AND owner_id = ? AND account_type = ? LIMIT 1
    ]], { ownerType, ownerId, accountType }, 'economy.accounts.get_owner')
end

function NexaEconomyDatabase.UpdateBalances(accountId, balance, reservedBalance)
    return update([[
        UPDATE nexa_economy_accounts
        SET balance = ?, reserved_balance = ?
        WHERE id = ?
    ]], { balance, reservedBalance, accountId }, 'economy.accounts.update_balance')
end

function NexaEconomyDatabase.InsertTransaction(payload)
    return insert([[
        INSERT INTO nexa_economy_transactions
            (transaction_key, transaction_type, status, source_account_id, target_account_id, amount, currency,
             idempotency_key, reason, metadata_json, error_code, correlation_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.transaction_key, payload.transaction_type, payload.status, payload.source_account_id,
        payload.target_account_id, payload.amount, payload.currency, payload.idempotency_key, payload.reason,
        encode(payload.metadata), payload.error_code, payload.correlation_id
    }, 'economy.transactions.insert')
end

function NexaEconomyDatabase.GetTransaction(id)
    return single('SELECT * FROM nexa_economy_transactions WHERE id = ? LIMIT 1', { id }, 'economy.transactions.get')
end

function NexaEconomyDatabase.GetTransactionByIdempotency(idempotencyKey)
    return single('SELECT * FROM nexa_economy_transactions WHERE idempotency_key = ? LIMIT 1', { idempotencyKey }, 'economy.transactions.idempotency')
end

function NexaEconomyDatabase.UpdateTransactionStatus(id, status, errorCode)
    return update('UPDATE nexa_economy_transactions SET status = ?, error_code = ? WHERE id = ?', { status, errorCode, id }, 'economy.transactions.status')
end

function NexaEconomyDatabase.InsertLedger(payload)
    return insert([[
        INSERT INTO nexa_economy_ledger
            (transaction_id, account_id, entry_type, amount, balance_before, balance_after, reserved_before,
             reserved_after, currency, category, reason, correlation_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.transaction_id, payload.account_id, payload.entry_type, payload.amount, payload.balance_before,
        payload.balance_after, payload.reserved_before, payload.reserved_after, payload.currency, payload.category,
        payload.reason, payload.correlation_id
    }, 'economy.ledger.insert')
end

function NexaEconomyDatabase.GetLedger(accountId, limit)
    return query([[
        SELECT * FROM nexa_economy_ledger
        WHERE account_id = ?
        ORDER BY id DESC
        LIMIT ?
    ]], { accountId, limit or 100 }, 'economy.ledger.list')
end

function NexaEconomyDatabase.InsertReservation(payload)
    return insert([[
        INSERT INTO nexa_economy_reservations
            (reservation_key, account_id, amount, currency, status, reason, expires_at, metadata_json, correlation_id)
        VALUES (?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?), ?, ?)
    ]], {
        payload.reservation_key, payload.account_id, payload.amount, payload.currency, payload.status,
        payload.reason, payload.expires_at, encode(payload.metadata), payload.correlation_id
    }, 'economy.reservations.insert')
end

function NexaEconomyDatabase.GetReservation(id)
    return single('SELECT * FROM nexa_economy_reservations WHERE id = ? LIMIT 1', { id }, 'economy.reservations.get')
end

function NexaEconomyDatabase.UpdateReservationStatus(id, status, fields)
    fields = fields or {}
    return update([[
        UPDATE nexa_economy_reservations
        SET status = ?, captured_transaction_id = COALESCE(?, captured_transaction_id),
            released_transaction_id = COALESCE(?, released_transaction_id)
        WHERE id = ?
    ]], { status, fields.captured_transaction_id, fields.released_transaction_id, id }, 'economy.reservations.status')
end

function NexaEconomyDatabase.InsertAudit(payload)
    return insert([[
        INSERT INTO nexa_economy_audit
            (action, actor_source, actor_character_id, account_id, amount, result, error_code, reason, metadata_json, correlation_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.action, payload.actor_source, payload.actor_character_id, payload.account_id, payload.amount,
        payload.result, payload.error_code, payload.reason, encode(payload.metadata), payload.correlation_id
    }, 'economy.audit.insert')
end

function NexaEconomyDatabase.InsertSaga(payload)
    return insert([[
        INSERT INTO nexa_economy_sagas
            (saga_key, saga_type, status, source, metadata_json, error_code, correlation_id)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.saga_key, payload.saga_type, payload.status, payload.source, encode(payload.metadata),
        payload.error_code, payload.correlation_id
    }, 'economy.sagas.insert')
end

function NexaEconomyDatabase.UpdateSagaStatus(id, status, errorCode)
    return update('UPDATE nexa_economy_sagas SET status = ?, error_code = ? WHERE id = ?', { status, errorCode, id }, 'economy.sagas.status')
end

function NexaEconomyDatabase.InsertSagaStep(payload)
    return insert([[
        INSERT INTO nexa_economy_saga_steps (saga_id, step_name, status, metadata_json, error_code)
        VALUES (?, ?, ?, ?, ?)
    ]], { payload.saga_id, payload.step_name, payload.status, encode(payload.metadata), payload.error_code }, 'economy.sagas.step')
end

function NexaEconomyDatabase.GetSchema()
    return {
        tables = {
            'nexa_economy_accounts',
            'nexa_economy_transactions',
            'nexa_economy_ledger',
            'nexa_economy_reservations',
            'nexa_economy_audit',
            'nexa_economy_sagas',
            'nexa_economy_saga_steps'
        },
        migration = '080_economy_foundation'
    }
end
