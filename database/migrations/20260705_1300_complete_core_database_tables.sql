-- Nexa Roleplay Phase 3.1 database completion
-- Basis: ADR-003 accepted scope for core and Phase 4 readiness.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS permission_roles (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(64) NOT NULL,
    label VARCHAR(64) NOT NULL,
    scope ENUM('global','job','faction','business','system') NOT NULL DEFAULT 'global',
    priority INT NOT NULL DEFAULT 0,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_permission_roles_name (name),
    KEY idx_permission_roles_scope (scope),
    KEY idx_permission_roles_priority (priority),
    KEY idx_permission_roles_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS role_permissions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    role_id BIGINT UNSIGNED NOT NULL,
    permission VARCHAR(128) NOT NULL,
    is_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_role_permissions_role_permission (role_id, permission),
    KEY idx_role_permissions_permission (permission),
    KEY idx_role_permissions_is_allowed (is_allowed),
    CONSTRAINT fk_role_permissions_role_id FOREIGN KEY (role_id) REFERENCES permission_roles (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS player_roles (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_id BIGINT UNSIGNED NOT NULL,
    role_id BIGINT UNSIGNED NOT NULL,
    assigned_by_player_id BIGINT UNSIGNED NULL,
    reason VARCHAR(255) NULL,
    assigned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NULL,
    revoked_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_player_roles_player_role (player_id, role_id),
    KEY idx_player_roles_player_id (player_id),
    KEY idx_player_roles_role_id (role_id),
    KEY idx_player_roles_active (player_id, revoked_at, expires_at),
    CONSTRAINT fk_player_roles_player_id FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE,
    CONSTRAINT fk_player_roles_role_id FOREIGN KEY (role_id) REFERENCES permission_roles (id) ON DELETE CASCADE,
    CONSTRAINT fk_player_roles_assigned_by_player_id FOREIGN KEY (assigned_by_player_id) REFERENCES players (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS character_permissions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    permission VARCHAR(128) NOT NULL,
    is_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    granted_by_player_id BIGINT UNSIGNED NULL,
    reason VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NULL,
    revoked_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_character_permissions_character_permission (character_id, permission),
    KEY idx_character_permissions_permission (permission),
    KEY idx_character_permissions_active (character_id, revoked_at, expires_at),
    CONSTRAINT fk_character_permissions_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_character_permissions_granted_by_player_id FOREIGN KEY (granted_by_player_id) REFERENCES players (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS account_members (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    account_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    role ENUM('owner','manager','member','viewer') NOT NULL DEFAULT 'member',
    permissions JSON NULL,
    granted_by_character_id BIGINT UNSIGNED NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NULL,
    revoked_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_account_members_account_character (account_id, character_id),
    KEY idx_account_members_account_id (account_id),
    KEY idx_account_members_character_id (character_id),
    KEY idx_account_members_active (character_id, revoked_at, expires_at),
    CONSTRAINT fk_account_members_account_id FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
    CONSTRAINT fk_account_members_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_account_members_granted_by_character_id FOREIGN KEY (granted_by_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS vehicle_garage_states (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_id BIGINT UNSIGNED NOT NULL,
    state ENUM('stored','out','impounded','seized') NOT NULL DEFAULT 'stored',
    garage_name VARCHAR(64) NULL,
    impound_reason VARCHAR(255) NULL,
    stored_at DATETIME NULL,
    out_at DATETIME NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_vehicle_garage_states_vehicle_id (vehicle_id),
    KEY idx_vehicle_garage_states_state (state),
    KEY idx_vehicle_garage_states_garage_name (garage_name),
    CONSTRAINT fk_vehicle_garage_states_vehicle_id FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS business_accounts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    business_id BIGINT UNSIGNED NOT NULL,
    account_id BIGINT UNSIGNED NOT NULL,
    account_role ENUM('primary','payroll','tax','reserve') NOT NULL DEFAULT 'primary',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_business_accounts_business_role (business_id, account_role),
    UNIQUE KEY uq_business_accounts_account_id (account_id),
    KEY idx_business_accounts_business_id (business_id),
    KEY idx_business_accounts_is_active (is_active),
    CONSTRAINT fk_business_accounts_business_id FOREIGN KEY (business_id) REFERENCES businesses (id) ON DELETE CASCADE,
    CONSTRAINT fk_business_accounts_account_id FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS business_transactions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    transaction_number VARCHAR(32) NOT NULL,
    business_id BIGINT UNSIGNED NOT NULL,
    business_account_id BIGINT UNSIGNED NULL,
    ledger_id BIGINT UNSIGNED NULL,
    actor_character_id BIGINT UNSIGNED NULL,
    transaction_type ENUM('income','expense','transfer','payroll','invoice','adjustment') NOT NULL,
    amount BIGINT NOT NULL,
    label VARCHAR(128) NOT NULL,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_business_transactions_transaction_number (transaction_number),
    KEY idx_business_transactions_business_created (business_id, created_at),
    KEY idx_business_transactions_account_created (business_account_id, created_at),
    KEY idx_business_transactions_type (transaction_type),
    KEY idx_business_transactions_ledger_id (ledger_id),
    CONSTRAINT fk_business_transactions_business_id FOREIGN KEY (business_id) REFERENCES businesses (id) ON DELETE CASCADE,
    CONSTRAINT fk_business_transactions_business_account_id FOREIGN KEY (business_account_id) REFERENCES business_accounts (id) ON DELETE SET NULL,
    CONSTRAINT fk_business_transactions_ledger_id FOREIGN KEY (ledger_id) REFERENCES economy_ledger (id) ON DELETE SET NULL,
    CONSTRAINT fk_business_transactions_actor_character_id FOREIGN KEY (actor_character_id) REFERENCES characters (id) ON DELETE SET NULL,
    CONSTRAINT chk_business_transactions_amount CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS license_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    license_id BIGINT UNSIGNED NOT NULL,
    license_type_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    actor_character_id BIGINT UNSIGNED NULL,
    action ENUM('issued','suspended','revoked','expired','renewed','restored') NOT NULL,
    old_status VARCHAR(32) NULL,
    new_status VARCHAR(32) NOT NULL,
    reason VARCHAR(255) NULL,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_license_history_license_id (license_id),
    KEY idx_license_history_character_created (character_id, created_at),
    KEY idx_license_history_type_created (license_type_id, created_at),
    KEY idx_license_history_action (action),
    CONSTRAINT fk_license_history_license_id FOREIGN KEY (license_id) REFERENCES licenses (id) ON DELETE CASCADE,
    CONSTRAINT fk_license_history_license_type_id FOREIGN KEY (license_type_id) REFERENCES license_types (id) ON DELETE RESTRICT,
    CONSTRAINT fk_license_history_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_license_history_actor_character_id FOREIGN KEY (actor_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS server_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    level ENUM('debug','info','warning','error','critical') NOT NULL DEFAULT 'info',
    resource_name VARCHAR(64) NOT NULL,
    message VARCHAR(255) NOT NULL,
    context JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_server_logs_level (level),
    KEY idx_server_logs_resource_created (resource_name, created_at),
    KEY idx_server_logs_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS error_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    resource_name VARCHAR(64) NOT NULL,
    error_code VARCHAR(64) NULL,
    message VARCHAR(255) NOT NULL,
    stack_trace TEXT NULL,
    context JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_error_logs_resource_created (resource_name, created_at),
    KEY idx_error_logs_error_code (error_code),
    KEY idx_error_logs_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS resource_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    resource_name VARCHAR(64) NOT NULL,
    level ENUM('debug','info','warning','error','critical') NOT NULL DEFAULT 'info',
    action VARCHAR(128) NOT NULL,
    message VARCHAR(255) NOT NULL,
    context JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_resource_logs_resource_created (resource_name, created_at),
    KEY idx_resource_logs_level (level),
    KEY idx_resource_logs_action (action),
    KEY idx_resource_logs_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS performance_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    resource_name VARCHAR(64) NOT NULL,
    metric_name VARCHAR(64) NOT NULL,
    metric_value DECIMAL(12,4) NOT NULL,
    metric_unit VARCHAR(32) NOT NULL,
    sample_count INT UNSIGNED NOT NULL DEFAULT 1,
    context JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_performance_logs_resource_metric (resource_name, metric_name),
    KEY idx_performance_logs_created_at (created_at),
    KEY idx_performance_logs_metric_created (metric_name, created_at),
    CONSTRAINT chk_performance_logs_sample_count CHECK (sample_count > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS stash_registry (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    stash_name VARCHAR(64) NOT NULL,
    label VARCHAR(64) NOT NULL,
    owner_type ENUM('none','character','business','faction','property','evidence','system') NOT NULL DEFAULT 'none',
    owner_id BIGINT UNSIGNED NULL,
    slots INT UNSIGNED NOT NULL,
    max_weight INT UNSIGNED NOT NULL,
    is_temporary BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_stash_registry_stash_name (stash_name),
    KEY idx_stash_registry_owner (owner_type, owner_id),
    KEY idx_stash_registry_is_active (is_active),
    CONSTRAINT chk_stash_registry_slots CHECK (slots > 0),
    CONSTRAINT chk_stash_registry_max_weight CHECK (max_weight > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS shop_registry (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    shop_name VARCHAR(64) NOT NULL,
    label VARCHAR(64) NOT NULL,
    shop_type VARCHAR(32) NOT NULL,
    owner_type ENUM('none','business','faction','system') NOT NULL DEFAULT 'none',
    owner_id BIGINT UNSIGNED NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_shop_registry_shop_name (shop_name),
    KEY idx_shop_registry_type (shop_type),
    KEY idx_shop_registry_owner (owner_type, owner_id),
    KEY idx_shop_registry_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS evidence_stashes (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    evidence_stash_code VARCHAR(32) NOT NULL,
    stash_id BIGINT UNSIGNED NOT NULL,
    incident_report_id BIGINT UNSIGNED NULL,
    faction_id BIGINT UNSIGNED NULL,
    created_by_character_id BIGINT UNSIGNED NULL,
    status ENUM('active','sealed','released','destroyed') NOT NULL DEFAULT 'active',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_evidence_stashes_code (evidence_stash_code),
    UNIQUE KEY uq_evidence_stashes_stash_id (stash_id),
    KEY idx_evidence_stashes_incident_report_id (incident_report_id),
    KEY idx_evidence_stashes_faction_id (faction_id),
    KEY idx_evidence_stashes_status (status),
    CONSTRAINT fk_evidence_stashes_stash_id FOREIGN KEY (stash_id) REFERENCES stash_registry (id) ON DELETE RESTRICT,
    CONSTRAINT fk_evidence_stashes_incident_report_id FOREIGN KEY (incident_report_id) REFERENCES incident_reports (id) ON DELETE SET NULL,
    CONSTRAINT fk_evidence_stashes_faction_id FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE SET NULL,
    CONSTRAINT fk_evidence_stashes_created_by_character_id FOREIGN KEY (created_by_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS property_storage (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    property_unit_id BIGINT UNSIGNED NOT NULL,
    stash_id BIGINT UNSIGNED NOT NULL,
    storage_type ENUM('private','shared','business','evidence') NOT NULL DEFAULT 'private',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_property_storage_unit_stash (property_unit_id, stash_id),
    KEY idx_property_storage_property_unit_id (property_unit_id),
    KEY idx_property_storage_stash_id (stash_id),
    KEY idx_property_storage_is_active (is_active),
    CONSTRAINT fk_property_storage_property_unit_id FOREIGN KEY (property_unit_id) REFERENCES property_units (id) ON DELETE CASCADE,
    CONSTRAINT fk_property_storage_stash_id FOREIGN KEY (stash_id) REFERENCES stash_registry (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS property_transactions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    transaction_number VARCHAR(32) NOT NULL,
    property_id BIGINT UNSIGNED NOT NULL,
    property_unit_id BIGINT UNSIGNED NULL,
    from_character_id BIGINT UNSIGNED NULL,
    to_character_id BIGINT UNSIGNED NULL,
    account_id BIGINT UNSIGNED NULL,
    ledger_id BIGINT UNSIGNED NULL,
    transaction_type ENUM('purchase','sale','rent','deposit','refund','fee') NOT NULL,
    amount BIGINT NOT NULL,
    status ENUM('created','completed','cancelled','failed') NOT NULL DEFAULT 'created',
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_property_transactions_transaction_number (transaction_number),
    KEY idx_property_transactions_property_created (property_id, created_at),
    KEY idx_property_transactions_unit_created (property_unit_id, created_at),
    KEY idx_property_transactions_to_character_id (to_character_id),
    KEY idx_property_transactions_status (status),
    CONSTRAINT fk_property_transactions_property_id FOREIGN KEY (property_id) REFERENCES properties (id) ON DELETE CASCADE,
    CONSTRAINT fk_property_transactions_property_unit_id FOREIGN KEY (property_unit_id) REFERENCES property_units (id) ON DELETE SET NULL,
    CONSTRAINT fk_property_transactions_from_character_id FOREIGN KEY (from_character_id) REFERENCES characters (id) ON DELETE SET NULL,
    CONSTRAINT fk_property_transactions_to_character_id FOREIGN KEY (to_character_id) REFERENCES characters (id) ON DELETE SET NULL,
    CONSTRAINT fk_property_transactions_account_id FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL,
    CONSTRAINT fk_property_transactions_ledger_id FOREIGN KEY (ledger_id) REFERENCES economy_ledger (id) ON DELETE SET NULL,
    CONSTRAINT chk_property_transactions_amount CHECK (amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS faction_permissions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    faction_grade_id BIGINT UNSIGNED NOT NULL,
    permission VARCHAR(128) NOT NULL,
    is_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_faction_permissions_grade_permission (faction_grade_id, permission),
    KEY idx_faction_permissions_permission (permission),
    CONSTRAINT fk_faction_permissions_grade_id FOREIGN KEY (faction_grade_id) REFERENCES faction_grades (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS faction_armory_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    faction_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NULL,
    item_ledger_id BIGINT UNSIGNED NULL,
    action ENUM('withdraw','deposit','seize','return','destroy') NOT NULL,
    item_name VARCHAR(64) NOT NULL,
    amount INT NOT NULL,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_faction_armory_logs_faction_created (faction_id, created_at),
    KEY idx_faction_armory_logs_character_id (character_id),
    KEY idx_faction_armory_logs_item_name (item_name),
    KEY idx_faction_armory_logs_item_ledger_id (item_ledger_id),
    CONSTRAINT fk_faction_armory_logs_faction_id FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE CASCADE,
    CONSTRAINT fk_faction_armory_logs_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE SET NULL,
    CONSTRAINT fk_faction_armory_logs_item_ledger_id FOREIGN KEY (item_ledger_id) REFERENCES item_ledger (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS faction_vehicle_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    faction_id BIGINT UNSIGNED NOT NULL,
    vehicle_id BIGINT UNSIGNED NULL,
    character_id BIGINT UNSIGNED NULL,
    action ENUM('checkout','return','impound','repair','assign','unassign') NOT NULL,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_faction_vehicle_logs_faction_created (faction_id, created_at),
    KEY idx_faction_vehicle_logs_vehicle_id (vehicle_id),
    KEY idx_faction_vehicle_logs_character_id (character_id),
    KEY idx_faction_vehicle_logs_action (action),
    CONSTRAINT fk_faction_vehicle_logs_faction_id FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE CASCADE,
    CONSTRAINT fk_faction_vehicle_logs_vehicle_id FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL,
    CONSTRAINT fk_faction_vehicle_logs_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS radio_channels (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    frequency DECIMAL(6,2) NOT NULL,
    name VARCHAR(64) NOT NULL,
    label VARCHAR(64) NOT NULL,
    channel_type ENUM('public','job','faction','emergency','system') NOT NULL DEFAULT 'public',
    faction_id BIGINT UNSIGNED NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_radio_channels_frequency (frequency),
    UNIQUE KEY uq_radio_channels_name (name),
    KEY idx_radio_channels_type (channel_type),
    KEY idx_radio_channels_faction_id (faction_id),
    KEY idx_radio_channels_is_active (is_active),
    CONSTRAINT fk_radio_channels_faction_id FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS radio_access (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    radio_channel_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NULL,
    faction_id BIGINT UNSIGNED NULL,
    job_id BIGINT UNSIGNED NULL,
    min_grade_level INT UNSIGNED NULL,
    access_type ENUM('listen','speak','manage') NOT NULL DEFAULT 'listen',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NULL,
    PRIMARY KEY (id),
    KEY idx_radio_access_channel_id (radio_channel_id),
    KEY idx_radio_access_character_id (character_id),
    KEY idx_radio_access_faction_id (faction_id),
    KEY idx_radio_access_job_id (job_id),
    CONSTRAINT fk_radio_access_channel_id FOREIGN KEY (radio_channel_id) REFERENCES radio_channels (id) ON DELETE CASCADE,
    CONSTRAINT fk_radio_access_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_radio_access_faction_id FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE CASCADE,
    CONSTRAINT fk_radio_access_job_id FOREIGN KEY (job_id) REFERENCES jobs (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS phone_calls (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    caller_number VARCHAR(32) NOT NULL,
    receiver_number VARCHAR(32) NOT NULL,
    status ENUM('started','answered','missed','declined','ended') NOT NULL DEFAULT 'started',
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    answered_at DATETIME NULL,
    ended_at DATETIME NULL,
    duration_seconds INT UNSIGNED NULL,
    metadata JSON NULL,
    PRIMARY KEY (id),
    KEY idx_phone_calls_caller_started (caller_number, started_at),
    KEY idx_phone_calls_receiver_started (receiver_number, started_at),
    KEY idx_phone_calls_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS phone_mail (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_character_id BIGINT UNSIGNED NOT NULL,
    sender VARCHAR(128) NOT NULL,
    subject VARCHAR(128) NOT NULL,
    body TEXT NOT NULL,
    status ENUM('unread','read','archived','deleted') NOT NULL DEFAULT 'unread',
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,
    PRIMARY KEY (id),
    KEY idx_phone_mail_owner_status (owner_character_id, status),
    KEY idx_phone_mail_created_at (created_at),
    CONSTRAINT fk_phone_mail_owner_character_id FOREIGN KEY (owner_character_id) REFERENCES characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS phone_notes (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(128) NOT NULL,
    content TEXT NULL,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,
    PRIMARY KEY (id),
    KEY idx_phone_notes_character_updated (character_id, updated_at),
    KEY idx_phone_notes_is_pinned (is_pinned),
    CONSTRAINT fk_phone_notes_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS phone_gallery (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    media_ref VARCHAR(255) NOT NULL,
    media_type ENUM('image','video') NOT NULL DEFAULT 'image',
    caption VARCHAR(255) NULL,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,
    PRIMARY KEY (id),
    KEY idx_phone_gallery_character_created (character_id, created_at),
    KEY idx_phone_gallery_media_type (media_type),
    CONSTRAINT fk_phone_gallery_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS phone_apps (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    app_name VARCHAR(64) NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    settings JSON NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_phone_apps_character_app (character_id, app_name),
    KEY idx_phone_apps_app_name (app_name),
    KEY idx_phone_apps_is_enabled (is_enabled),
    CONSTRAINT fk_phone_apps_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS document_signatures (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    document_id BIGINT UNSIGNED NOT NULL,
    signer_character_id BIGINT UNSIGNED NOT NULL,
    signature_hash VARCHAR(128) NOT NULL,
    signed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metadata JSON NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_document_signatures_document_signer (document_id, signer_character_id),
    KEY idx_document_signatures_signer (signer_character_id),
    KEY idx_document_signatures_signed_at (signed_at),
    CONSTRAINT fk_document_signatures_document_id FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,
    CONSTRAINT fk_document_signatures_signer_character_id FOREIGN KEY (signer_character_id) REFERENCES characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name, checksum, executed_by, duration_ms)
VALUES ('20260705_1300', 'complete_core_database_tables', 'managed-by-phase-3-1-validation', 'phase_3_1_migration', 0)
ON DUPLICATE KEY UPDATE name = VALUES(name);

SET FOREIGN_KEY_CHECKS = 1;
