NexaJobsCreatorDatabase = {}

local createOrganizationsTable = [[
CREATE TABLE IF NOT EXISTS organizations (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(64) NOT NULL,
    label VARCHAR(96) NOT NULL,
    organization_type VARCHAR(32) NOT NULL,
    mdt_type VARCHAR(32) NOT NULL,
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_organizations_name (name),
    KEY idx_organizations_type (organization_type),
    KEY idx_organizations_mdt_type (mdt_type),
    KEY idx_organizations_enabled (enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

local createGradesTable = [[
CREATE TABLE IF NOT EXISTS organization_grades (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    organization_id INT UNSIGNED NOT NULL,
    name VARCHAR(64) NOT NULL,
    label VARCHAR(96) NOT NULL,
    level INT NOT NULL DEFAULT 0,
    permissions JSON NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_organization_grades_name (organization_id, name),
    KEY idx_organization_grades_level (organization_id, level),
    CONSTRAINT fk_organization_grades_organization
        FOREIGN KEY (organization_id) REFERENCES organizations (id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

local createMembersTable = [[
CREATE TABLE IF NOT EXISTS organization_members (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    organization_id INT UNSIGNED NOT NULL,
    character_id INT UNSIGNED NOT NULL,
    grade_id INT UNSIGNED NULL,
    callsign VARCHAR(32) NULL,
    is_on_duty TINYINT(1) NOT NULL DEFAULT 0,
    joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_organization_members_character (organization_id, character_id),
    KEY idx_organization_members_character (character_id),
    KEY idx_organization_members_duty (organization_id, is_on_duty),
    CONSTRAINT fk_organization_members_organization
        FOREIGN KEY (organization_id) REFERENCES organizations (id)
        ON DELETE CASCADE,
    CONSTRAINT fk_organization_members_grade
        FOREIGN KEY (grade_id) REFERENCES organization_grades (id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

local migrations = {
    createOrganizationsTable,
    createGradesTable,
    createMembersTable
}

function NexaJobsCreatorDatabase.Migrate()
    for _, query in ipairs(migrations) do
        local ok, result = pcall(MySQL.query.await, query)

        if not ok then
            return false, result
        end
    end

    return true, nil
end

function NexaJobsCreatorDatabase.GetSchema()
    return {
        organizations = {
            'id',
            'name',
            'label',
            'organization_type',
            'mdt_type',
            'enabled',
            'created_at',
            'updated_at'
        },
        organization_grades = {
            'id',
            'organization_id',
            'name',
            'label',
            'level',
            'permissions'
        },
        organization_members = {
            'id',
            'organization_id',
            'character_id',
            'grade_id',
            'callsign',
            'is_on_duty',
            'joined_at'
        }
    }
end
