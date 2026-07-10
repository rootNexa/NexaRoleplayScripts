NexaJobsDatabase = {}

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
    if not db or not db[method] then
        return nil, { code = NEXA_JOB_ERRORS.databaseError, message = 'Core database unavailable.' }
    end
    return db[method](sql, params or {}, { category = category or 'jobs.db' })
end

function NexaJobsDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '091_jobs_duty_foundation',
        description = 'Create job runtime audit table and rely on organization duty sessions.',
        transaction = false,
        up = function()
            db.Query([[
                CREATE TABLE IF NOT EXISTS nexa_job_audit (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    action VARCHAR(64) NOT NULL,
                    source INT NULL,
                    character_id BIGINT NULL,
                    organization_id INT NULL,
                    rank_id INT NULL,
                    duty_session_id INT NULL,
                    reason VARCHAR(255) NULL,
                    result VARCHAR(32) NOT NULL,
                    error_code VARCHAR(64) NULL,
                    metadata LONGTEXT NULL,
                    correlation_id VARCHAR(128) NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    INDEX idx_nexa_job_audit_character (character_id),
                    INDEX idx_nexa_job_audit_org (organization_id)
                )
            ]], {}, { category = 'jobs.migration.audit' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaJobsDatabase.InsertDutySession(payload)
    return dbCall('Insert', [[
        INSERT INTO nexa_job_duty_sessions (character_id, organization_id, rank_id, status, start_reason, source, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { payload.character_id, payload.organization_id, payload.rank_id, payload.status, payload.start_reason, payload.source, encode(payload.metadata) }, 'jobs.duty.insert')
end

function NexaJobsDatabase.GetActiveDutySession(characterId)
    return dbCall('Single', 'SELECT * FROM nexa_job_duty_sessions WHERE character_id = ? AND status = ? LIMIT 1', { characterId, NEXA_DUTY_SESSION_STATUS.active }, 'jobs.duty.active')
end

function NexaJobsDatabase.EndDutySession(sessionId, status, reason)
    return dbCall('Update', 'UPDATE nexa_job_duty_sessions SET status = ?, ended_at = CURRENT_TIMESTAMP, end_reason = ? WHERE id = ?', { status, reason, sessionId }, 'jobs.duty.end')
end

function NexaJobsDatabase.ListActiveDuty(organizationId)
    return dbCall('Query', 'SELECT * FROM nexa_job_duty_sessions WHERE organization_id = ? AND status = ? ORDER BY started_at ASC', { organizationId, NEXA_DUTY_SESSION_STATUS.active }, 'jobs.duty.list')
end

function NexaJobsDatabase.InsertAudit(payload)
    return dbCall('Insert', [[
        INSERT INTO nexa_job_audit (action, source, character_id, organization_id, rank_id, duty_session_id, reason, result, error_code, metadata, correlation_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { payload.action, payload.source, payload.character_id, payload.organization_id, payload.rank_id, payload.duty_session_id, payload.reason, payload.result, payload.error_code, encode(payload.metadata), payload.correlation_id }, 'jobs.audit.insert')
end

function NexaJobsDatabase.GetSchema()
    return { migration = '091_jobs_duty_foundation', tables = { 'nexa_job_audit', 'nexa_job_duty_sessions' } }
end
