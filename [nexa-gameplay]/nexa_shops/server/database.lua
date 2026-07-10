NexaShopsDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_SHOP_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'shops.db' }) end

function NexaShopsDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '130_shops_commerce_foundation',
        description = 'Create commerce shop definitions catalog stock transactions deliveries and audit.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_shop_definitions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                shop_key VARCHAR(64) UNIQUE NOT NULL,
                label VARCHAR(128) NOT NULL,
                shop_type VARCHAR(32) NOT NULL,
                status VARCHAR(32) NOT NULL,
                owner_type VARCHAR(32) NULL,
                owner_id VARCHAR(64) NULL,
                organization_id INT NULL,
                property_id INT NULL,
                economy_account_id INT NULL,
                inventory_id VARCHAR(64) NULL,
                position LONGTEXT NULL,
                access_rules LONGTEXT NULL,
                stock_policy LONGTEXT NULL,
                pricing_policy LONGTEXT NULL,
                settings LONGTEXT NULL,
                version INT NOT NULL DEFAULT 1,
                created_by BIGINT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                deleted_at TIMESTAMP NULL,
                INDEX idx_shop_def_type (shop_type, status)
            )]], {}, { category = 'shops.migration.definitions' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_shop_items (
                id INT AUTO_INCREMENT PRIMARY KEY,
                shop_id INT NOT NULL,
                item_name VARCHAR(64) NOT NULL,
                buy_price BIGINT NOT NULL DEFAULT 0,
                sell_price BIGINT NOT NULL DEFAULT 0,
                buy_enabled TINYINT(1) NOT NULL DEFAULT 1,
                sell_enabled TINYINT(1) NOT NULL DEFAULT 0,
                stock_mode VARCHAR(32) NOT NULL,
                stock_amount INT NOT NULL DEFAULT 0,
                max_stock INT NOT NULL DEFAULT 0,
                restock_threshold INT NOT NULL DEFAULT 0,
                purchase_limit INT NULL,
                required_license VARCHAR(64) NULL,
                access_rules LONGTEXT NULL,
                metadata LONGTEXT NULL,
                version INT NOT NULL DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY uq_shop_item (shop_id, item_name)
            )]], {}, { category = 'shops.migration.items' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_shop_transactions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                shop_id INT NOT NULL,
                transaction_type VARCHAR(32) NOT NULL,
                character_id BIGINT NULL,
                item_name VARCHAR(64) NOT NULL,
                amount INT NOT NULL,
                unit_price BIGINT NOT NULL,
                total_price BIGINT NOT NULL,
                currency VARCHAR(32) NOT NULL,
                economy_transaction_id INT NULL,
                inventory_correlation_id VARCHAR(128) NULL,
                status VARCHAR(32) NOT NULL,
                idempotency_key VARCHAR(128) UNIQUE NULL,
                correlation_id VARCHAR(128) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                completed_at TIMESTAMP NULL,
                error_code VARCHAR(64) NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'shops.migration.transactions' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_shop_stock_movements (
                id INT AUTO_INCREMENT PRIMARY KEY,
                shop_id INT NOT NULL,
                item_name VARCHAR(64) NOT NULL,
                movement_type VARCHAR(32) NOT NULL,
                amount INT NOT NULL,
                stock_before INT NULL,
                stock_after INT NULL,
                actor_account_id BIGINT NULL,
                actor_character_id BIGINT NULL,
                source_resource VARCHAR(64) NULL,
                reason VARCHAR(255) NULL,
                correlation_id VARCHAR(128) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL
            )]], {}, { category = 'shops.migration.stock' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_shop_deliveries (
                id INT AUTO_INCREMENT PRIMARY KEY,
                shop_id INT NOT NULL,
                item_name VARCHAR(64) NOT NULL,
                amount INT NOT NULL,
                status VARCHAR(32) NOT NULL,
                assigned_character_id BIGINT NULL,
                organization_id INT NULL,
                correlation_id VARCHAR(128) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL
            )]], {}, { category = 'shops.migration.deliveries' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_shop_audit (
                id INT AUTO_INCREMENT PRIMARY KEY,
                shop_id INT NULL,
                action VARCHAR(64) NOT NULL,
                actor_account_id BIGINT NULL,
                actor_character_id BIGINT NULL,
                before_state LONGTEXT NULL,
                after_state LONGTEXT NULL,
                reason VARCHAR(255) NULL,
                result VARCHAR(32) NOT NULL,
                error_code VARCHAR(64) NULL,
                source_resource VARCHAR(64) NULL,
                correlation_id VARCHAR(128) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL
            )]], {}, { category = 'shops.migration.audit' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaShopsDatabase.InsertShop(s) return dbCall('Insert', 'INSERT INTO nexa_shop_definitions (shop_key, label, shop_type, status, owner_type, owner_id, organization_id, property_id, economy_account_id, inventory_id, position, access_rules, stock_policy, pricing_policy, settings, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { s.shop_key, s.label, s.shop_type, s.status, s.owner_type, s.owner_id, s.organization_id, s.property_id, s.economy_account_id, s.inventory_id, encode(s.position), encode(s.access_rules), encode(s.stock_policy), encode(s.pricing_policy), encode(s.settings), s.created_by }, 'shops.insert') end
function NexaShopsDatabase.GetShop(idOrKey) local id = tonumber(idOrKey); if id then return dbCall('Single', 'SELECT * FROM nexa_shop_definitions WHERE id = ? AND deleted_at IS NULL LIMIT 1', { id }, 'shops.get') end; return dbCall('Single', 'SELECT * FROM nexa_shop_definitions WHERE shop_key = ? AND deleted_at IS NULL LIMIT 1', { tostring(idOrKey) }, 'shops.key') end
function NexaShopsDatabase.ListShops() return dbCall('Query', 'SELECT * FROM nexa_shop_definitions WHERE deleted_at IS NULL ORDER BY id DESC LIMIT 500', {}, 'shops.list') end
function NexaShopsDatabase.UpdateShopStatus(id, status) return dbCall('Update', 'UPDATE nexa_shop_definitions SET status = ?, version = version + 1 WHERE id = ?', { status, id }, 'shops.status') end
function NexaShopsDatabase.InsertShopItem(i) return dbCall('Insert', 'INSERT INTO nexa_shop_items (shop_id, item_name, buy_price, sell_price, buy_enabled, sell_enabled, stock_mode, stock_amount, max_stock, restock_threshold, purchase_limit, required_license, access_rules, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { i.shop_id, i.item_name, i.buy_price, i.sell_price, i.buy_enabled and 1 or 0, i.sell_enabled and 1 or 0, i.stock_mode, i.stock_amount, i.max_stock, i.restock_threshold, i.purchase_limit, i.required_license, encode(i.access_rules), encode(i.metadata) }, 'shops.item.insert') end
function NexaShopsDatabase.GetShopItem(shopId, itemName) return dbCall('Single', 'SELECT * FROM nexa_shop_items WHERE shop_id = ? AND item_name = ? LIMIT 1', { shopId, itemName }, 'shops.item.get') end
function NexaShopsDatabase.ListShopItems(shopId) return dbCall('Query', 'SELECT * FROM nexa_shop_items WHERE shop_id = ? ORDER BY item_name ASC', { shopId }, 'shops.item.list') end
function NexaShopsDatabase.UpdateShopItem(id, updates) return dbCall('Update', 'UPDATE nexa_shop_items SET buy_price = ?, sell_price = ?, buy_enabled = ?, sell_enabled = ?, stock_mode = ?, stock_amount = ?, max_stock = ?, version = version + 1 WHERE id = ?', { updates.buy_price, updates.sell_price, updates.buy_enabled and 1 or 0, updates.sell_enabled and 1 or 0, updates.stock_mode, updates.stock_amount, updates.max_stock, id }, 'shops.item.update') end
function NexaShopsDatabase.RemoveShopItem(id) return dbCall('Update', 'DELETE FROM nexa_shop_items WHERE id = ?', { id }, 'shops.item.remove') end
function NexaShopsDatabase.AdjustStock(shopId, itemName, delta) return dbCall('Update', 'UPDATE nexa_shop_items SET stock_amount = stock_amount + ?, version = version + 1 WHERE shop_id = ? AND item_name = ? AND stock_mode <> ?', { delta, shopId, itemName, NEXA_SHOP_STOCK_MODE.infinite }, 'shops.stock.adjust') end
function NexaShopsDatabase.InsertStockMovement(m) return dbCall('Insert', 'INSERT INTO nexa_shop_stock_movements (shop_id, item_name, movement_type, amount, stock_before, stock_after, actor_account_id, actor_character_id, source_resource, reason, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { m.shop_id, m.item_name, m.movement_type, m.amount, m.stock_before, m.stock_after, m.actor_account_id, m.actor_character_id, m.source_resource, m.reason, m.correlation_id, encode(m.metadata) }, 'shops.stock.movement') end
function NexaShopsDatabase.InsertTransaction(t) return dbCall('Insert', 'INSERT INTO nexa_shop_transactions (shop_id, transaction_type, character_id, item_name, amount, unit_price, total_price, currency, economy_transaction_id, inventory_correlation_id, status, idempotency_key, correlation_id, error_code, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { t.shop_id, t.transaction_type, t.character_id, t.item_name, t.amount, t.unit_price, t.total_price, t.currency, t.economy_transaction_id, t.inventory_correlation_id, t.status, t.idempotency_key, t.correlation_id, t.error_code, encode(t.metadata) }, 'shops.transaction.insert') end
function NexaShopsDatabase.GetTransaction(id) return dbCall('Single', 'SELECT * FROM nexa_shop_transactions WHERE id = ? LIMIT 1', { id }, 'shops.transaction.get') end
function NexaShopsDatabase.InsertDelivery(d) return dbCall('Insert', 'INSERT INTO nexa_shop_deliveries (shop_id, item_name, amount, status, assigned_character_id, organization_id, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', { d.shop_id, d.item_name, d.amount, d.status, d.assigned_character_id, d.organization_id, d.correlation_id, encode(d.metadata) }, 'shops.delivery.insert') end
function NexaShopsDatabase.GetDelivery(id) return dbCall('Single', 'SELECT * FROM nexa_shop_deliveries WHERE id = ? LIMIT 1', { id }, 'shops.delivery.get') end
function NexaShopsDatabase.UpdateDeliveryStatus(id, status, assignedCharacterId) return dbCall('Update', 'UPDATE nexa_shop_deliveries SET status = ?, assigned_character_id = COALESCE(?, assigned_character_id) WHERE id = ?', { status, assignedCharacterId, id }, 'shops.delivery.status') end
function NexaShopsDatabase.InsertAudit(a) return dbCall('Insert', 'INSERT INTO nexa_shop_audit (shop_id, action, actor_account_id, actor_character_id, before_state, after_state, reason, result, error_code, source_resource, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { a.shop_id, a.action, a.actor_account_id, a.actor_character_id, a.before_state and encode(a.before_state) or nil, a.after_state and encode(a.after_state) or nil, a.reason, a.result, a.error_code, a.source_resource, a.correlation_id, encode(a.metadata) }, 'shops.audit') end
function NexaShopsDatabase.GetSchema() return { migration = '130_shops_commerce_foundation', tables = { 'nexa_shop_definitions', 'nexa_shop_items', 'nexa_shop_transactions', 'nexa_shop_stock_movements', 'nexa_shop_deliveries', 'nexa_shop_audit' } } end
