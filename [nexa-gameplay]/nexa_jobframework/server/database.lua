NexaJobFrameworkDatabase = {}

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
    if not db or not db[method] then return nil, { code = NEXA_JOB_ERRORS.databaseError, message = 'Core database unavailable.' } end
    return db[method](sql, params or {}, { category = category or 'jobframework.db' })
end

function NexaJobFrameworkDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '140_jobframework_foundation',
        description = 'Create legal job framework definitions sessions progress rewards cooldowns resource nodes and audit.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_job_definitions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                job_key VARCHAR(64) UNIQUE NOT NULL,
                label VARCHAR(128) NOT NULL,
                description TEXT NULL,
                job_type VARCHAR(32) NOT NULL,
                status VARCHAR(32) NOT NULL,
                organization_id INT NULL,
                required_rank_id INT NULL,
                duty_required TINYINT(1) NOT NULL DEFAULT 0,
                group_allowed TINYINT(1) NOT NULL DEFAULT 0,
                minimum_group_size INT NOT NULL DEFAULT 1,
                maximum_group_size INT NOT NULL DEFAULT 1,
                cooldown_seconds INT NOT NULL DEFAULT 0,
                maximum_duration_seconds INT NOT NULL DEFAULT 0,
                entry_rules LONGTEXT NULL,
                reward_policy LONGTEXT NULL,
                settings LONGTEXT NULL,
                version INT NOT NULL DEFAULT 1,
                created_by BIGINT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                deleted_at TIMESTAMP NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'jobframework.migration.definitions' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_job_phases (
                id INT AUTO_INCREMENT PRIMARY KEY,
                job_definition_id INT NOT NULL,
                phase_key VARCHAR(64) NOT NULL,
                label VARCHAR(128) NOT NULL,
                position INT NOT NULL,
                phase_type VARCHAR(32) NOT NULL,
                completion_policy LONGTEXT NULL,
                timeout_seconds INT NULL,
                configuration LONGTEXT NULL,
                version INT NOT NULL DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY uq_nexa_job_phases_key (job_definition_id, phase_key)
            )]], {}, { category = 'jobframework.migration.phases' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_job_tasks (
                id INT AUTO_INCREMENT PRIMARY KEY,
                phase_id INT NOT NULL,
                task_key VARCHAR(64) NOT NULL,
                task_type VARCHAR(32) NOT NULL,
                position INT NOT NULL,
                target_definition LONGTEXT NULL,
                amount_required INT NOT NULL DEFAULT 1,
                progress_policy LONGTEXT NULL,
                validation_policy LONGTEXT NULL,
                reward_fragment LONGTEXT NULL,
                configuration LONGTEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY uq_nexa_job_tasks_key (phase_id, task_key)
            )]], {}, { category = 'jobframework.migration.tasks' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_job_sessions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                job_definition_id INT NOT NULL,
                leader_character_id BIGINT NOT NULL,
                organization_id INT NULL,
                status VARCHAR(32) NOT NULL,
                current_phase_id INT NULL,
                started_at TIMESTAMP NULL,
                expires_at TIMESTAMP NULL,
                completed_at TIMESTAMP NULL,
                cancelled_at TIMESTAMP NULL,
                failure_reason VARCHAR(255) NULL,
                idempotency_key VARCHAR(128) UNIQUE NULL,
                correlation_id VARCHAR(128) NULL,
                version INT NOT NULL DEFAULT 1,
                metadata LONGTEXT NULL,
                KEY idx_nexa_job_sessions_status (status),
                KEY idx_nexa_job_sessions_leader (leader_character_id)
            )]], {}, { category = 'jobframework.migration.sessions' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_job_session_members (
                id INT AUTO_INCREMENT PRIMARY KEY,
                session_id INT NOT NULL,
                character_id BIGINT NOT NULL,
                member_role VARCHAR(32) NOT NULL,
                status VARCHAR(32) NOT NULL,
                joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                left_at TIMESTAMP NULL,
                contribution LONGTEXT NULL,
                metadata LONGTEXT NULL,
                KEY idx_nexa_job_members_character (character_id)
            )]], {}, { category = 'jobframework.migration.members' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_job_task_progress (
                id INT AUTO_INCREMENT PRIMARY KEY,
                session_id INT NOT NULL,
                task_id INT NOT NULL,
                character_id BIGINT NOT NULL,
                progress_value INT NOT NULL DEFAULT 0,
                status VARCHAR(32) NOT NULL,
                started_at TIMESTAMP NULL,
                completed_at TIMESTAMP NULL,
                version INT NOT NULL DEFAULT 1,
                metadata LONGTEXT NULL,
                UNIQUE KEY uq_nexa_job_progress (session_id, task_id, character_id)
            )]], {}, { category = 'jobframework.migration.progress' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_job_rewards (
                id INT AUTO_INCREMENT PRIMARY KEY,
                session_id INT NOT NULL,
                character_id BIGINT NOT NULL,
                reward_type VARCHAR(32) NOT NULL,
                currency VARCHAR(32) NULL,
                amount INT NULL,
                item_name VARCHAR(64) NULL,
                item_amount INT NULL,
                status VARCHAR(32) NOT NULL,
                economy_transaction_id VARCHAR(128) NULL,
                inventory_correlation_id VARCHAR(128) NULL,
                idempotency_key VARCHAR(128) UNIQUE NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                completed_at TIMESTAMP NULL,
                error_code VARCHAR(64) NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'jobframework.migration.rewards' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_job_cooldowns (
                id INT AUTO_INCREMENT PRIMARY KEY,
                job_definition_id INT NOT NULL,
                holder_type VARCHAR(32) NOT NULL,
                holder_id VARCHAR(64) NOT NULL,
                starts_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                expires_at TIMESTAMP NOT NULL,
                reason VARCHAR(255) NULL,
                metadata LONGTEXT NULL,
                KEY idx_nexa_job_cooldowns_holder (holder_type, holder_id)
            )]], {}, { category = 'jobframework.migration.cooldowns' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_job_resource_nodes (
                id INT AUTO_INCREMENT PRIMARY KEY,
                node_key VARCHAR(64) UNIQUE NOT NULL,
                node_type VARCHAR(32) NOT NULL,
                label VARCHAR(128) NOT NULL,
                position LONGTEXT NULL,
                radius INT NOT NULL DEFAULT 3,
                resource_item VARCHAR(64) NULL,
                available_amount INT NOT NULL DEFAULT 0,
                respawn_seconds INT NOT NULL DEFAULT 0,
                tool_requirements LONGTEXT NULL,
                access_rules LONGTEXT NULL,
                anti_afk_policy LONGTEXT NULL,
                status VARCHAR(32) NOT NULL DEFAULT 'active',
                next_respawn_at TIMESTAMP NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'jobframework.migration.resource_nodes' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_job_production_chains (
                id INT AUTO_INCREMENT PRIMARY KEY,
                chain_key VARCHAR(64) UNIQUE NOT NULL,
                label VARCHAR(128) NOT NULL,
                status VARCHAR(32) NOT NULL DEFAULT 'active',
                crafting_recipe_id INT NULL,
                stages LONGTEXT NULL,
                access_rules LONGTEXT NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'jobframework.migration.production' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_job_audit (
                id INT AUTO_INCREMENT PRIMARY KEY,
                job_definition_id INT NULL,
                session_id INT NULL,
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
            )]], {}, { category = 'jobframework.migration.audit' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaJobFrameworkDatabase.InsertDefinition(d) return dbCall('Insert', 'INSERT INTO nexa_job_definitions (job_key, label, description, job_type, status, organization_id, required_rank_id, duty_required, group_allowed, minimum_group_size, maximum_group_size, cooldown_seconds, maximum_duration_seconds, entry_rules, reward_policy, settings, created_by, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { d.job_key, d.label, d.description, d.job_type, d.status, d.organization_id, d.required_rank_id, d.duty_required and 1 or 0, d.group_allowed and 1 or 0, d.minimum_group_size, d.maximum_group_size, d.cooldown_seconds, d.maximum_duration_seconds, encode(d.entry_rules), encode(d.reward_policy), encode(d.settings), d.created_by, encode(d.metadata) }, 'jobframework.definition.insert') end
function NexaJobFrameworkDatabase.GetDefinition(idOrKey) local id = tonumber(idOrKey); if id then return dbCall('Single', 'SELECT * FROM nexa_job_definitions WHERE id = ? AND deleted_at IS NULL LIMIT 1', { id }, 'jobframework.definition.get') end; return dbCall('Single', 'SELECT * FROM nexa_job_definitions WHERE job_key = ? AND deleted_at IS NULL LIMIT 1', { tostring(idOrKey) }, 'jobframework.definition.key') end
function NexaJobFrameworkDatabase.ListDefinitions(filters) filters = filters or {}; local sql = 'SELECT * FROM nexa_job_definitions WHERE deleted_at IS NULL'; local params = {}; if filters.status then sql = sql .. ' AND status = ?'; params[#params + 1] = filters.status end; if filters.job_type then sql = sql .. ' AND job_type = ?'; params[#params + 1] = filters.job_type end; return dbCall('Query', sql .. ' ORDER BY id DESC LIMIT 500', params, 'jobframework.definition.list') end
function NexaJobFrameworkDatabase.UpdateDefinitionStatus(id, status) return dbCall('Update', 'UPDATE nexa_job_definitions SET status = ?, version = version + 1 WHERE id = ?', { status, id }, 'jobframework.definition.status') end
function NexaJobFrameworkDatabase.UpdateDefinition(id, d) return dbCall('Update', 'UPDATE nexa_job_definitions SET label = ?, description = ?, status = ?, duty_required = ?, group_allowed = ?, minimum_group_size = ?, maximum_group_size = ?, cooldown_seconds = ?, maximum_duration_seconds = ?, entry_rules = ?, reward_policy = ?, settings = ?, version = version + 1, metadata = ? WHERE id = ?', { d.label, d.description, d.status, d.duty_required and 1 or 0, d.group_allowed and 1 or 0, d.minimum_group_size, d.maximum_group_size, d.cooldown_seconds, d.maximum_duration_seconds, encode(d.entry_rules), encode(d.reward_policy), encode(d.settings), encode(d.metadata), id }, 'jobframework.definition.update') end
function NexaJobFrameworkDatabase.InsertPhase(p) return dbCall('Insert', 'INSERT INTO nexa_job_phases (job_definition_id, phase_key, label, position, phase_type, completion_policy, timeout_seconds, configuration) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', { p.job_definition_id, p.phase_key, p.label, p.position, p.phase_type, encode(p.completion_policy), p.timeout_seconds, encode(p.configuration) }, 'jobframework.phase.insert') end
function NexaJobFrameworkDatabase.InsertTask(t) return dbCall('Insert', 'INSERT INTO nexa_job_tasks (phase_id, task_key, task_type, position, target_definition, amount_required, progress_policy, validation_policy, reward_fragment, configuration) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { t.phase_id, t.task_key, t.task_type, t.position, encode(t.target_definition), t.amount_required, encode(t.progress_policy), encode(t.validation_policy), encode(t.reward_fragment), encode(t.configuration) }, 'jobframework.task.insert') end
function NexaJobFrameworkDatabase.ListPhases(jobId) return dbCall('Query', 'SELECT * FROM nexa_job_phases WHERE job_definition_id = ? ORDER BY position ASC', { jobId }, 'jobframework.phase.list') end
function NexaJobFrameworkDatabase.ListTasks(phaseId) return dbCall('Query', 'SELECT * FROM nexa_job_tasks WHERE phase_id = ? ORDER BY position ASC', { phaseId }, 'jobframework.task.list') end
function NexaJobFrameworkDatabase.GetTask(taskId) return dbCall('Single', 'SELECT * FROM nexa_job_tasks WHERE id = ? LIMIT 1', { taskId }, 'jobframework.task.get') end
function NexaJobFrameworkDatabase.InsertSession(s) return dbCall('Insert', 'INSERT INTO nexa_job_sessions (job_definition_id, leader_character_id, organization_id, status, current_phase_id, started_at, expires_at, idempotency_key, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, FROM_UNIXTIME(?), ?, ?, ?)', { s.job_definition_id, s.leader_character_id, s.organization_id, s.status, s.current_phase_id, s.expires_at, s.idempotency_key, s.correlation_id, encode(s.metadata) }, 'jobframework.session.insert') end
function NexaJobFrameworkDatabase.GetSession(id) return dbCall('Single', 'SELECT * FROM nexa_job_sessions WHERE id = ? LIMIT 1', { id }, 'jobframework.session.get') end
function NexaJobFrameworkDatabase.GetActiveSessionByCharacter(characterId) return dbCall('Single', 'SELECT s.* FROM nexa_job_sessions s JOIN nexa_job_session_members m ON m.session_id = s.id WHERE m.character_id = ? AND s.status IN (?, ?) LIMIT 1', { characterId, NEXA_JOB_SESSION_STATUS.created, NEXA_JOB_SESSION_STATUS.active }, 'jobframework.session.character') end
function NexaJobFrameworkDatabase.ListActiveSessions() return dbCall('Query', 'SELECT * FROM nexa_job_sessions WHERE status IN (?, ?) ORDER BY id DESC LIMIT 500', { NEXA_JOB_SESSION_STATUS.created, NEXA_JOB_SESSION_STATUS.active }, 'jobframework.session.active') end
function NexaJobFrameworkDatabase.SetSessionStatus(id, status, reason) return dbCall('Update', 'UPDATE nexa_job_sessions SET status = ?, failure_reason = ?, completed_at = CASE WHEN ? = ? THEN CURRENT_TIMESTAMP ELSE completed_at END, cancelled_at = CASE WHEN ? = ? THEN CURRENT_TIMESTAMP ELSE cancelled_at END, version = version + 1 WHERE id = ?', { status, reason, status, NEXA_JOB_SESSION_STATUS.completed, status, NEXA_JOB_SESSION_STATUS.cancelled, id }, 'jobframework.session.status') end
function NexaJobFrameworkDatabase.InsertMember(m) return dbCall('Insert', 'INSERT INTO nexa_job_session_members (session_id, character_id, member_role, status, contribution, metadata) VALUES (?, ?, ?, ?, ?, ?)', { m.session_id, m.character_id, m.member_role, m.status, encode(m.contribution), encode(m.metadata) }, 'jobframework.member.insert') end
function NexaJobFrameworkDatabase.GetProgress(sessionId, taskId, characterId) return dbCall('Single', 'SELECT * FROM nexa_job_task_progress WHERE session_id = ? AND task_id = ? AND character_id = ? LIMIT 1', { sessionId, taskId, characterId }, 'jobframework.progress.get') end
function NexaJobFrameworkDatabase.UpsertProgress(p) return dbCall('Insert', 'INSERT INTO nexa_job_task_progress (session_id, task_id, character_id, progress_value, status, started_at, completed_at, metadata) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CASE WHEN ? = ? THEN CURRENT_TIMESTAMP ELSE NULL END, ?) ON DUPLICATE KEY UPDATE progress_value = VALUES(progress_value), status = VALUES(status), completed_at = VALUES(completed_at), version = version + 1, metadata = VALUES(metadata)', { p.session_id, p.task_id, p.character_id, p.progress_value, p.status, p.status, NEXA_JOB_PROGRESS_STATUS.completed, encode(p.metadata) }, 'jobframework.progress.upsert') end
function NexaJobFrameworkDatabase.ListRewards(sessionId) return dbCall('Query', 'SELECT * FROM nexa_job_rewards WHERE session_id = ? ORDER BY id ASC', { sessionId }, 'jobframework.reward.list') end
function NexaJobFrameworkDatabase.InsertReward(r) return dbCall('Insert', 'INSERT INTO nexa_job_rewards (session_id, character_id, reward_type, currency, amount, item_name, item_amount, status, idempotency_key, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { r.session_id, r.character_id, r.reward_type, r.currency, r.amount, r.item_name, r.item_amount, r.status, r.idempotency_key, encode(r.metadata) }, 'jobframework.reward.insert') end
function NexaJobFrameworkDatabase.InsertResourceNode(n) return dbCall('Insert', 'INSERT INTO nexa_job_resource_nodes (node_key, node_type, label, position, radius, resource_item, available_amount, respawn_seconds, tool_requirements, access_rules, anti_afk_policy, status, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { n.node_key, n.node_type, n.label, encode(n.position), n.radius, n.resource_item, n.available_amount, n.respawn_seconds, encode(n.tool_requirements), encode(n.access_rules), encode(n.anti_afk_policy), n.status, encode(n.metadata) }, 'jobframework.node.insert') end
function NexaJobFrameworkDatabase.GetResourceNode(id) return dbCall('Single', 'SELECT * FROM nexa_job_resource_nodes WHERE id = ? OR node_key = ? LIMIT 1', { tonumber(id) or 0, tostring(id) }, 'jobframework.node.get') end
function NexaJobFrameworkDatabase.InsertProductionChain(c) return dbCall('Insert', 'INSERT INTO nexa_job_production_chains (chain_key, label, status, crafting_recipe_id, stages, access_rules, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)', { c.chain_key, c.label, c.status, c.crafting_recipe_id, encode(c.stages), encode(c.access_rules), encode(c.metadata) }, 'jobframework.chain.insert') end
function NexaJobFrameworkDatabase.GetProductionChain(id) return dbCall('Single', 'SELECT * FROM nexa_job_production_chains WHERE id = ? OR chain_key = ? LIMIT 1', { tonumber(id) or 0, tostring(id) }, 'jobframework.chain.get') end
function NexaJobFrameworkDatabase.InsertAudit(a) return dbCall('Insert', 'INSERT INTO nexa_job_audit (job_definition_id, session_id, action, actor_account_id, actor_character_id, before_state, after_state, reason, result, error_code, source_resource, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { a.job_definition_id, a.session_id, a.action, a.actor_account_id, a.actor_character_id, a.before_state and encode(a.before_state) or nil, a.after_state and encode(a.after_state) or nil, a.reason, a.result, a.error_code, a.source_resource, a.correlation_id, encode(a.metadata) }, 'jobframework.audit') end
function NexaJobFrameworkDatabase.GetSchema() return { migration = '140_jobframework_foundation', tables = { 'nexa_job_definitions', 'nexa_job_phases', 'nexa_job_tasks', 'nexa_job_sessions', 'nexa_job_session_members', 'nexa_job_task_progress', 'nexa_job_rewards', 'nexa_job_cooldowns', 'nexa_job_resource_nodes', 'nexa_job_production_chains', 'nexa_job_audit' } } end
