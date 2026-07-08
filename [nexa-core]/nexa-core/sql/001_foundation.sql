CREATE TABLE IF NOT EXISTS nexa_players (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    identifier VARCHAR(128) NOT NULL,
    identifier_type VARCHAR(32) NOT NULL,
    display_name VARCHAR(64) NOT NULL,
    last_seen_at TIMESTAMP NULL DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_nexa_players_identifier (identifier),
    KEY idx_nexa_players_identifier_type (identifier_type),
    KEY idx_nexa_players_last_seen_at (last_seen_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS nexa_characters (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_id BIGINT UNSIGNED NOT NULL,
    first_name VARCHAR(32) NOT NULL,
    last_name VARCHAR(32) NOT NULL,
    birthdate DATE NOT NULL,
    gender ENUM('male', 'female', 'diverse', 'unknown') NOT NULL DEFAULT 'unknown',
    metadata JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_nexa_characters_player_id (player_id),
    KEY idx_nexa_characters_name (last_name, first_name),
    KEY idx_nexa_characters_deleted_at (deleted_at),
    CONSTRAINT fk_nexa_characters_player
        FOREIGN KEY (player_id) REFERENCES nexa_players (id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS nexa_permissions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_id BIGINT UNSIGNED NOT NULL,
    permission VARCHAR(96) NOT NULL,
    value TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_nexa_permissions_player_permission (player_id, permission),
    KEY idx_nexa_permissions_permission (permission),
    CONSTRAINT fk_nexa_permissions_player
        FOREIGN KEY (player_id) REFERENCES nexa_players (id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS nexa_audit_log (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    action VARCHAR(96) NOT NULL,
    actor_source INT NULL,
    player_id BIGINT UNSIGNED NULL,
    character_id BIGINT UNSIGNED NULL,
    resource VARCHAR(64) NOT NULL,
    context JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_nexa_audit_log_action (action),
    KEY idx_nexa_audit_log_player_id (player_id),
    KEY idx_nexa_audit_log_character_id (character_id),
    KEY idx_nexa_audit_log_created_at (created_at),
    CONSTRAINT fk_nexa_audit_log_player
        FOREIGN KEY (player_id) REFERENCES nexa_players (id)
        ON DELETE SET NULL,
    CONSTRAINT fk_nexa_audit_log_character
        FOREIGN KEY (character_id) REFERENCES nexa_characters (id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
