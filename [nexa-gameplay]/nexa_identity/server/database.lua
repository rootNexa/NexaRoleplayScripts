NexaIdentity = NexaIdentity or {}
NexaIdentity.Database = {}

local CORE_RESOURCE = 'nexa-core'

local function getCore()
    if GetResourceState(CORE_RESOURCE) ~= 'started' then
        return nil, 'CORE_NOT_STARTED'
    end

    local ok, coreObject = pcall(function()
        return exports[CORE_RESOURCE]:GetCoreObject()
    end)

    if not ok or type(coreObject) ~= 'table' or type(coreObject.Database) ~= 'table' then
        return nil, 'CORE_DATABASE_UNAVAILABLE'
    end

    return coreObject, nil
end

local function getDatabase()
    local coreObject, err = getCore()

    if not coreObject then
        return nil, err
    end

    return coreObject.Database, nil
end

local function dbError(err)
    if type(err) == 'table' then
        return err.code or 'DATABASE_ERROR'
    end

    return err or 'DATABASE_ERROR'
end

function NexaIdentity.Database.RegisterMigrations()
    local coreObject, err = getCore()

    if not coreObject then
        return false, err
    end

    local db = coreObject.Database

    db.RegisterMigration({
        id = '010_identity_accounts',
        description = 'Create Nexa account identity tables',
        transaction = false,
        statements = {
            [[
                CREATE TABLE IF NOT EXISTS nexa_accounts (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    primary_license VARCHAR(128) NOT NULL,
                    status VARCHAR(32) NOT NULL DEFAULT 'active',
                    status_reason TEXT NULL,
                    banned_until TIMESTAMP NULL DEFAULT NULL,
                    metadata_json LONGTEXT NULL,
                    legacy_player_id BIGINT UNSIGNED NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    last_login_at TIMESTAMP NULL DEFAULT NULL,
                    last_logout_at TIMESTAMP NULL DEFAULT NULL,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    version INT UNSIGNED NOT NULL DEFAULT 1,
                    PRIMARY KEY (id),
                    UNIQUE KEY uq_nexa_accounts_primary_license (primary_license),
                    KEY idx_nexa_accounts_status (status),
                    KEY idx_nexa_accounts_legacy_player (legacy_player_id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]],
            [[
                CREATE TABLE IF NOT EXISTS nexa_account_identifiers (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    account_id BIGINT UNSIGNED NOT NULL,
                    identifier_type VARCHAR(32) NOT NULL,
                    identifier_value VARCHAR(160) NOT NULL,
                    identifier_hash VARCHAR(128) NULL,
                    first_seen_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    last_seen_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    verified TINYINT(1) NOT NULL DEFAULT 0,
                    active TINYINT(1) NOT NULL DEFAULT 1,
                    PRIMARY KEY (id),
                    UNIQUE KEY uq_nexa_account_identifier_value (identifier_type, identifier_value),
                    KEY idx_nexa_account_identifiers_account (account_id),
                    KEY idx_nexa_account_identifiers_active (active),
                    CONSTRAINT fk_nexa_account_identifiers_account
                        FOREIGN KEY (account_id) REFERENCES nexa_accounts (id)
                        ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]],
            [[
                CREATE TABLE IF NOT EXISTS nexa_account_status_history (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    account_id BIGINT UNSIGNED NOT NULL,
                    old_status VARCHAR(32) NULL,
                    new_status VARCHAR(32) NOT NULL,
                    reason TEXT NULL,
                    actor VARCHAR(128) NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    KEY idx_nexa_account_status_history_account (account_id),
                    KEY idx_nexa_account_status_history_created (created_at),
                    CONSTRAINT fk_nexa_account_status_history_account
                        FOREIGN KEY (account_id) REFERENCES nexa_accounts (id)
                        ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]],
            [[
                CREATE TABLE IF NOT EXISTS nexa_account_review_signals (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    account_id BIGINT UNSIGNED NOT NULL,
                    signal_type VARCHAR(64) NOT NULL,
                    strength VARCHAR(16) NOT NULL,
                    related_account_id BIGINT UNSIGNED NULL,
                    decision VARCHAR(64) NOT NULL,
                    evidence_json LONGTEXT NULL,
                    actor VARCHAR(128) NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    KEY idx_nexa_account_review_account (account_id),
                    KEY idx_nexa_account_review_related (related_account_id),
                    KEY idx_nexa_account_review_signal (signal_type, strength),
                    CONSTRAINT fk_nexa_account_review_account
                        FOREIGN KEY (account_id) REFERENCES nexa_accounts (id)
                        ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]]
        }
    })

    return db.RunMigrations()
end

function NexaIdentity.Database.UpsertAccount(primaryLicense, metadata)
    local db, err = getDatabase()

    if not db then
        return nil, err
    end

    local accountId, insertErr = db.Insert([[
        INSERT INTO nexa_accounts (primary_license, status, metadata_json, last_login_at)
        VALUES (?, 'active', ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE
            id = LAST_INSERT_ID(id),
            last_login_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP,
            version = version + 1
    ]], { primaryLicense, json.encode(metadata or {}) }, {
        category = 'identity.account_upsert'
    })

    if insertErr then
        return nil, dbError(insertErr)
    end

    return tonumber(accountId), nil
end

function NexaIdentity.Database.GetAccountById(accountId)
    local db, err = getDatabase()

    if not db then
        return nil, err
    end

    local row, queryErr = db.Single([[
        SELECT id, primary_license, status, status_reason, banned_until, metadata_json, legacy_player_id,
               created_at, last_login_at, last_logout_at, updated_at, version
        FROM nexa_accounts
        WHERE id = ?
        LIMIT 1
    ]], { accountId }, {
        category = 'identity.account_get'
    })

    if queryErr then
        return nil, dbError(queryErr)
    end

    return row, nil
end

function NexaIdentity.Database.UpsertIdentifier(accountId, identifierType, identifierValue, verified)
    local db, err = getDatabase()

    if not db then
        return false, err
    end

    local _, updateErr = db.Update([[
        INSERT INTO nexa_account_identifiers (account_id, identifier_type, identifier_value, identifier_hash, verified, active, first_seen_at, last_seen_at)
        VALUES (?, ?, ?, SHA2(?, 256), ?, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE
            account_id = VALUES(account_id),
            identifier_hash = VALUES(identifier_hash),
            verified = GREATEST(verified, VALUES(verified)),
            active = 1,
            last_seen_at = CURRENT_TIMESTAMP
    ]], { accountId, identifierType, identifierValue, identifierValue, verified and 1 or 0 }, {
        category = 'identity.identifier_upsert'
    })

    if updateErr then
        return false, dbError(updateErr)
    end

    return true, nil
end

function NexaIdentity.Database.ListIdentifiers(accountId)
    local db, err = getDatabase()

    if not db then
        return nil, err
    end

    local rows, queryErr = db.Query([[
        SELECT id, account_id, identifier_type, identifier_value, first_seen_at, last_seen_at, verified, active
        FROM nexa_account_identifiers
        WHERE account_id = ?
        ORDER BY identifier_type ASC, id ASC
    ]], { accountId }, {
        category = 'identity.identifiers_list'
    })

    if queryErr then
        return nil, dbError(queryErr)
    end

    return rows or {}, nil
end

function NexaIdentity.Database.FindOtherAccountsByIdentifier(accountId, identifierType, identifierValue)
    local db, err = getDatabase()

    if not db then
        return nil, err
    end

    local rows, queryErr = db.Query([[
        SELECT account_id, identifier_type, first_seen_at, last_seen_at
        FROM nexa_account_identifiers
        WHERE identifier_type = ? AND identifier_value = ? AND account_id <> ? AND active = 1
        ORDER BY last_seen_at DESC
    ]], { identifierType, identifierValue, accountId }, {
        category = 'identity.identifier_conflicts'
    })

    if queryErr then
        return nil, dbError(queryErr)
    end

    return rows or {}, nil
end

function NexaIdentity.Database.SetAccountStatus(accountId, status, reason, actor)
    local db, err = getDatabase()

    if not db then
        return false, err
    end

    local account, accountErr = NexaIdentity.Database.GetAccountById(accountId)

    if accountErr then
        return false, accountErr
    end

    if not account then
        return false, NEXA_IDENTITY.errors.accountNotFound
    end

    local ok, txErr = db.Transaction({
        {
            query = [[
                UPDATE nexa_accounts
                SET status = ?, status_reason = ?, updated_at = CURRENT_TIMESTAMP, version = version + 1
                WHERE id = ?
            ]],
            params = { status, reason, accountId }
        },
        {
            query = [[
                INSERT INTO nexa_account_status_history (account_id, old_status, new_status, reason, actor)
                VALUES (?, ?, ?, ?, ?)
            ]],
            params = { accountId, account.status, status, reason, actor }
        }
    }, {
        category = 'identity.account_status'
    })

    if not ok then
        return false, dbError(txErr)
    end

    return true, nil
end

function NexaIdentity.Database.RecordReviewSignal(accountId, signal)
    local db, err = getDatabase()

    if not db then
        return false, err
    end

    local _, insertErr = db.Insert([[
        INSERT INTO nexa_account_review_signals (account_id, signal_type, strength, related_account_id, decision, evidence_json, actor)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        accountId,
        signal.signalType,
        signal.strength,
        signal.relatedAccountId,
        signal.decision,
        json.encode(signal.evidence or {}),
        signal.actor
    }, {
        category = 'identity.review_signal'
    })

    if insertErr then
        return false, dbError(insertErr)
    end

    return true, nil
end

function NexaIdentity.Database.GetRiskSignals(accountId)
    local db, err = getDatabase()

    if not db then
        return nil, err
    end

    local rows, queryErr = db.Query([[
        SELECT id, account_id, signal_type, strength, related_account_id, decision, evidence_json, actor, created_at
        FROM nexa_account_review_signals
        WHERE account_id = ?
        ORDER BY created_at DESC, id DESC
    ]], { accountId }, {
        category = 'identity.review_signals'
    })

    if queryErr then
        return nil, dbError(queryErr)
    end

    return rows or {}, nil
end

function NexaIdentity.Database.MarkLogout(accountId)
    local db, err = getDatabase()

    if not db then
        return false, err
    end

    local _, updateErr = db.Update([[
        UPDATE nexa_accounts
        SET last_logout_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], { accountId }, {
        category = 'identity.account_logout'
    })

    if updateErr then
        return false, dbError(updateErr)
    end

    return true, nil
end
