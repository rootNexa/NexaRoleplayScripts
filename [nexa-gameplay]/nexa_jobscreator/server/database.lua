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

function NexaJobsCreatorDatabase.InsertOrganization(payload)
    return MySQL.insert.await([[
        INSERT INTO organizations (name, label, organization_type, mdt_type, enabled)
        VALUES (?, ?, ?, ?, ?)
    ]], {
        payload.name,
        payload.label,
        payload.organization_type,
        payload.mdt_type,
        payload.enabled and 1 or 0
    })
end

function NexaJobsCreatorDatabase.GetOrganization(id)
    return MySQL.single.await([[
        SELECT id, name, label, organization_type, mdt_type, enabled, created_at, updated_at
        FROM organizations
        WHERE id = ?
        LIMIT 1
    ]], {
        id
    })
end

function NexaJobsCreatorDatabase.FindOrganizationByName(name)
    return MySQL.single.await([[
        SELECT id, name, label, organization_type, mdt_type, enabled, created_at, updated_at
        FROM organizations
        WHERE name = ?
        LIMIT 1
    ]], {
        name
    })
end

function NexaJobsCreatorDatabase.ListOrganizations(filter)
    filter = filter or {}

    local query = [[
        SELECT id, name, label, organization_type, mdt_type, enabled, created_at, updated_at
        FROM organizations
        WHERE 1 = 1
    ]]
    local params = {}

    if filter.organization_type then
        query = query .. ' AND organization_type = ?'
        params[#params + 1] = filter.organization_type
    end

    if filter.mdt_type then
        query = query .. ' AND mdt_type = ?'
        params[#params + 1] = filter.mdt_type
    end

    if filter.enabled ~= nil then
        query = query .. ' AND enabled = ?'
        params[#params + 1] = filter.enabled and 1 or 0
    end

    query = query .. ' ORDER BY label ASC, id ASC'

    return MySQL.query.await(query, params)
end

function NexaJobsCreatorDatabase.SetOrganizationEnabled(id, enabled)
    return MySQL.update.await([[
        UPDATE organizations
        SET enabled = ?
        WHERE id = ?
    ]], {
        enabled and 1 or 0,
        id
    })
end

function NexaJobsCreatorDatabase.InsertGrade(payload)
    return MySQL.insert.await([[
        INSERT INTO organization_grades (organization_id, name, label, level, permissions)
        VALUES (?, ?, ?, ?, ?)
    ]], {
        payload.organization_id,
        payload.name,
        payload.label,
        payload.level,
        payload.permissions
    })
end

function NexaJobsCreatorDatabase.GetGrade(id)
    return MySQL.single.await([[
        SELECT id, organization_id, name, label, level, permissions
        FROM organization_grades
        WHERE id = ?
        LIMIT 1
    ]], {
        id
    })
end

function NexaJobsCreatorDatabase.ListGrades(organizationId)
    return MySQL.query.await([[
        SELECT id, organization_id, name, label, level, permissions
        FROM organization_grades
        WHERE organization_id = ?
        ORDER BY level DESC, label ASC, id ASC
    ]], {
        organizationId
    })
end

function NexaJobsCreatorDatabase.UpdateGrade(id, updates)
    local assignments = {}
    local params = {}

    for _, field in ipairs({ 'name', 'label', 'level', 'permissions' }) do
        if updates[field] ~= nil then
            assignments[#assignments + 1] = field .. ' = ?'
            params[#params + 1] = updates[field]
        end
    end

    if #assignments == 0 then
        return 0
    end

    params[#params + 1] = id

    return MySQL.update.await(('UPDATE organization_grades SET %s WHERE id = ?'):format(table.concat(assignments, ', ')), params)
end

function NexaJobsCreatorDatabase.DeleteGrade(id)
    return MySQL.update.await('DELETE FROM organization_grades WHERE id = ?', {
        id
    })
end

function NexaJobsCreatorDatabase.InsertMember(payload)
    return MySQL.insert.await([[
        INSERT INTO organization_members (organization_id, character_id, grade_id, callsign, is_on_duty)
        VALUES (?, ?, ?, ?, ?)
    ]], {
        payload.organization_id,
        payload.character_id,
        payload.grade_id,
        payload.callsign,
        payload.is_on_duty and 1 or 0
    })
end

function NexaJobsCreatorDatabase.GetMember(id)
    return MySQL.single.await([[
        SELECT id, organization_id, character_id, grade_id, callsign, is_on_duty, joined_at
        FROM organization_members
        WHERE id = ?
        LIMIT 1
    ]], {
        id
    })
end

function NexaJobsCreatorDatabase.ListMembers(organizationId)
    return MySQL.query.await([[
        SELECT
            m.id,
            m.organization_id,
            m.character_id,
            m.grade_id,
            m.callsign,
            m.is_on_duty,
            m.joined_at,
            g.name AS grade_name,
            g.label AS grade_label,
            g.level AS grade_level
        FROM organization_members m
        LEFT JOIN organization_grades g ON g.id = m.grade_id
        WHERE m.organization_id = ?
        ORDER BY g.level DESC, m.callsign ASC, m.id ASC
    ]], {
        organizationId
    })
end

function NexaJobsCreatorDatabase.UpdateMember(id, updates)
    local assignments = {}
    local params = {}

    if updates.grade_id_set then
        assignments[#assignments + 1] = 'grade_id = ?'
        params[#params + 1] = updates.grade_id
    end

    if updates.callsign_set then
        assignments[#assignments + 1] = 'callsign = ?'
        params[#params + 1] = updates.callsign
    end

    if updates.is_on_duty_set then
        assignments[#assignments + 1] = 'is_on_duty = ?'
        params[#params + 1] = updates.is_on_duty and 1 or 0
    end

    if #assignments == 0 then
        return 0
    end

    params[#params + 1] = id

    return MySQL.update.await(('UPDATE organization_members SET %s WHERE id = ?'):format(table.concat(assignments, ', ')), params)
end

function NexaJobsCreatorDatabase.RemoveMember(id)
    return MySQL.update.await('DELETE FROM organization_members WHERE id = ?', {
        id
    })
end

function NexaJobsCreatorDatabase.SetDuty(memberId, isOnDuty)
    return MySQL.update.await([[
        UPDATE organization_members
        SET is_on_duty = ?
        WHERE id = ?
    ]], {
        isOnDuty and 1 or 0,
        memberId
    })
end
