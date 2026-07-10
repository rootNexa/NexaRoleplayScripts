NexaCraftingDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_CRAFTING_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'crafting.db' }) end

function NexaCraftingDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '131_crafting_foundation',
        description = 'Create crafting recipes stations jobs knowledge and audit.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crafting_recipes (
                id INT AUTO_INCREMENT PRIMARY KEY,
                recipe_key VARCHAR(64) UNIQUE NOT NULL,
                label VARCHAR(128) NOT NULL,
                crafting_type VARCHAR(32) NOT NULL,
                status VARCHAR(32) NOT NULL,
                visibility VARCHAR(32) NOT NULL,
                organization_id INT NULL,
                required_rank_id INT NULL,
                station_type VARCHAR(64) NULL,
                duration_ms INT NOT NULL DEFAULT 0,
                batch_limit INT NOT NULL DEFAULT 1,
                quality_policy LONGTEXT NULL,
                tool_requirements LONGTEXT NULL,
                access_rules LONGTEXT NULL,
                version INT NOT NULL DEFAULT 1,
                created_by BIGINT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                deleted_at TIMESTAMP NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'crafting.migration.recipes' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crafting_recipe_inputs (
                id INT AUTO_INCREMENT PRIMARY KEY,
                recipe_id INT NOT NULL,
                item_name VARCHAR(64) NOT NULL,
                amount INT NOT NULL,
                consume TINYINT(1) NOT NULL DEFAULT 1,
                minimum_quality INT NULL,
                metadata_requirements LONGTEXT NULL,
                position INT NOT NULL DEFAULT 1,
                metadata LONGTEXT NULL
            )]], {}, { category = 'crafting.migration.inputs' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crafting_recipe_outputs (
                id INT AUTO_INCREMENT PRIMARY KEY,
                recipe_id INT NOT NULL,
                item_name VARCHAR(64) NOT NULL,
                amount INT NOT NULL,
                probability INT NOT NULL DEFAULT 100,
                quality_rule LONGTEXT NULL,
                metadata_template LONGTEXT NULL,
                position INT NOT NULL DEFAULT 1,
                metadata LONGTEXT NULL
            )]], {}, { category = 'crafting.migration.outputs' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crafting_stations (
                id INT AUTO_INCREMENT PRIMARY KEY,
                station_key VARCHAR(64) UNIQUE NOT NULL,
                label VARCHAR(128) NOT NULL,
                station_type VARCHAR(64) NOT NULL,
                status VARCHAR(32) NOT NULL,
                property_id INT NULL,
                organization_id INT NULL,
                position LONGTEXT NULL,
                routing_bucket_policy LONGTEXT NULL,
                capacity INT NOT NULL DEFAULT 1,
                access_rules LONGTEXT NULL,
                configuration LONGTEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL
            )]], {}, { category = 'crafting.migration.stations' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crafting_jobs (
                id INT AUTO_INCREMENT PRIMARY KEY,
                recipe_id INT NOT NULL,
                station_id INT NOT NULL,
                character_id BIGINT NULL,
                organization_id INT NULL,
                batch_amount INT NOT NULL,
                status VARCHAR(32) NOT NULL,
                started_at TIMESTAMP NULL,
                completes_at TIMESTAMP NULL,
                completed_at TIMESTAMP NULL,
                cancelled_at TIMESTAMP NULL,
                input_reservation LONGTEXT NULL,
                output_inventory_id VARCHAR(64) NULL,
                quality_result INT NULL,
                idempotency_key VARCHAR(128) UNIQUE NULL,
                correlation_id VARCHAR(128) NULL,
                error_code VARCHAR(64) NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'crafting.migration.jobs' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crafting_known_recipes (
                id INT AUTO_INCREMENT PRIMARY KEY,
                recipe_id INT NOT NULL,
                knowledge_type VARCHAR(32) NOT NULL,
                holder_type VARCHAR(32) NOT NULL,
                holder_id VARCHAR(64) NOT NULL,
                granted_by BIGINT NULL,
                granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                revoked_at TIMESTAMP NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'crafting.migration.knowledge' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crafting_audit (
                id INT AUTO_INCREMENT PRIMARY KEY,
                recipe_id INT NULL,
                station_id INT NULL,
                job_id INT NULL,
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
            )]], {}, { category = 'crafting.migration.audit' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaCraftingDatabase.InsertRecipe(r) return dbCall('Insert', 'INSERT INTO nexa_crafting_recipes (recipe_key, label, crafting_type, status, visibility, organization_id, required_rank_id, station_type, duration_ms, batch_limit, quality_policy, tool_requirements, access_rules, created_by, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { r.recipe_key, r.label, r.crafting_type, r.status, r.visibility, r.organization_id, r.required_rank_id, r.station_type, r.duration_ms, r.batch_limit, encode(r.quality_policy), encode(r.tool_requirements), encode(r.access_rules), r.created_by, encode(r.metadata) }, 'crafting.recipe.insert') end
function NexaCraftingDatabase.GetRecipe(idOrKey) local id = tonumber(idOrKey); if id then return dbCall('Single', 'SELECT * FROM nexa_crafting_recipes WHERE id = ? AND deleted_at IS NULL LIMIT 1', { id }, 'crafting.recipe.get') end; return dbCall('Single', 'SELECT * FROM nexa_crafting_recipes WHERE recipe_key = ? AND deleted_at IS NULL LIMIT 1', { tostring(idOrKey) }, 'crafting.recipe.key') end
function NexaCraftingDatabase.ListRecipes() return dbCall('Query', 'SELECT * FROM nexa_crafting_recipes WHERE deleted_at IS NULL ORDER BY id DESC LIMIT 500', {}, 'crafting.recipe.list') end
function NexaCraftingDatabase.SetRecipeStatus(id, status) return dbCall('Update', 'UPDATE nexa_crafting_recipes SET status = ?, version = version + 1 WHERE id = ?', { status, id }, 'crafting.recipe.status') end
function NexaCraftingDatabase.InsertInput(i) return dbCall('Insert', 'INSERT INTO nexa_crafting_recipe_inputs (recipe_id, item_name, amount, consume, minimum_quality, metadata_requirements, position, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', { i.recipe_id, i.item_name, i.amount, i.consume and 1 or 0, i.minimum_quality, encode(i.metadata_requirements), i.position, encode(i.metadata) }, 'crafting.input.insert') end
function NexaCraftingDatabase.InsertOutput(o) return dbCall('Insert', 'INSERT INTO nexa_crafting_recipe_outputs (recipe_id, item_name, amount, probability, quality_rule, metadata_template, position, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', { o.recipe_id, o.item_name, o.amount, o.probability, encode(o.quality_rule), encode(o.metadata_template), o.position, encode(o.metadata) }, 'crafting.output.insert') end
function NexaCraftingDatabase.ListInputs(recipeId) return dbCall('Query', 'SELECT * FROM nexa_crafting_recipe_inputs WHERE recipe_id = ? ORDER BY position ASC', { recipeId }, 'crafting.input.list') end
function NexaCraftingDatabase.ListOutputs(recipeId) return dbCall('Query', 'SELECT * FROM nexa_crafting_recipe_outputs WHERE recipe_id = ? ORDER BY position ASC', { recipeId }, 'crafting.output.list') end
function NexaCraftingDatabase.InsertStation(s) return dbCall('Insert', 'INSERT INTO nexa_crafting_stations (station_key, label, station_type, status, property_id, organization_id, position, routing_bucket_policy, capacity, access_rules, configuration, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { s.station_key, s.label, s.station_type, s.status, s.property_id, s.organization_id, encode(s.position), encode(s.routing_bucket_policy), s.capacity, encode(s.access_rules), encode(s.configuration), encode(s.metadata) }, 'crafting.station.insert') end
function NexaCraftingDatabase.GetStation(idOrKey) local id = tonumber(idOrKey); if id then return dbCall('Single', 'SELECT * FROM nexa_crafting_stations WHERE id = ? LIMIT 1', { id }, 'crafting.station.get') end; return dbCall('Single', 'SELECT * FROM nexa_crafting_stations WHERE station_key = ? LIMIT 1', { tostring(idOrKey) }, 'crafting.station.key') end
function NexaCraftingDatabase.ListStations() return dbCall('Query', 'SELECT * FROM nexa_crafting_stations ORDER BY id DESC LIMIT 500', {}, 'crafting.station.list') end
function NexaCraftingDatabase.InsertJob(j) return dbCall('Insert', 'INSERT INTO nexa_crafting_jobs (recipe_id, station_id, character_id, organization_id, batch_amount, status, started_at, completes_at, input_reservation, output_inventory_id, quality_result, idempotency_key, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, FROM_UNIXTIME(?), ?, ?, ?, ?, ?, ?)', { j.recipe_id, j.station_id, j.character_id, j.organization_id, j.batch_amount, j.status, j.completes_at, encode(j.input_reservation), j.output_inventory_id, j.quality_result, j.idempotency_key, j.correlation_id, encode(j.metadata) }, 'crafting.job.insert') end
function NexaCraftingDatabase.GetJob(id) return dbCall('Single', 'SELECT * FROM nexa_crafting_jobs WHERE id = ? LIMIT 1', { id }, 'crafting.job.get') end
function NexaCraftingDatabase.ListJobs() return dbCall('Query', 'SELECT * FROM nexa_crafting_jobs ORDER BY id DESC LIMIT 500', {}, 'crafting.job.list') end
function NexaCraftingDatabase.SetJobStatus(id, status, quality, errorCode) return dbCall('Update', 'UPDATE nexa_crafting_jobs SET status = ?, quality_result = COALESCE(?, quality_result), error_code = ?, completed_at = CASE WHEN ? = ? THEN CURRENT_TIMESTAMP ELSE completed_at END, cancelled_at = CASE WHEN ? = ? THEN CURRENT_TIMESTAMP ELSE cancelled_at END WHERE id = ?', { status, quality, errorCode, status, NEXA_CRAFTING_JOB_STATUS.completed, status, NEXA_CRAFTING_JOB_STATUS.cancelled, id }, 'crafting.job.status') end
function NexaCraftingDatabase.InsertKnowledge(k) return dbCall('Insert', 'INSERT INTO nexa_crafting_known_recipes (recipe_id, knowledge_type, holder_type, holder_id, granted_by, metadata) VALUES (?, ?, ?, ?, ?, ?)', { k.recipe_id, k.knowledge_type, k.holder_type, tostring(k.holder_id), k.granted_by, encode(k.metadata) }, 'crafting.knowledge.insert') end
function NexaCraftingDatabase.RevokeKnowledge(recipeId, holderType, holderId) return dbCall('Update', 'UPDATE nexa_crafting_known_recipes SET revoked_at = CURRENT_TIMESTAMP WHERE recipe_id = ? AND holder_type = ? AND holder_id = ?', { recipeId, holderType, tostring(holderId) }, 'crafting.knowledge.revoke') end
function NexaCraftingDatabase.GetKnowledge(recipeId, holderType, holderId) return dbCall('Single', 'SELECT * FROM nexa_crafting_known_recipes WHERE recipe_id = ? AND holder_type = ? AND holder_id = ? AND revoked_at IS NULL LIMIT 1', { recipeId, holderType, tostring(holderId) }, 'crafting.knowledge.get') end
function NexaCraftingDatabase.InsertAudit(a) return dbCall('Insert', 'INSERT INTO nexa_crafting_audit (recipe_id, station_id, job_id, action, actor_account_id, actor_character_id, before_state, after_state, reason, result, error_code, source_resource, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { a.recipe_id, a.station_id, a.job_id, a.action, a.actor_account_id, a.actor_character_id, a.before_state and encode(a.before_state) or nil, a.after_state and encode(a.after_state) or nil, a.reason, a.result, a.error_code, a.source_resource, a.correlation_id, encode(a.metadata) }, 'crafting.audit') end
function NexaCraftingDatabase.GetSchema() return { migration = '131_crafting_foundation', tables = { 'nexa_crafting_recipes', 'nexa_crafting_recipe_inputs', 'nexa_crafting_recipe_outputs', 'nexa_crafting_stations', 'nexa_crafting_jobs', 'nexa_crafting_known_recipes', 'nexa_crafting_audit' } } end
