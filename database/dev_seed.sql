-- Development-only seed data.
-- Phase 3 intentionally avoids gameplay test data.

INSERT INTO feature_flags (flag_name, environment, is_enabled, metadata)
VALUES
    ('dev.database.validation_verbose', 'dev', TRUE, JSON_OBJECT('source', 'phase3_dev_seed')),
    ('phase8a.factions_core', 'dev', TRUE, JSON_OBJECT('source', 'phase8a_dev_seed')),
    ('phase8b.lspd', 'dev', TRUE, JSON_OBJECT('source', 'phase8b_dev_seed')),
    ('phase8c.ems', 'dev', TRUE, JSON_OBJECT('source', 'phase8c_dev_seed', 'resource', 'nexa_ems')),
    ('phase8d.government', 'dev', TRUE, JSON_OBJECT('source', 'phase8d_dev_seed', 'resource', 'nexa_government')),
    ('phase8e.weazel', 'dev', TRUE, JSON_OBJECT('source', 'phase8e_dev_seed', 'resource', 'nexa_weazel')),
    ('phase9a.illegal_core', 'dev', TRUE, JSON_OBJECT('source', 'phase9a_dev_seed', 'resource', 'nexa_illegal_core')),
    ('phase9b.blackmarket', 'dev', TRUE, JSON_OBJECT('source', 'phase9b_dev_seed', 'resource', 'nexa_blackmarket')),
    ('phase9c.drugs', 'dev', TRUE, JSON_OBJECT('source', 'phase9c_dev_seed', 'resource', 'nexa_drugs')),
    ('phase9d.moneywash', 'dev', TRUE, JSON_OBJECT('source', 'phase9d_dev_seed', 'resource', 'nexa_moneywash')),
    ('phase9e.chopshop', 'dev', TRUE, JSON_OBJECT('source', 'phase9e_dev_seed', 'resource', 'nexa_chopshop')),
    ('phase9f.evidence', 'dev', TRUE, JSON_OBJECT('source', 'phase9f_dev_seed', 'resource', 'nexa_evidence')),
    ('phase10a.world_core', 'dev', TRUE, JSON_OBJECT('source', 'phase10a_dev_seed', 'resource', 'nexa_worldstates')),
    ('phase10b.blips', 'dev', TRUE, JSON_OBJECT('source', 'phase10b_dev_seed', 'resource', 'nexa_blips')),
    ('phase10c.zones', 'dev', TRUE, JSON_OBJECT('source', 'phase10c_dev_seed', 'resource', 'nexa_zones')),
    ('phase10d.interiors', 'dev', TRUE, JSON_OBJECT('source', 'phase10d_dev_seed', 'resource', 'nexa_interiors')),
    ('phase10e.maps', 'dev', TRUE, JSON_OBJECT('source', 'phase10e_dev_seed', 'resource', 'nexa_maps')),
    ('phase10f.npcs', 'dev', TRUE, JSON_OBJECT('source', 'phase10f_dev_seed', 'resource', 'nexa_npcs')),
    ('phase11a.admin_core', 'dev', TRUE, JSON_OBJECT('source', 'phase11a_dev_seed', 'resource', 'nexa_admin')),
    ('phase11b.reports', 'dev', TRUE, JSON_OBJECT('source', 'phase11b_dev_seed', 'resource', 'nexa_admin')),
    ('phase11c.tickets', 'dev', TRUE, JSON_OBJECT('source', 'phase11c_dev_seed', 'resource', 'nexa_admin')),
    ('phase11d.moderation_actions', 'dev', TRUE, JSON_OBJECT('source', 'phase11d_dev_seed', 'resource', 'nexa_admin')),
    ('phase11e.admin_utility', 'dev', TRUE, JSON_OBJECT('source', 'phase11e_dev_seed', 'resource', 'nexa_admin'))
ON DUPLICATE KEY UPDATE
    is_enabled = VALUES(is_enabled),
    metadata = VALUES(metadata);
