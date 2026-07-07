-- Nexa Roleplay Phase 3 database schema
-- Basis: docs/02_Datenbankmodell.md, detail sections 4.1-4.53

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS schema_migrations (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    version VARCHAR(64) NOT NULL,
    name VARCHAR(128) NOT NULL,
    checksum VARCHAR(128) NOT NULL,
    executed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    executed_by VARCHAR(128) NULL,
    duration_ms INT UNSIGNED NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_schema_migrations_version (version),
    KEY idx_schema_migrations_executed_at (executed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS players (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    primary_identifier VARCHAR(128) NOT NULL,
    display_name VARCHAR(64) NULL,
    first_joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at DATETIME NULL,
    playtime_minutes INT UNSIGNED NOT NULL DEFAULT 0,
    is_banned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_players_primary_identifier (primary_identifier),
    KEY idx_players_last_seen_at (last_seen_at),
    KEY idx_players_is_banned (is_banned)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS player_identifiers (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_id BIGINT UNSIGNED NOT NULL,
    type VARCHAR(32) NOT NULL,
    value VARCHAR(128) NOT NULL,
    first_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_player_identifiers_type_value (type, value),
    KEY idx_player_identifiers_player_id (player_id),
    KEY idx_player_identifiers_type (type),
    KEY idx_player_identifiers_value (value),
    CONSTRAINT fk_player_identifiers_player_id FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS player_sessions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_id BIGINT UNSIGNED NOT NULL,
    source_temp INT UNSIGNED NULL,
    joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    left_at DATETIME NULL,
    duration_seconds INT UNSIGNED NULL,
    ip_hash VARCHAR(128) NULL,
    disconnect_reason VARCHAR(255) NULL,
    PRIMARY KEY (id),
    KEY idx_player_sessions_player_id (player_id),
    KEY idx_player_sessions_joined_at (joined_at),
    KEY idx_player_sessions_left_at (left_at),
    CONSTRAINT fk_player_sessions_player_id FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS characters (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_id BIGINT UNSIGNED NOT NULL,
    citizenid VARCHAR(64) NOT NULL,
    firstname VARCHAR(64) NOT NULL,
    lastname VARCHAR(64) NOT NULL,
    birthdate DATE NOT NULL,
    gender VARCHAR(32) NOT NULL,
    nationality VARCHAR(64) NULL,
    phone_number VARCHAR(32) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_characters_citizenid (citizenid),
    UNIQUE KEY uq_characters_phone_number (phone_number),
    KEY idx_characters_player_id (player_id),
    KEY idx_characters_lastname (lastname),
    KEY idx_characters_is_active (is_active),
    CONSTRAINT fk_characters_player_id FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS character_metadata (
    character_id BIGINT UNSIGNED NOT NULL,
    meta_key VARCHAR(64) NOT NULL,
    meta_value JSON NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (character_id, meta_key),
    KEY idx_character_metadata_meta_key (meta_key),
    CONSTRAINT fk_character_metadata_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS character_status (
    character_id BIGINT UNSIGNED NOT NULL,
    health SMALLINT UNSIGNED NOT NULL DEFAULT 200,
    armor SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    hunger TINYINT UNSIGNED NOT NULL DEFAULT 100,
    thirst TINYINT UNSIGNED NOT NULL DEFAULT 100,
    stress TINYINT UNSIGNED NOT NULL DEFAULT 0,
    is_dead BOOLEAN NOT NULL DEFAULT FALSE,
    last_updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (character_id),
    CONSTRAINT fk_character_status_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS accounts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    account_number VARCHAR(32) NOT NULL,
    owner_type ENUM('character','business','faction','system') NOT NULL,
    owner_id BIGINT UNSIGNED NOT NULL,
    account_type ENUM('checking','savings','business','faction','system') NOT NULL,
    balance BIGINT NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    is_frozen BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_accounts_account_number (account_number),
    KEY idx_accounts_owner (owner_type, owner_id),
    KEY idx_accounts_is_frozen (is_frozen),
    CONSTRAINT chk_accounts_balance CHECK (balance >= 0 OR owner_type = 'system')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS economy_ledger (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    transaction_id VARCHAR(64) NOT NULL,
    from_account_id BIGINT UNSIGNED NULL,
    to_account_id BIGINT UNSIGNED NULL,
    amount BIGINT NOT NULL,
    reason VARCHAR(128) NOT NULL,
    category VARCHAR(64) NOT NULL,
    actor_character_id BIGINT UNSIGNED NULL,
    actor_player_id BIGINT UNSIGNED NULL,
    resource_name VARCHAR(64) NOT NULL,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_economy_ledger_transaction_id (transaction_id),
    KEY idx_economy_ledger_created_at (created_at),
    KEY idx_economy_ledger_category (category),
    KEY idx_economy_ledger_actor_character_id (actor_character_id),
    KEY idx_economy_ledger_from_account_id (from_account_id),
    KEY idx_economy_ledger_to_account_id (to_account_id),
    CONSTRAINT fk_economy_ledger_from_account_id FOREIGN KEY (from_account_id) REFERENCES accounts (id) ON DELETE SET NULL,
    CONSTRAINT fk_economy_ledger_to_account_id FOREIGN KEY (to_account_id) REFERENCES accounts (id) ON DELETE SET NULL,
    CONSTRAINT fk_economy_ledger_actor_character_id FOREIGN KEY (actor_character_id) REFERENCES characters (id) ON DELETE SET NULL,
    CONSTRAINT fk_economy_ledger_actor_player_id FOREIGN KEY (actor_player_id) REFERENCES players (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS bank_transactions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    ledger_id BIGINT UNSIGNED NOT NULL,
    account_id BIGINT UNSIGNED NOT NULL,
    direction ENUM('in','out') NOT NULL,
    amount BIGINT NOT NULL,
    label VARCHAR(128) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_bank_transactions_account_created (account_id, created_at),
    KEY idx_bank_transactions_ledger_id (ledger_id),
    CONSTRAINT fk_bank_transactions_ledger_id FOREIGN KEY (ledger_id) REFERENCES economy_ledger (id) ON DELETE RESTRICT,
    CONSTRAINT fk_bank_transactions_account_id FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS invoices (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    invoice_number VARCHAR(32) NOT NULL,
    from_type VARCHAR(32) NOT NULL,
    from_id BIGINT UNSIGNED NOT NULL,
    to_character_id BIGINT UNSIGNED NOT NULL,
    amount BIGINT NOT NULL,
    reason VARCHAR(128) NOT NULL,
    status ENUM('open','paid','cancelled','overdue') NOT NULL DEFAULT 'open',
    due_at DATETIME NULL,
    paid_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_invoices_invoice_number (invoice_number),
    KEY idx_invoices_to_character_status (to_character_id, status),
    KEY idx_invoices_status_due_at (status, due_at),
    CONSTRAINT fk_invoices_to_character_id FOREIGN KEY (to_character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT chk_invoices_amount CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS item_ledger (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    event_id VARCHAR(64) NOT NULL,
    character_id BIGINT UNSIGNED NULL,
    player_id BIGINT UNSIGNED NULL,
    item_name VARCHAR(64) NOT NULL,
    amount INT NOT NULL,
    action VARCHAR(64) NOT NULL,
    reason VARCHAR(128) NOT NULL,
    resource_name VARCHAR(64) NOT NULL,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_item_ledger_event_id (event_id),
    KEY idx_item_ledger_character_id (character_id),
    KEY idx_item_ledger_player_id (player_id),
    KEY idx_item_ledger_item_name (item_name),
    KEY idx_item_ledger_created_at (created_at),
    CONSTRAINT fk_item_ledger_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE SET NULL,
    CONSTRAINT fk_item_ledger_player_id FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS vehicles (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_character_id BIGINT UNSIGNED NULL,
    plate VARCHAR(16) NOT NULL,
    model VARCHAR(64) NOT NULL,
    vehicle_type VARCHAR(32) NOT NULL,
    status ENUM('active','stored','impounded','seized','deleted') NOT NULL DEFAULT 'active',
    garage_name VARCHAR(64) NULL,
    fuel_level DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    engine_health DECIMAL(8,2) NOT NULL DEFAULT 1000.00,
    body_health DECIMAL(8,2) NOT NULL DEFAULT 1000.00,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_vehicles_plate (plate),
    KEY idx_vehicles_owner_character_id (owner_character_id),
    KEY idx_vehicles_status (status),
    CONSTRAINT fk_vehicles_owner_character_id FOREIGN KEY (owner_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS vehicle_keys (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    key_type ENUM('owner','shared','temporary','job','faction') NOT NULL,
    granted_by_character_id BIGINT UNSIGNED NULL,
    expires_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_vehicle_keys_vehicle_character_type (vehicle_id, character_id, key_type),
    KEY idx_vehicle_keys_character_id (character_id),
    KEY idx_vehicle_keys_vehicle_id (vehicle_id),
    CONSTRAINT fk_vehicle_keys_vehicle_id FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
    CONSTRAINT fk_vehicle_keys_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_vehicle_keys_granted_by_character_id FOREIGN KEY (granted_by_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS vehicle_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_id BIGINT UNSIGNED NOT NULL,
    event_type VARCHAR(64) NOT NULL,
    actor_character_id BIGINT UNSIGNED NULL,
    old_value JSON NULL,
    new_value JSON NULL,
    reason VARCHAR(128) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_vehicle_history_vehicle_id (vehicle_id),
    KEY idx_vehicle_history_event_type (event_type),
    KEY idx_vehicle_history_created_at (created_at),
    CONSTRAINT fk_vehicle_history_vehicle_id FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
    CONSTRAINT fk_vehicle_history_actor_character_id FOREIGN KEY (actor_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS properties (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    property_code VARCHAR(32) NOT NULL,
    name VARCHAR(64) NOT NULL,
    property_type VARCHAR(32) NOT NULL,
    status ENUM('available','owned','rented','locked','disabled') NOT NULL DEFAULT 'available',
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_properties_property_code (property_code),
    KEY idx_properties_status (status),
    KEY idx_properties_property_type (property_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS property_units (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    property_id BIGINT UNSIGNED NOT NULL,
    unit_code VARCHAR(32) NOT NULL,
    owner_character_id BIGINT UNSIGNED NULL,
    label VARCHAR(64) NOT NULL,
    status ENUM('available','owned','rented','disabled') NOT NULL DEFAULT 'available',
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_property_units_property_unit (property_id, unit_code),
    KEY idx_property_units_owner_character_id (owner_character_id),
    KEY idx_property_units_status (status),
    CONSTRAINT fk_property_units_property_id FOREIGN KEY (property_id) REFERENCES properties (id) ON DELETE CASCADE,
    CONSTRAINT fk_property_units_owner_character_id FOREIGN KEY (owner_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS property_access (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    property_unit_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    access_type ENUM('owner','tenant','guest','temporary') NOT NULL,
    granted_by_character_id BIGINT UNSIGNED NULL,
    expires_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_property_access_unit_character (property_unit_id, character_id),
    KEY idx_property_access_character_id (character_id),
    KEY idx_property_access_property_unit_id (property_unit_id),
    CONSTRAINT fk_property_access_property_unit_id FOREIGN KEY (property_unit_id) REFERENCES property_units (id) ON DELETE CASCADE,
    CONSTRAINT fk_property_access_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_property_access_granted_by_character_id FOREIGN KEY (granted_by_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS jobs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(64) NOT NULL,
    label VARCHAR(64) NOT NULL,
    job_type VARCHAR(32) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_jobs_name (name),
    KEY idx_jobs_is_active (is_active),
    KEY idx_jobs_job_type (job_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS job_grades (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    job_id BIGINT UNSIGNED NOT NULL,
    grade_level INT UNSIGNED NOT NULL,
    name VARCHAR(64) NOT NULL,
    label VARCHAR(64) NOT NULL,
    salary BIGINT NOT NULL DEFAULT 0,
    permissions JSON NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_job_grades_job_level (job_id, grade_level),
    KEY idx_job_grades_job_id (job_id),
    CONSTRAINT fk_job_grades_job_id FOREIGN KEY (job_id) REFERENCES jobs (id) ON DELETE CASCADE,
    CONSTRAINT chk_job_grades_salary CHECK (salary >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS character_jobs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    job_id BIGINT UNSIGNED NOT NULL,
    grade_id BIGINT UNSIGNED NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    assigned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at DATETIME NULL,
    PRIMARY KEY (id),
    KEY idx_character_jobs_character_id (character_id),
    KEY idx_character_jobs_job_id (job_id),
    KEY idx_character_jobs_active (character_id, ended_at),
    CONSTRAINT fk_character_jobs_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_character_jobs_job_id FOREIGN KEY (job_id) REFERENCES jobs (id) ON DELETE CASCADE,
    CONSTRAINT fk_character_jobs_grade_id FOREIGN KEY (grade_id) REFERENCES job_grades (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS businesses (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    business_code VARCHAR(32) NOT NULL,
    name VARCHAR(64) NOT NULL,
    label VARCHAR(64) NOT NULL,
    status ENUM('active','inactive','suspended','closed') NOT NULL DEFAULT 'active',
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_businesses_business_code (business_code),
    UNIQUE KEY uq_businesses_name (name),
    KEY idx_businesses_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS business_members (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    business_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    role_name VARCHAR(64) NOT NULL,
    joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    left_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_business_members_business_character (business_id, character_id),
    KEY idx_business_members_character_id (character_id),
    KEY idx_business_members_business_id (business_id),
    CONSTRAINT fk_business_members_business_id FOREIGN KEY (business_id) REFERENCES businesses (id) ON DELETE CASCADE,
    CONSTRAINT fk_business_members_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS factions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(64) NOT NULL,
    label VARCHAR(64) NOT NULL,
    faction_type VARCHAR(32) NOT NULL,
    status ENUM('active','inactive','disabled') NOT NULL DEFAULT 'active',
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_factions_name (name),
    KEY idx_factions_status (status),
    KEY idx_factions_faction_type (faction_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS faction_grades (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    faction_id BIGINT UNSIGNED NOT NULL,
    grade_level INT UNSIGNED NOT NULL,
    name VARCHAR(64) NOT NULL,
    label VARCHAR(64) NOT NULL,
    permissions JSON NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_faction_grades_faction_level (faction_id, grade_level),
    KEY idx_faction_grades_faction_id (faction_id),
    CONSTRAINT fk_faction_grades_faction_id FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS faction_members (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    faction_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    grade_id BIGINT UNSIGNED NOT NULL,
    callsign VARCHAR(16) NULL,
    joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    left_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_faction_members_faction_character (faction_id, character_id),
    KEY idx_faction_members_character_id (character_id),
    KEY idx_faction_members_faction_id (faction_id),
    CONSTRAINT fk_faction_members_faction_id FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE CASCADE,
    CONSTRAINT fk_faction_members_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_faction_members_grade_id FOREIGN KEY (grade_id) REFERENCES faction_grades (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS duty_sessions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    duty_type VARCHAR(32) NOT NULL,
    duty_ref_id BIGINT UNSIGNED NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at DATETIME NULL,
    duration_seconds INT UNSIGNED NULL,
    PRIMARY KEY (id),
    KEY idx_duty_sessions_character_id (character_id),
    KEY idx_duty_sessions_started_at (started_at),
    KEY idx_duty_sessions_active (character_id, ended_at),
    CONSTRAINT fk_duty_sessions_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS dispatch_calls (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    call_number VARCHAR(32) NOT NULL,
    caller_character_id BIGINT UNSIGNED NULL,
    status ENUM('open','assigned','closed','cancelled') NOT NULL DEFAULT 'open',
    priority TINYINT UNSIGNED NOT NULL DEFAULT 3,
    category VARCHAR(64) NOT NULL,
    location JSON NULL,
    description TEXT NULL,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_dispatch_calls_call_number (call_number),
    KEY idx_dispatch_calls_status_created (status, created_at),
    KEY idx_dispatch_calls_caller_character_id (caller_character_id),
    CONSTRAINT fk_dispatch_calls_caller_character_id FOREIGN KEY (caller_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS police_records (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    record_type VARCHAR(64) NOT NULL,
    title VARCHAR(128) NOT NULL,
    summary TEXT NULL,
    status ENUM('open','closed','archived') NOT NULL DEFAULT 'open',
    created_by_character_id BIGINT UNSIGNED NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_police_records_character_id (character_id),
    KEY idx_police_records_status (status),
    KEY idx_police_records_created_at (created_at),
    CONSTRAINT fk_police_records_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_police_records_created_by_character_id FOREIGN KEY (created_by_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS incident_reports (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    case_number VARCHAR(32) NOT NULL,
    title VARCHAR(128) NOT NULL,
    summary TEXT NULL,
    status ENUM('draft','open','closed','archived') NOT NULL DEFAULT 'draft',
    created_by_character_id BIGINT UNSIGNED NULL,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_incident_reports_case_number (case_number),
    KEY idx_incident_reports_status (status),
    KEY idx_incident_reports_created_at (created_at),
    CONSTRAINT fk_incident_reports_created_by_character_id FOREIGN KEY (created_by_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS warrants (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    warrant_number VARCHAR(32) NOT NULL,
    target_character_id BIGINT UNSIGNED NOT NULL,
    issued_by_character_id BIGINT UNSIGNED NULL,
    reason TEXT NOT NULL,
    status ENUM('active','served','revoked','expired') NOT NULL DEFAULT 'active',
    issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_warrants_warrant_number (warrant_number),
    KEY idx_warrants_target_status (target_character_id, status),
    KEY idx_warrants_status (status),
    CONSTRAINT fk_warrants_target_character_id FOREIGN KEY (target_character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_warrants_issued_by_character_id FOREIGN KEY (issued_by_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fines (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    fine_number VARCHAR(32) NOT NULL,
    target_character_id BIGINT UNSIGNED NOT NULL,
    issued_by_character_id BIGINT UNSIGNED NULL,
    amount BIGINT NOT NULL,
    reason VARCHAR(255) NOT NULL,
    status ENUM('open','paid','cancelled') NOT NULL DEFAULT 'open',
    issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_fines_fine_number (fine_number),
    KEY idx_fines_target_status (target_character_id, status),
    KEY idx_fines_status (status),
    CONSTRAINT fk_fines_target_character_id FOREIGN KEY (target_character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_fines_issued_by_character_id FOREIGN KEY (issued_by_character_id) REFERENCES characters (id) ON DELETE SET NULL,
    CONSTRAINT chk_fines_amount CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS evidence_items (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    evidence_number VARCHAR(32) NOT NULL,
    incident_report_id BIGINT UNSIGNED NULL,
    character_id BIGINT UNSIGNED NULL,
    item_name VARCHAR(64) NOT NULL,
    description TEXT NULL,
    storage_ref VARCHAR(128) NULL,
    status ENUM('stored','released','destroyed','transferred') NOT NULL DEFAULT 'stored',
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_evidence_items_evidence_number (evidence_number),
    KEY idx_evidence_items_incident_report_id (incident_report_id),
    KEY idx_evidence_items_character_id (character_id),
    KEY idx_evidence_items_status (status),
    CONSTRAINT fk_evidence_items_incident_report_id FOREIGN KEY (incident_report_id) REFERENCES incident_reports (id) ON DELETE SET NULL,
    CONSTRAINT fk_evidence_items_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ems_records (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    record_type VARCHAR(64) NOT NULL,
    summary TEXT NULL,
    status ENUM('open','closed','archived') NOT NULL DEFAULT 'open',
    created_by_character_id BIGINT UNSIGNED NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_ems_records_character_id (character_id),
    KEY idx_ems_records_status (status),
    KEY idx_ems_records_created_at (created_at),
    CONSTRAINT fk_ems_records_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_ems_records_created_by_character_id FOREIGN KEY (created_by_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS medical_treatments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    ems_record_id BIGINT UNSIGNED NOT NULL,
    treated_by_character_id BIGINT UNSIGNED NULL,
    treatment_type VARCHAR(64) NOT NULL,
    notes TEXT NULL,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_medical_treatments_ems_record_id (ems_record_id),
    KEY idx_medical_treatments_created_at (created_at),
    CONSTRAINT fk_medical_treatments_ems_record_id FOREIGN KEY (ems_record_id) REFERENCES ems_records (id) ON DELETE CASCADE,
    CONSTRAINT fk_medical_treatments_treated_by_character_id FOREIGN KEY (treated_by_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS gangs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(64) NOT NULL,
    label VARCHAR(64) NOT NULL,
    status ENUM('active','inactive','disbanded') NOT NULL DEFAULT 'active',
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_gangs_name (name),
    KEY idx_gangs_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS gang_members (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    gang_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    rank_name VARCHAR(64) NOT NULL,
    joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    left_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_gang_members_gang_character (gang_id, character_id),
    KEY idx_gang_members_character_id (character_id),
    KEY idx_gang_members_gang_id (gang_id),
    CONSTRAINT fk_gang_members_gang_id FOREIGN KEY (gang_id) REFERENCES gangs (id) ON DELETE CASCADE,
    CONSTRAINT fk_gang_members_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS blackmarket_orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_number VARCHAR(32) NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    item_name VARCHAR(64) NOT NULL,
    amount INT UNSIGNED NOT NULL,
    price BIGINT NOT NULL,
    status ENUM('created','paid','delivered','failed','cancelled') NOT NULL DEFAULT 'created',
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_blackmarket_orders_order_number (order_number),
    KEY idx_blackmarket_orders_character_id (character_id),
    KEY idx_blackmarket_orders_status (status),
    KEY idx_blackmarket_orders_created_at (created_at),
    CONSTRAINT fk_blackmarket_orders_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT chk_blackmarket_orders_amount CHECK (amount > 0),
    CONSTRAINT chk_blackmarket_orders_price CHECK (price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS heist_runs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    heist_type VARCHAR(64) NOT NULL,
    leader_character_id BIGINT UNSIGNED NOT NULL,
    status ENUM('started','completed','failed','cancelled') NOT NULL DEFAULT 'started',
    payout_total BIGINT NOT NULL DEFAULT 0,
    metadata JSON NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at DATETIME NULL,
    PRIMARY KEY (id),
    KEY idx_heist_runs_heist_type (heist_type),
    KEY idx_heist_runs_status (status),
    KEY idx_heist_runs_started_at (started_at),
    CONSTRAINT fk_heist_runs_leader_character_id FOREIGN KEY (leader_character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT chk_heist_runs_payout_total CHECK (payout_total >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS phone_numbers (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    number VARCHAR(32) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_phone_numbers_number (number),
    KEY idx_phone_numbers_character_id (character_id),
    KEY idx_phone_numbers_is_active (is_active),
    CONSTRAINT fk_phone_numbers_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS phone_contacts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_character_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(64) NOT NULL,
    number VARCHAR(32) NOT NULL,
    notes VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_phone_contacts_owner_character_id (owner_character_id),
    KEY idx_phone_contacts_number (number),
    CONSTRAINT fk_phone_contacts_owner_character_id FOREIGN KEY (owner_character_id) REFERENCES characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS phone_messages (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    sender_number VARCHAR(32) NOT NULL,
    receiver_number VARCHAR(32) NOT NULL,
    message TEXT NOT NULL,
    status ENUM('sent','delivered','read','deleted') NOT NULL DEFAULT 'sent',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_phone_messages_sender_number (sender_number),
    KEY idx_phone_messages_receiver_number (receiver_number),
    KEY idx_phone_messages_created_at (created_at),
    KEY idx_phone_messages_receiver_created (receiver_number, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS document_types (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(64) NOT NULL,
    label VARCHAR(64) NOT NULL,
    requires_signature BOOLEAN NOT NULL DEFAULT FALSE,
    default_valid_days INT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    UNIQUE KEY uq_document_types_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS documents (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    document_number VARCHAR(32) NOT NULL,
    document_type_id BIGINT UNSIGNED NOT NULL,
    owner_character_id BIGINT UNSIGNED NOT NULL,
    issued_by_character_id BIGINT UNSIGNED NULL,
    status ENUM('valid','revoked','expired') NOT NULL DEFAULT 'valid',
    data JSON NULL,
    issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_documents_document_number (document_number),
    KEY idx_documents_owner_character_id (owner_character_id),
    KEY idx_documents_status (status),
    KEY idx_documents_expires_at (expires_at),
    CONSTRAINT fk_documents_document_type_id FOREIGN KEY (document_type_id) REFERENCES document_types (id) ON DELETE RESTRICT,
    CONSTRAINT fk_documents_owner_character_id FOREIGN KEY (owner_character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_documents_issued_by_character_id FOREIGN KEY (issued_by_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS license_types (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(64) NOT NULL,
    label VARCHAR(64) NOT NULL,
    category VARCHAR(64) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    UNIQUE KEY uq_license_types_name (name),
    KEY idx_license_types_category (category),
    KEY idx_license_types_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS licenses (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    license_type_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    status ENUM('active','suspended','revoked','expired') NOT NULL DEFAULT 'active',
    issued_by_character_id BIGINT UNSIGNED NULL,
    issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_licenses_type_character (license_type_id, character_id),
    KEY idx_licenses_character_id (character_id),
    KEY idx_licenses_status (status),
    KEY idx_licenses_expires_at (expires_at),
    CONSTRAINT fk_licenses_license_type_id FOREIGN KEY (license_type_id) REFERENCES license_types (id) ON DELETE RESTRICT,
    CONSTRAINT fk_licenses_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_licenses_issued_by_character_id FOREIGN KEY (issued_by_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS audit_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    event_type VARCHAR(64) NOT NULL,
    severity ENUM('info','warning','critical') NOT NULL DEFAULT 'info',
    actor_player_id BIGINT UNSIGNED NULL,
    actor_character_id BIGINT UNSIGNED NULL,
    target_type VARCHAR(64) NULL,
    target_id BIGINT UNSIGNED NULL,
    resource_name VARCHAR(64) NOT NULL,
    action VARCHAR(128) NOT NULL,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_audit_events_event_type (event_type),
    KEY idx_audit_events_severity (severity),
    KEY idx_audit_events_created_at (created_at),
    KEY idx_audit_events_actor_character_id (actor_character_id),
    KEY idx_audit_events_resource_name (resource_name),
    CONSTRAINT fk_audit_events_actor_player_id FOREIGN KEY (actor_player_id) REFERENCES players (id) ON DELETE SET NULL,
    CONSTRAINT fk_audit_events_actor_character_id FOREIGN KEY (actor_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS security_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_id BIGINT UNSIGNED NULL,
    character_id BIGINT UNSIGNED NULL,
    event_name VARCHAR(128) NOT NULL,
    reason VARCHAR(255) NOT NULL,
    severity ENUM('low','medium','high','critical') NOT NULL DEFAULT 'low',
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_security_events_player_id (player_id),
    KEY idx_security_events_character_id (character_id),
    KEY idx_security_events_severity (severity),
    KEY idx_security_events_created_at (created_at),
    KEY idx_security_events_player_created (player_id, created_at),
    CONSTRAINT fk_security_events_player_id FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE SET NULL,
    CONSTRAINT fk_security_events_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS rate_limit_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_id BIGINT UNSIGNED NULL,
    event_name VARCHAR(128) NOT NULL,
    count INT UNSIGNED NOT NULL,
    window_seconds INT UNSIGNED NOT NULL,
    action_taken ENUM('none','warn','drop','ban_review') NOT NULL DEFAULT 'none',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_rate_limit_events_player_id (player_id),
    KEY idx_rate_limit_events_event_name (event_name),
    KEY idx_rate_limit_events_created_at (created_at),
    CONSTRAINT fk_rate_limit_events_player_id FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS admin_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    admin_player_id BIGINT UNSIGNED NOT NULL,
    admin_character_id BIGINT UNSIGNED NULL,
    action VARCHAR(128) NOT NULL,
    target_type VARCHAR(64) NOT NULL,
    target_id BIGINT UNSIGNED NULL,
    reason VARCHAR(255) NOT NULL,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_admin_logs_admin_player_id (admin_player_id),
    KEY idx_admin_logs_action (action),
    KEY idx_admin_logs_created_at (created_at),
    CONSTRAINT fk_admin_logs_admin_player_id FOREIGN KEY (admin_player_id) REFERENCES players (id) ON DELETE RESTRICT,
    CONSTRAINT fk_admin_logs_admin_character_id FOREIGN KEY (admin_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS bans (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_id BIGINT UNSIGNED NOT NULL,
    banned_by_player_id BIGINT UNSIGNED NULL,
    reason TEXT NOT NULL,
    expires_at DATETIME NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at DATETIME NULL,
    PRIMARY KEY (id),
    KEY idx_bans_player_id (player_id),
    KEY idx_bans_is_active (is_active),
    KEY idx_bans_expires_at (expires_at),
    CONSTRAINT fk_bans_player_id FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE,
    CONSTRAINT fk_bans_banned_by_player_id FOREIGN KEY (banned_by_player_id) REFERENCES players (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS resource_settings (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    resource_name VARCHAR(64) NOT NULL,
    setting_key VARCHAR(64) NOT NULL,
    setting_value JSON NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_resource_settings_resource_key (resource_name, setting_key),
    KEY idx_resource_settings_resource_name (resource_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS feature_flags (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    flag_name VARCHAR(64) NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    environment ENUM('dev','staging','prod') NOT NULL,
    metadata JSON NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_feature_flags_flag_environment (flag_name, environment),
    KEY idx_feature_flags_is_enabled (is_enabled),
    KEY idx_feature_flags_environment (environment)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name, checksum, executed_by, duration_ms)
VALUES ('20260705_1200', 'create_phase_3_schema', 'managed-by-phase-3-validation', 'phase_3_migration', 0)
ON DUPLICATE KEY UPDATE name = VALUES(name);

SET FOREIGN_KEY_CHECKS = 1;
