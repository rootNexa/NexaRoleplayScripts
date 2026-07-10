NexaPayrollDatabase = {}

local function coreDatabase()
    if GetResourceState('nexa-core') ~= 'started' then return nil end
    local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end)
    return ok and core and core.Database or nil
end

local function encode(value)
    local ok, encoded = pcall(json.encode, value or {})
    return ok and encoded or '{}'
end

local function dbCall(method, sql, params, category)
    local db = coreDatabase()
    if not db or not db[method] then return nil, { code = NEXA_PAYROLL_ERRORS.databaseError } end
    return db[method](sql, params or {}, { category = category or 'payroll.db' })
end

function NexaPayrollDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '100_payroll_foundation',
        description = 'Create payroll policies periods runs entries and audit.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_payroll_policies (
                id INT AUTO_INCREMENT PRIMARY KEY,
                organization_id INT NOT NULL,
                rank_id INT NOT NULL,
                amount BIGINT NOT NULL,
                interval_seconds INT NOT NULL,
                minimum_duty_seconds INT NOT NULL DEFAULT 0,
                prorated TINYINT(1) NOT NULL DEFAULT 0,
                max_amount BIGINT NULL,
                status VARCHAR(32) NOT NULL,
                valid_from TIMESTAMP NULL,
                valid_until TIMESTAMP NULL,
                version INT NOT NULL DEFAULT 1,
                created_by BIGINT NULL,
                updated_by BIGINT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL,
                INDEX idx_payroll_policy_org_rank (organization_id, rank_id, status)
            )]], {}, { category = 'payroll.migration.policies' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_payroll_periods (
                id INT AUTO_INCREMENT PRIMARY KEY,
                scope_type VARCHAR(32) NOT NULL,
                scope_id VARCHAR(64) NOT NULL,
                period_start TIMESTAMP NOT NULL,
                period_end TIMESTAMP NOT NULL,
                status VARCHAR(32) NOT NULL,
                run_id INT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                closed_at TIMESTAMP NULL,
                metadata LONGTEXT NULL,
                UNIQUE KEY uq_payroll_period_scope (scope_type, scope_id, period_start, period_end)
            )]], {}, { category = 'payroll.migration.periods' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_payroll_runs (
                id INT AUTO_INCREMENT PRIMARY KEY,
                period_id INT NOT NULL,
                organization_id INT NOT NULL,
                status VARCHAR(32) NOT NULL,
                total_gross BIGINT NOT NULL DEFAULT 0,
                total_paid BIGINT NOT NULL DEFAULT 0,
                total_failed BIGINT NOT NULL DEFAULT 0,
                member_count INT NOT NULL DEFAULT 0,
                started_at TIMESTAMP NULL,
                completed_at TIMESTAMP NULL,
                failed_at TIMESTAMP NULL,
                correlation_id VARCHAR(128) NULL,
                idempotency_key VARCHAR(128) UNIQUE NULL,
                error_code VARCHAR(64) NULL,
                metadata LONGTEXT NULL,
                UNIQUE KEY uq_payroll_run_period_org (period_id, organization_id)
            )]], {}, { category = 'payroll.migration.runs' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_payroll_entries (
                id INT AUTO_INCREMENT PRIMARY KEY,
                run_id INT NOT NULL,
                character_id BIGINT NOT NULL,
                organization_id INT NOT NULL,
                rank_id INT NOT NULL,
                policy_id INT NULL,
                duty_seconds INT NOT NULL DEFAULT 0,
                calculated_amount BIGINT NOT NULL DEFAULT 0,
                paid_amount BIGINT NOT NULL DEFAULT 0,
                status VARCHAR(32) NOT NULL,
                source_account_id INT NULL,
                target_account_id INT NULL,
                economy_transaction_id INT NULL,
                failure_reason VARCHAR(255) NULL,
                correlation_id VARCHAR(128) NULL,
                idempotency_key VARCHAR(128) UNIQUE NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                paid_at TIMESTAMP NULL,
                metadata LONGTEXT NULL,
                UNIQUE KEY uq_payroll_entry_run_character (run_id, character_id)
            )]], {}, { category = 'payroll.migration.entries' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_payroll_audit (
                id INT AUTO_INCREMENT PRIMARY KEY,
                action VARCHAR(64) NOT NULL,
                actor_account_id BIGINT NULL,
                actor_character_id BIGINT NULL,
                organization_id INT NULL,
                run_id INT NULL,
                entry_id INT NULL,
                amount BIGINT NULL,
                before_state LONGTEXT NULL,
                after_state LONGTEXT NULL,
                reason VARCHAR(255) NULL,
                result VARCHAR(32) NOT NULL,
                error_code VARCHAR(64) NULL,
                source_resource VARCHAR(64) NULL,
                correlation_id VARCHAR(128) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL
            )]], {}, { category = 'payroll.migration.audit' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaPayrollDatabase.InsertPolicy(p) return dbCall('Insert', 'INSERT INTO nexa_payroll_policies (organization_id, rank_id, amount, interval_seconds, minimum_duty_seconds, prorated, max_amount, status, valid_from, valid_until, created_by, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?), FROM_UNIXTIME(?), ?, ?)', { p.organization_id, p.rank_id, p.amount, p.interval_seconds, p.minimum_duty_seconds, p.prorated and 1 or 0, p.max_amount, p.status, p.valid_from, p.valid_until, p.created_by, encode(p.metadata) }, 'payroll.policy.insert') end
function NexaPayrollDatabase.GetPolicy(id) return dbCall('Single', 'SELECT * FROM nexa_payroll_policies WHERE id = ? LIMIT 1', { id }, 'payroll.policy.get') end
function NexaPayrollDatabase.ListPolicies(orgId) return dbCall('Query', 'SELECT * FROM nexa_payroll_policies WHERE organization_id = ? ORDER BY id ASC', { orgId }, 'payroll.policy.list') end
function NexaPayrollDatabase.GetPolicyForRank(orgId, rankId) return dbCall('Single', 'SELECT * FROM nexa_payroll_policies WHERE organization_id = ? AND rank_id = ? AND status = ? ORDER BY version DESC LIMIT 1', { orgId, rankId, NEXA_PAYROLL_POLICY_STATUS.active }, 'payroll.policy.rank') end
function NexaPayrollDatabase.UpdatePolicy(id, c) return dbCall('Update', 'UPDATE nexa_payroll_policies SET amount = COALESCE(?, amount), status = COALESCE(?, status), minimum_duty_seconds = COALESCE(?, minimum_duty_seconds), prorated = COALESCE(?, prorated), max_amount = COALESCE(?, max_amount), updated_by = ?, version = version + 1 WHERE id = ?', { c.amount, c.status, c.minimum_duty_seconds, c.prorated, c.max_amount, c.updated_by, id }, 'payroll.policy.update') end
function NexaPayrollDatabase.InsertPeriod(p) return dbCall('Insert', 'INSERT INTO nexa_payroll_periods (scope_type, scope_id, period_start, period_end, status, metadata) VALUES (?, ?, FROM_UNIXTIME(?), FROM_UNIXTIME(?), ?, ?)', { p.scope_type, p.scope_id, p.period_start, p.period_end, p.status, encode(p.metadata) }, 'payroll.period.insert') end
function NexaPayrollDatabase.GetPeriod(id) return dbCall('Single', 'SELECT * FROM nexa_payroll_periods WHERE id = ? LIMIT 1', { id }, 'payroll.period.get') end
function NexaPayrollDatabase.GetCurrentPeriod(scopeType, scopeId, now) return dbCall('Single', 'SELECT * FROM nexa_payroll_periods WHERE scope_type = ? AND scope_id = ? AND period_start <= FROM_UNIXTIME(?) AND period_end > FROM_UNIXTIME(?) LIMIT 1', { scopeType, scopeId, now, now }, 'payroll.period.current') end
function NexaPayrollDatabase.UpdatePeriodStatus(id, status, runId) return dbCall('Update', 'UPDATE nexa_payroll_periods SET status = ?, run_id = COALESCE(?, run_id), closed_at = CURRENT_TIMESTAMP WHERE id = ?', { status, runId, id }, 'payroll.period.status') end
function NexaPayrollDatabase.InsertRun(p) return dbCall('Insert', 'INSERT INTO nexa_payroll_runs (period_id, organization_id, status, started_at, correlation_id, idempotency_key, metadata) VALUES (?, ?, ?, CURRENT_TIMESTAMP, ?, ?, ?)', { p.period_id, p.organization_id, p.status, p.correlation_id, p.idempotency_key, encode(p.metadata) }, 'payroll.run.insert') end
function NexaPayrollDatabase.GetRun(id) return dbCall('Single', 'SELECT * FROM nexa_payroll_runs WHERE id = ? LIMIT 1', { id }, 'payroll.run.get') end
function NexaPayrollDatabase.ListRuns() return dbCall('Query', 'SELECT * FROM nexa_payroll_runs ORDER BY id DESC LIMIT 100', {}, 'payroll.run.list') end
function NexaPayrollDatabase.UpdateRun(id, c) return dbCall('Update', 'UPDATE nexa_payroll_runs SET status = ?, total_gross = COALESCE(?, total_gross), total_paid = COALESCE(?, total_paid), total_failed = COALESCE(?, total_failed), member_count = COALESCE(?, member_count), completed_at = CASE WHEN ? = ? THEN CURRENT_TIMESTAMP ELSE completed_at END, failed_at = CASE WHEN ? = ? THEN CURRENT_TIMESTAMP ELSE failed_at END, error_code = ? WHERE id = ?', { c.status, c.total_gross, c.total_paid, c.total_failed, c.member_count, c.status, NEXA_PAYROLL_RUN_STATUS.completed, c.status, NEXA_PAYROLL_RUN_STATUS.failed, c.error_code, id }, 'payroll.run.update') end
function NexaPayrollDatabase.InsertEntry(e) return dbCall('Insert', 'INSERT INTO nexa_payroll_entries (run_id, character_id, organization_id, rank_id, policy_id, duty_seconds, calculated_amount, paid_amount, status, source_account_id, target_account_id, economy_transaction_id, failure_reason, correlation_id, idempotency_key, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { e.run_id, e.character_id, e.organization_id, e.rank_id, e.policy_id, e.duty_seconds, e.calculated_amount, e.paid_amount or 0, e.status, e.source_account_id, e.target_account_id, e.economy_transaction_id, e.failure_reason, e.correlation_id, e.idempotency_key, encode(e.metadata) }, 'payroll.entry.insert') end
function NexaPayrollDatabase.GetEntry(id) return dbCall('Single', 'SELECT * FROM nexa_payroll_entries WHERE id = ? LIMIT 1', { id }, 'payroll.entry.get') end
function NexaPayrollDatabase.ListEntries(runId) return dbCall('Query', 'SELECT * FROM nexa_payroll_entries WHERE run_id = ? ORDER BY id ASC', { runId }, 'payroll.entry.list') end
function NexaPayrollDatabase.UpdateEntryPaid(id, amount, transactionId) return dbCall('Update', 'UPDATE nexa_payroll_entries SET status = ?, paid_amount = ?, economy_transaction_id = ?, paid_at = CURRENT_TIMESTAMP WHERE id = ?', { NEXA_PAYROLL_ENTRY_STATUS.paid, amount, transactionId, id }, 'payroll.entry.paid') end
function NexaPayrollDatabase.ListDutySessions(characterId, organizationId, startAt, endAt) return dbCall('Query', 'SELECT * FROM nexa_job_duty_sessions WHERE character_id = ? AND organization_id = ? AND started_at < FROM_UNIXTIME(?) AND (ended_at IS NULL OR ended_at > FROM_UNIXTIME(?)) ORDER BY started_at ASC', { characterId, organizationId, endAt, startAt }, 'payroll.duty.sessions') end
function NexaPayrollDatabase.InsertAudit(a) return dbCall('Insert', 'INSERT INTO nexa_payroll_audit (action, actor_account_id, actor_character_id, organization_id, run_id, entry_id, amount, before_state, after_state, reason, result, error_code, source_resource, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { a.action, a.actor_account_id, a.actor_character_id, a.organization_id, a.run_id, a.entry_id, a.amount, a.before_state and encode(a.before_state) or nil, a.after_state and encode(a.after_state) or nil, a.reason, a.result, a.error_code, a.source_resource, a.correlation_id, encode(a.metadata) }, 'payroll.audit.insert') end
function NexaPayrollDatabase.GetSchema() return { migration = '100_payroll_foundation', tables = { 'nexa_payroll_policies', 'nexa_payroll_periods', 'nexa_payroll_runs', 'nexa_payroll_entries', 'nexa_payroll_audit' } } end
