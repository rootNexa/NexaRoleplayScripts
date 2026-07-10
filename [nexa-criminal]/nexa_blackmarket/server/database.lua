NexaBlackmarketDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_BLACKMARKET_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'blackmarket.db' }) end

function NexaBlackmarketDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '153_blackmarket_foundation',
        description = 'Create blackmarket markets catalog fences laundering jobs and audit.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_blackmarket_markets (id INT AUTO_INCREMENT PRIMARY KEY, market_key VARCHAR(64) UNIQUE NOT NULL, label VARCHAR(128) NOT NULL, market_type VARCHAR(32) NOT NULL, status VARCHAR(32) NOT NULL, access_rules LONGTEXT NULL, pricing_policy LONGTEXT NULL, metadata LONGTEXT NULL)]], {}, { category = 'blackmarket.migration.markets' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_blackmarket_catalog (id INT AUTO_INCREMENT PRIMARY KEY, market_id INT NOT NULL, item_name VARCHAR(64) NOT NULL, price INT NOT NULL, currency_item VARCHAR(64) NULL, stock_policy LONGTEXT NULL, access_rules LONGTEXT NULL, metadata LONGTEXT NULL)]], {}, { category = 'blackmarket.migration.catalog' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_blackmarket_fences (id INT AUTO_INCREMENT PRIMARY KEY, fence_key VARCHAR(64) UNIQUE NOT NULL, label VARCHAR(128) NOT NULL, status VARCHAR(32) NOT NULL, accepted_rules LONGTEXT NULL, pricing_policy LONGTEXT NULL, metadata LONGTEXT NULL)]], {}, { category = 'blackmarket.migration.fences' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_moneylaundering_jobs (id INT AUTO_INCREMENT PRIMARY KEY, character_id BIGINT NOT NULL, amount INT NOT NULL, fee_amount INT NOT NULL, payout_amount INT NOT NULL, status VARCHAR(32) NOT NULL, started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, completes_at TIMESTAMP NULL, completed_at TIMESTAMP NULL, idempotency_key VARCHAR(128) UNIQUE NULL, correlation_id VARCHAR(128) NULL, metadata LONGTEXT NULL)]], {}, { category = 'blackmarket.migration.laundering' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_blackmarket_audit (id INT AUTO_INCREMENT PRIMARY KEY, market_id INT NULL, action VARCHAR(64) NOT NULL, actor_character_id BIGINT NULL, reason VARCHAR(255) NULL, result VARCHAR(32) NOT NULL, error_code VARCHAR(64) NULL, correlation_id VARCHAR(128) NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'blackmarket.migration.audit' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaBlackmarketDatabase.ListMarkets() return dbCall('Query', 'SELECT * FROM nexa_blackmarket_markets WHERE status = ? ORDER BY id DESC LIMIT 500', { 'active' }, 'blackmarket.market.list') end
function NexaBlackmarketDatabase.GetMarket(id) return dbCall('Single', 'SELECT * FROM nexa_blackmarket_markets WHERE id = ? OR market_key = ? LIMIT 1', { tonumber(id) or 0, tostring(id) }, 'blackmarket.market.get') end
function NexaBlackmarketDatabase.ListCatalog(marketId) return dbCall('Query', 'SELECT * FROM nexa_blackmarket_catalog WHERE market_id = ? ORDER BY id ASC', { marketId }, 'blackmarket.catalog.list') end
function NexaBlackmarketDatabase.InsertLaunderingJob(j) return dbCall('Insert', 'INSERT INTO nexa_moneylaundering_jobs (character_id, amount, fee_amount, payout_amount, status, completes_at, idempotency_key, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, FROM_UNIXTIME(?), ?, ?, ?)', { j.character_id, j.amount, j.fee_amount, j.payout_amount, j.status, j.completes_at, j.idempotency_key, j.correlation_id, encode(j.metadata) }, 'blackmarket.laundering.insert') end
function NexaBlackmarketDatabase.GetLaunderingJob(id) return dbCall('Single', 'SELECT * FROM nexa_moneylaundering_jobs WHERE id = ? LIMIT 1', { id }, 'blackmarket.laundering.get') end
function NexaBlackmarketDatabase.GetSchema() return { migration = '153_blackmarket_foundation', tables = { 'nexa_blackmarket_markets', 'nexa_blackmarket_catalog', 'nexa_blackmarket_fences', 'nexa_moneylaundering_jobs', 'nexa_blackmarket_audit' } } end
