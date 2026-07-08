CREATE TABLE IF NOT EXISTS nexa_permission_roles (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(48) NOT NULL,
    label VARCHAR(96) NOT NULL,
    priority INT NOT NULL DEFAULT 0,
    inherits VARCHAR(48) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_nexa_permission_roles_name (name),
    KEY idx_nexa_permission_roles_priority (priority),
    KEY idx_nexa_permission_roles_inherits (inherits)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS nexa_permission_role_rules (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    role_id BIGINT UNSIGNED NOT NULL,
    permission VARCHAR(96) NOT NULL,
    allowed TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_nexa_permission_role_rules_role_permission (role_id, permission),
    KEY idx_nexa_permission_role_rules_permission (permission),
    CONSTRAINT fk_nexa_permission_role_rules_role
        FOREIGN KEY (role_id) REFERENCES nexa_permission_roles (id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS nexa_permission_assignments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_id BIGINT UNSIGNED NULL,
    character_id BIGINT UNSIGNED NULL,
    identifier VARCHAR(128) NULL,
    role_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_nexa_permission_assignments_player_role (player_id, role_id),
    UNIQUE KEY uq_nexa_permission_assignments_character_role (character_id, role_id),
    UNIQUE KEY uq_nexa_permission_assignments_identifier_role (identifier, role_id),
    KEY idx_nexa_permission_assignments_identifier (identifier),
    KEY idx_nexa_permission_assignments_role_id (role_id),
    CONSTRAINT fk_nexa_permission_assignments_player
        FOREIGN KEY (player_id) REFERENCES nexa_players (id)
        ON DELETE CASCADE,
    CONSTRAINT fk_nexa_permission_assignments_character
        FOREIGN KEY (character_id) REFERENCES nexa_characters (id)
        ON DELETE CASCADE,
    CONSTRAINT fk_nexa_permission_assignments_role
        FOREIGN KEY (role_id) REFERENCES nexa_permission_roles (id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
