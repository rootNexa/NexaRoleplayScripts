NexaBillingDatabase = {}

local function coreDatabase()
    if GetResourceState('nexa-core') ~= 'started' then return nil end
    local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end)
    return ok and core and core.Database or nil
end

local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_BILLING_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'billing.db' }) end

function NexaBillingDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '101_billing_foundation',
        description = 'Create invoices invoice items payments and audit.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_invoices (
                id INT AUTO_INCREMENT PRIMARY KEY,
                invoice_number VARCHAR(64) UNIQUE NOT NULL,
                invoice_type VARCHAR(32) NOT NULL,
                issuer_type VARCHAR(32) NOT NULL,
                issuer_id VARCHAR(64) NOT NULL,
                recipient_type VARCHAR(32) NOT NULL,
                recipient_id VARCHAR(64) NOT NULL,
                organization_id INT NULL,
                currency VARCHAR(32) NOT NULL,
                total_amount BIGINT NOT NULL,
                paid_amount BIGINT NOT NULL DEFAULT 0,
                status VARCHAR(32) NOT NULL,
                description VARCHAR(255) NULL,
                issued_at TIMESTAMP NULL,
                due_at TIMESTAMP NULL,
                viewed_at TIMESTAMP NULL,
                paid_at TIMESTAMP NULL,
                cancelled_at TIMESTAMP NULL,
                created_by_account_id BIGINT NULL,
                created_by_character_id BIGINT NULL,
                version INT NOT NULL DEFAULT 1,
                correlation_id VARCHAR(128) NULL,
                metadata LONGTEXT NULL,
                INDEX idx_invoice_recipient (recipient_type, recipient_id, status),
                INDEX idx_invoice_issuer (issuer_type, issuer_id, status)
            )]], {}, { category = 'billing.migration.invoices' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_invoice_items (
                id INT AUTO_INCREMENT PRIMARY KEY,
                invoice_id INT NOT NULL,
                position INT NOT NULL,
                description VARCHAR(255) NOT NULL,
                quantity INT NOT NULL,
                unit_amount BIGINT NOT NULL,
                total_amount BIGINT NOT NULL,
                category VARCHAR(64) NULL,
                reference_type VARCHAR(64) NULL,
                reference_id VARCHAR(64) NULL,
                metadata LONGTEXT NULL,
                UNIQUE KEY uq_invoice_item_position (invoice_id, position)
            )]], {}, { category = 'billing.migration.items' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_invoice_payments (
                id INT AUTO_INCREMENT PRIMARY KEY,
                invoice_id INT NOT NULL,
                amount BIGINT NOT NULL,
                payer_account_id BIGINT NULL,
                payer_character_id BIGINT NULL,
                source_economy_account_id INT NULL,
                target_economy_account_id INT NULL,
                economy_transaction_id INT NULL,
                status VARCHAR(32) NOT NULL,
                idempotency_key VARCHAR(128) UNIQUE NULL,
                correlation_id VARCHAR(128) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                completed_at TIMESTAMP NULL,
                error_code VARCHAR(64) NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'billing.migration.payments' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_invoice_audit (
                id INT AUTO_INCREMENT PRIMARY KEY,
                invoice_id INT NULL,
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
            )]], {}, { category = 'billing.migration.audit' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaBillingDatabase.InsertInvoice(i) return dbCall('Insert', 'INSERT INTO nexa_invoices (invoice_number, invoice_type, issuer_type, issuer_id, recipient_type, recipient_id, organization_id, currency, total_amount, paid_amount, status, description, issued_at, due_at, created_by_account_id, created_by_character_id, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, CURRENT_TIMESTAMP, FROM_UNIXTIME(?), ?, ?, ?, ?)', { i.invoice_number, i.invoice_type, i.issuer_type, i.issuer_id, i.recipient_type, i.recipient_id, i.organization_id, i.currency, i.total_amount, i.status, i.description, i.due_at, i.created_by_account_id, i.created_by_character_id, i.correlation_id, encode(i.metadata) }, 'billing.invoice.insert') end
function NexaBillingDatabase.GetInvoice(id) return dbCall('Single', 'SELECT * FROM nexa_invoices WHERE id = ? LIMIT 1', { id }, 'billing.invoice.get') end
function NexaBillingDatabase.ListInvoices() return dbCall('Query', 'SELECT * FROM nexa_invoices ORDER BY id DESC LIMIT 100', {}, 'billing.invoice.list') end
function NexaBillingDatabase.ListRecipientInvoices(t, id) return dbCall('Query', 'SELECT * FROM nexa_invoices WHERE recipient_type = ? AND recipient_id = ? ORDER BY id DESC', { t, id }, 'billing.invoice.recipient') end
function NexaBillingDatabase.ListIssuerInvoices(t, id) return dbCall('Query', 'SELECT * FROM nexa_invoices WHERE issuer_type = ? AND issuer_id = ? ORDER BY id DESC', { t, id }, 'billing.invoice.issuer') end
function NexaBillingDatabase.UpdateInvoiceStatus(id, status) return dbCall('Update', 'UPDATE nexa_invoices SET status = ?, version = version + 1 WHERE id = ?', { status, id }, 'billing.invoice.status') end
function NexaBillingDatabase.UpdateInvoicePaid(id, amount, status) return dbCall('Update', 'UPDATE nexa_invoices SET paid_amount = paid_amount + ?, status = ?, paid_at = CASE WHEN ? = ? THEN CURRENT_TIMESTAMP ELSE paid_at END, version = version + 1 WHERE id = ?', { amount, status, status, NEXA_INVOICE_STATUS.paid, id }, 'billing.invoice.paid') end
function NexaBillingDatabase.InsertItem(item) return dbCall('Insert', 'INSERT INTO nexa_invoice_items (invoice_id, position, description, quantity, unit_amount, total_amount, category, reference_type, reference_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { item.invoice_id, item.position, item.description, item.quantity, item.unit_amount, item.total_amount, item.category, item.reference_type, item.reference_id, encode(item.metadata) }, 'billing.item.insert') end
function NexaBillingDatabase.ListItems(invoiceId) return dbCall('Query', 'SELECT * FROM nexa_invoice_items WHERE invoice_id = ? ORDER BY position ASC', { invoiceId }, 'billing.item.list') end
function NexaBillingDatabase.InsertPayment(p) return dbCall('Insert', 'INSERT INTO nexa_invoice_payments (invoice_id, amount, payer_account_id, payer_character_id, source_economy_account_id, target_economy_account_id, economy_transaction_id, status, idempotency_key, correlation_id, error_code, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { p.invoice_id, p.amount, p.payer_account_id, p.payer_character_id, p.source_economy_account_id, p.target_economy_account_id, p.economy_transaction_id, p.status, p.idempotency_key, p.correlation_id, p.error_code, encode(p.metadata) }, 'billing.payment.insert') end
function NexaBillingDatabase.GetPayment(id) return dbCall('Single', 'SELECT * FROM nexa_invoice_payments WHERE id = ? LIMIT 1', { id }, 'billing.payment.get') end
function NexaBillingDatabase.ListPayments(invoiceId) return dbCall('Query', 'SELECT * FROM nexa_invoice_payments WHERE invoice_id = ? ORDER BY id ASC', { invoiceId }, 'billing.payment.list') end
function NexaBillingDatabase.ListOverdue(now) return dbCall('Query', 'SELECT * FROM nexa_invoices WHERE due_at < FROM_UNIXTIME(?) AND status IN (?, ?, ?) ORDER BY due_at ASC', { now, NEXA_INVOICE_STATUS.issued, NEXA_INVOICE_STATUS.viewed, NEXA_INVOICE_STATUS.partiallyPaid }, 'billing.invoice.overdue') end
function NexaBillingDatabase.InsertAudit(a) return dbCall('Insert', 'INSERT INTO nexa_invoice_audit (invoice_id, action, actor_account_id, actor_character_id, before_state, after_state, reason, result, error_code, source_resource, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { a.invoice_id, a.action, a.actor_account_id, a.actor_character_id, a.before_state and encode(a.before_state) or nil, a.after_state and encode(a.after_state) or nil, a.reason, a.result, a.error_code, a.source_resource, a.correlation_id, encode(a.metadata) }, 'billing.audit.insert') end
function NexaBillingDatabase.GetSchema() return { migration = '101_billing_foundation', tables = { 'nexa_invoices', 'nexa_invoice_items', 'nexa_invoice_payments', 'nexa_invoice_audit' } } end
