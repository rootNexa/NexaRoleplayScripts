-- Nexa Roleplay Phase 3 seed data
-- Only non-gameplay operational defaults are seeded in this phase.

INSERT INTO feature_flags (flag_name, environment, is_enabled, metadata)
VALUES
    ('phase3.database.persistence', 'dev', TRUE, JSON_OBJECT('source', 'phase3_seed')),
    ('phase3.database.persistence', 'staging', FALSE, JSON_OBJECT('source', 'phase3_seed')),
    ('phase3.database.persistence', 'prod', FALSE, JSON_OBJECT('source', 'phase3_seed')),
    ('phase3_1.database.completion', 'dev', TRUE, JSON_OBJECT('source', 'phase3_1_seed')),
    ('phase3_1.database.completion', 'staging', FALSE, JSON_OBJECT('source', 'phase3_1_seed')),
    ('phase3_1.database.completion', 'prod', FALSE, JSON_OBJECT('source', 'phase3_1_seed')),
    ('phase4b.documents_licenses', 'dev', TRUE, JSON_OBJECT('source', 'phase4b_seed')),
    ('phase4b.documents_licenses', 'staging', FALSE, JSON_OBJECT('source', 'phase4b_seed')),
    ('phase4b.documents_licenses', 'prod', FALSE, JSON_OBJECT('source', 'phase4b_seed')),
    ('phase4c.banking', 'dev', TRUE, JSON_OBJECT('source', 'phase4c_seed')),
    ('phase4c.banking', 'staging', FALSE, JSON_OBJECT('source', 'phase4c_seed')),
    ('phase4c.banking', 'prod', FALSE, JSON_OBJECT('source', 'phase4c_seed')),
    ('phase4d.jobs_businesses', 'dev', TRUE, JSON_OBJECT('source', 'phase4d_seed')),
    ('phase4d.jobs_businesses', 'staging', FALSE, JSON_OBJECT('source', 'phase4d_seed')),
    ('phase4d.jobs_businesses', 'prod', FALSE, JSON_OBJECT('source', 'phase4d_seed')),
    ('phase4e.dispatch', 'dev', TRUE, JSON_OBJECT('source', 'phase4e_seed')),
    ('phase4e.dispatch', 'staging', FALSE, JSON_OBJECT('source', 'phase4e_seed')),
    ('phase4e.dispatch', 'prod', FALSE, JSON_OBJECT('source', 'phase4e_seed')),
    ('phase6c.vehicledealer', 'dev', TRUE, JSON_OBJECT('source', 'phase6c_seed')),
    ('phase6c.vehicledealer', 'staging', FALSE, JSON_OBJECT('source', 'phase6c_seed')),
    ('phase6c.vehicledealer', 'prod', FALSE, JSON_OBJECT('source', 'phase6c_seed')),
    ('phase6d.fuel', 'dev', TRUE, JSON_OBJECT('source', 'phase6d_seed')),
    ('phase6d.fuel', 'staging', FALSE, JSON_OBJECT('source', 'phase6d_seed')),
    ('phase6d.fuel', 'prod', FALSE, JSON_OBJECT('source', 'phase6d_seed')),
    ('phase6e.impound', 'dev', TRUE, JSON_OBJECT('source', 'phase6e_seed')),
    ('phase6e.impound', 'staging', FALSE, JSON_OBJECT('source', 'phase6e_seed')),
    ('phase6e.impound', 'prod', FALSE, JSON_OBJECT('source', 'phase6e_seed')),
    ('phase7a.housing_core', 'dev', TRUE, JSON_OBJECT('source', 'phase7a_seed')),
    ('phase7a.housing_core', 'staging', FALSE, JSON_OBJECT('source', 'phase7a_seed')),
    ('phase7a.housing_core', 'prod', FALSE, JSON_OBJECT('source', 'phase7a_seed')),
    ('phase7b.property_access', 'dev', TRUE, JSON_OBJECT('source', 'phase7b_seed')),
    ('phase7b.property_access', 'staging', FALSE, JSON_OBJECT('source', 'phase7b_seed')),
    ('phase7b.property_access', 'prod', FALSE, JSON_OBJECT('source', 'phase7b_seed')),
    ('phase7c.housing_storage', 'dev', TRUE, JSON_OBJECT('source', 'phase7c_seed')),
    ('phase7c.housing_storage', 'staging', FALSE, JSON_OBJECT('source', 'phase7c_seed')),
    ('phase7c.housing_storage', 'prod', FALSE, JSON_OBJECT('source', 'phase7c_seed')),
    ('phase7d.furniture', 'dev', TRUE, JSON_OBJECT('source', 'phase7d_seed')),
    ('phase7d.furniture', 'staging', FALSE, JSON_OBJECT('source', 'phase7d_seed')),
    ('phase7d.furniture', 'prod', FALSE, JSON_OBJECT('source', 'phase7d_seed')),
    ('architecture.official_factions_lspd_ems_government_weazel', 'dev', TRUE, JSON_OBJECT('source', 'adr004')),
    ('architecture.official_factions_lspd_ems_government_weazel', 'staging', TRUE, JSON_OBJECT('source', 'adr004')),
    ('architecture.official_factions_lspd_ems_government_weazel', 'prod', TRUE, JSON_OBJECT('source', 'adr004')),
    ('architecture.realistic_crime_only', 'dev', TRUE, JSON_OBJECT('source', 'adr004')),
    ('architecture.realistic_crime_only', 'staging', TRUE, JSON_OBJECT('source', 'adr004')),
    ('architecture.realistic_crime_only', 'prod', TRUE, JSON_OBJECT('source', 'adr004')),
    ('architecture.no_player_blips', 'dev', TRUE, JSON_OBJECT('source', 'adr004')),
    ('architecture.no_player_blips', 'staging', TRUE, JSON_OBJECT('source', 'adr004')),
    ('architecture.no_player_blips', 'prod', TRUE, JSON_OBJECT('source', 'adr004')),
    ('architecture.anticheat_server_authoritative', 'dev', TRUE, JSON_OBJECT('source', 'adr004')),
    ('architecture.anticheat_server_authoritative', 'staging', TRUE, JSON_OBJECT('source', 'adr004')),
    ('architecture.anticheat_server_authoritative', 'prod', TRUE, JSON_OBJECT('source', 'adr004'))
ON DUPLICATE KEY UPDATE
    is_enabled = VALUES(is_enabled),
    metadata = VALUES(metadata);

INSERT INTO feature_flags (flag_name, environment, is_enabled, metadata)
VALUES
    ('phase8a.factions_core', 'dev', TRUE, JSON_OBJECT('source', 'phase8a_seed')),
    ('phase8a.factions_core', 'staging', FALSE, JSON_OBJECT('source', 'phase8a_seed')),
    ('phase8a.factions_core', 'prod', FALSE, JSON_OBJECT('source', 'phase8a_seed')),
    ('phase8b.lspd', 'dev', TRUE, JSON_OBJECT('source', 'phase8b_seed')),
    ('phase8b.lspd', 'staging', FALSE, JSON_OBJECT('source', 'phase8b_seed')),
    ('phase8b.lspd', 'prod', FALSE, JSON_OBJECT('source', 'phase8b_seed')),
    ('phase8c.ems', 'dev', TRUE, JSON_OBJECT('source', 'phase8c_seed', 'resource', 'nexa_ems')),
    ('phase8c.ems', 'staging', FALSE, JSON_OBJECT('source', 'phase8c_seed', 'resource', 'nexa_ems')),
    ('phase8c.ems', 'prod', FALSE, JSON_OBJECT('source', 'phase8c_seed', 'resource', 'nexa_ems')),
    ('phase8d.government', 'dev', TRUE, JSON_OBJECT('source', 'phase8d_seed', 'resource', 'nexa_government')),
    ('phase8d.government', 'staging', FALSE, JSON_OBJECT('source', 'phase8d_seed', 'resource', 'nexa_government')),
    ('phase8d.government', 'prod', FALSE, JSON_OBJECT('source', 'phase8d_seed', 'resource', 'nexa_government')),
    ('phase8e.weazel', 'dev', TRUE, JSON_OBJECT('source', 'phase8e_seed', 'resource', 'nexa_weazel')),
    ('phase8e.weazel', 'staging', FALSE, JSON_OBJECT('source', 'phase8e_seed', 'resource', 'nexa_weazel')),
    ('phase8e.weazel', 'prod', FALSE, JSON_OBJECT('source', 'phase8e_seed', 'resource', 'nexa_weazel')),
    ('phase9a.illegal_core', 'dev', TRUE, JSON_OBJECT('source', 'phase9a_seed', 'resource', 'nexa_illegal_core')),
    ('phase9a.illegal_core', 'staging', FALSE, JSON_OBJECT('source', 'phase9a_seed', 'resource', 'nexa_illegal_core')),
    ('phase9a.illegal_core', 'prod', FALSE, JSON_OBJECT('source', 'phase9a_seed', 'resource', 'nexa_illegal_core')),
    ('phase9b.blackmarket', 'dev', TRUE, JSON_OBJECT('source', 'phase9b_seed', 'resource', 'nexa_blackmarket')),
    ('phase9b.blackmarket', 'staging', FALSE, JSON_OBJECT('source', 'phase9b_seed', 'resource', 'nexa_blackmarket')),
    ('phase9b.blackmarket', 'prod', FALSE, JSON_OBJECT('source', 'phase9b_seed', 'resource', 'nexa_blackmarket')),
    ('phase9c.drugs', 'dev', TRUE, JSON_OBJECT('source', 'phase9c_seed', 'resource', 'nexa_drugs')),
    ('phase9c.drugs', 'staging', FALSE, JSON_OBJECT('source', 'phase9c_seed', 'resource', 'nexa_drugs')),
    ('phase9c.drugs', 'prod', FALSE, JSON_OBJECT('source', 'phase9c_seed', 'resource', 'nexa_drugs')),
    ('phase9d.moneywash', 'dev', TRUE, JSON_OBJECT('source', 'phase9d_seed', 'resource', 'nexa_moneywash')),
    ('phase9d.moneywash', 'staging', FALSE, JSON_OBJECT('source', 'phase9d_seed', 'resource', 'nexa_moneywash')),
    ('phase9d.moneywash', 'prod', FALSE, JSON_OBJECT('source', 'phase9d_seed', 'resource', 'nexa_moneywash')),
    ('phase9e.chopshop', 'dev', TRUE, JSON_OBJECT('source', 'phase9e_seed', 'resource', 'nexa_chopshop')),
    ('phase9e.chopshop', 'staging', FALSE, JSON_OBJECT('source', 'phase9e_seed', 'resource', 'nexa_chopshop')),
    ('phase9e.chopshop', 'prod', FALSE, JSON_OBJECT('source', 'phase9e_seed', 'resource', 'nexa_chopshop')),
    ('phase9f.evidence', 'dev', TRUE, JSON_OBJECT('source', 'phase9f_seed', 'resource', 'nexa_evidence')),
    ('phase9f.evidence', 'staging', FALSE, JSON_OBJECT('source', 'phase9f_seed', 'resource', 'nexa_evidence')),
    ('phase9f.evidence', 'prod', FALSE, JSON_OBJECT('source', 'phase9f_seed', 'resource', 'nexa_evidence')),
    ('phase10a.world_core', 'dev', TRUE, JSON_OBJECT('source', 'phase10a_seed', 'resource', 'nexa_worldstates')),
    ('phase10a.world_core', 'staging', FALSE, JSON_OBJECT('source', 'phase10a_seed', 'resource', 'nexa_worldstates')),
    ('phase10a.world_core', 'prod', FALSE, JSON_OBJECT('source', 'phase10a_seed', 'resource', 'nexa_worldstates')),
    ('phase10b.blips', 'dev', TRUE, JSON_OBJECT('source', 'phase10b_seed', 'resource', 'nexa_blips')),
    ('phase10b.blips', 'staging', FALSE, JSON_OBJECT('source', 'phase10b_seed', 'resource', 'nexa_blips')),
    ('phase10b.blips', 'prod', FALSE, JSON_OBJECT('source', 'phase10b_seed', 'resource', 'nexa_blips')),
    ('phase10c.zones', 'dev', TRUE, JSON_OBJECT('source', 'phase10c_seed', 'resource', 'nexa_zones')),
    ('phase10c.zones', 'staging', FALSE, JSON_OBJECT('source', 'phase10c_seed', 'resource', 'nexa_zones')),
    ('phase10c.zones', 'prod', FALSE, JSON_OBJECT('source', 'phase10c_seed', 'resource', 'nexa_zones')),
    ('phase10d.interiors', 'dev', TRUE, JSON_OBJECT('source', 'phase10d_seed', 'resource', 'nexa_interiors')),
    ('phase10d.interiors', 'staging', FALSE, JSON_OBJECT('source', 'phase10d_seed', 'resource', 'nexa_interiors')),
    ('phase10d.interiors', 'prod', FALSE, JSON_OBJECT('source', 'phase10d_seed', 'resource', 'nexa_interiors')),
    ('phase10e.maps', 'dev', TRUE, JSON_OBJECT('source', 'phase10e_seed', 'resource', 'nexa_maps')),
    ('phase10e.maps', 'staging', FALSE, JSON_OBJECT('source', 'phase10e_seed', 'resource', 'nexa_maps')),
    ('phase10e.maps', 'prod', FALSE, JSON_OBJECT('source', 'phase10e_seed', 'resource', 'nexa_maps')),
    ('phase10f.npcs', 'dev', TRUE, JSON_OBJECT('source', 'phase10f_seed', 'resource', 'nexa_npcs')),
    ('phase10f.npcs', 'staging', FALSE, JSON_OBJECT('source', 'phase10f_seed', 'resource', 'nexa_npcs')),
    ('phase10f.npcs', 'prod', FALSE, JSON_OBJECT('source', 'phase10f_seed', 'resource', 'nexa_npcs')),
    ('phase11a.admin_core', 'dev', TRUE, JSON_OBJECT('source', 'phase11a_seed', 'resource', 'nexa_admin')),
    ('phase11a.admin_core', 'staging', FALSE, JSON_OBJECT('source', 'phase11a_seed', 'resource', 'nexa_admin')),
    ('phase11a.admin_core', 'prod', FALSE, JSON_OBJECT('source', 'phase11a_seed', 'resource', 'nexa_admin')),
    ('phase11b.reports', 'dev', TRUE, JSON_OBJECT('source', 'phase11b_seed', 'resource', 'nexa_admin')),
    ('phase11b.reports', 'staging', FALSE, JSON_OBJECT('source', 'phase11b_seed', 'resource', 'nexa_admin')),
    ('phase11b.reports', 'prod', FALSE, JSON_OBJECT('source', 'phase11b_seed', 'resource', 'nexa_admin')),
    ('phase11c.tickets', 'dev', TRUE, JSON_OBJECT('source', 'phase11c_seed', 'resource', 'nexa_admin')),
    ('phase11c.tickets', 'staging', FALSE, JSON_OBJECT('source', 'phase11c_seed', 'resource', 'nexa_admin')),
    ('phase11c.tickets', 'prod', FALSE, JSON_OBJECT('source', 'phase11c_seed', 'resource', 'nexa_admin')),
    ('phase11d.moderation_actions', 'dev', TRUE, JSON_OBJECT('source', 'phase11d_seed', 'resource', 'nexa_admin')),
    ('phase11d.moderation_actions', 'staging', FALSE, JSON_OBJECT('source', 'phase11d_seed', 'resource', 'nexa_admin')),
    ('phase11d.moderation_actions', 'prod', FALSE, JSON_OBJECT('source', 'phase11d_seed', 'resource', 'nexa_admin')),
    ('phase11e.admin_utility', 'dev', TRUE, JSON_OBJECT('source', 'phase11e_seed', 'resource', 'nexa_admin')),
    ('phase11e.admin_utility', 'staging', FALSE, JSON_OBJECT('source', 'phase11e_seed', 'resource', 'nexa_admin')),
    ('phase11e.admin_utility', 'prod', FALSE, JSON_OBJECT('source', 'phase11e_seed', 'resource', 'nexa_admin'))
ON DUPLICATE KEY UPDATE
    is_enabled = VALUES(is_enabled),
    metadata = VALUES(metadata);

INSERT INTO resource_settings (resource_name, setting_key, setting_value)
VALUES
    ('nexa_config', 'database_schema_version', JSON_QUOTE('20260706_1200')),
    ('nexa_bootstrap', 'requires_schema_migrations', JSON_EXTRACT('true', '$')),
    ('nexa_vehicledealer', 'default_dealer', JSON_QUOTE('premium_deluxe')),
    ('nexa_vehicledealer', 'seed_catalog', JSON_ARRAY(
        JSON_OBJECT('dealerId', 'premium_deluxe', 'catalogId', 'compacts_blista', 'model', 'blista', 'price', 18000, 'garageName', 'stadtgarage'),
        JSON_OBJECT('dealerId', 'premium_deluxe', 'catalogId', 'sedans_asea', 'model', 'asea', 'price', 22000, 'garageName', 'stadtgarage'),
        JSON_OBJECT('dealerId', 'premium_deluxe', 'catalogId', 'sedans_tailgater', 'model', 'tailgater', 'price', 52000, 'garageName', 'stadtgarage'),
        JSON_OBJECT('dealerId', 'premium_deluxe', 'catalogId', 'sports_sultan', 'model', 'sultan', 'price', 84000, 'garageName', 'stadtgarage')
    )),
    ('nexa_fuel', 'default_price_per_liter', JSON_EXTRACT('12', '$')),
    ('nexa_fuel', 'seed_stations', JSON_ARRAY(
        JSON_OBJECT('stationId', 'little_seoul_ltd', 'label', 'LTD Little Seoul', 'pricePerLiter', 12),
        JSON_OBJECT('stationId', 'sandy_ron', 'label', 'RON Sandy Shores', 'pricePerLiter', 10),
        JSON_OBJECT('stationId', 'paleto_ltd', 'label', 'LTD Paleto Bay', 'pricePerLiter', 11)
    )),
    ('nexa_impound', 'default_fee', JSON_EXTRACT('500', '$')),
    ('nexa_impound', 'seed_locations', JSON_ARRAY(
        JSON_OBJECT('locationId', 'mission_row_impound', 'label', 'Mission Row Verwahrung', 'fee', 500, 'releaseGarageName', 'stadtgarage'),
        JSON_OBJECT('locationId', 'sandy_impound', 'label', 'Sandy Shores Verwahrung', 'fee', 350, 'releaseGarageName', 'sandy_garage')
    )),
    ('nexa_housing', 'phase7a_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_housing', 'phase7b_access_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_housing', 'phase7c_storage_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_furniture', 'phase7d_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_furniture', 'max_furniture_per_unit', JSON_EXTRACT('100', '$')),
    ('nexa_furniture', 'placement_bounds_required', JSON_EXTRACT('true', '$')),
    ('nexa_furniture', 'placement_bounds_source', JSON_QUOTE('property_units.metadata.furniture.bounds')),
    ('nexa_housing', 'core_boundaries', JSON_ARRAY(
        'no_complex_interiors',
        'no_doorlock_full_integration',
        'storage_foundation_only',
        'property_access_only'
    ))
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

INSERT INTO resource_settings (resource_name, setting_key, setting_value)
VALUES
    ('nexa_factions_core', 'official_factions', JSON_ARRAY('lspd', 'ems', 'government', 'weazel')),
    ('nexa_factions_core', 'government_admin_only', JSON_EXTRACT('true', '$')),
    ('nexa_factions_core', 'phase8a_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_lspd', 'faction_name', JSON_QUOTE('lspd')),
    ('nexa_lspd', 'dispatch_access', JSON_QUOTE('read_only')),
    ('nexa_lspd', 'mdt_access', JSON_QUOTE('existing_only')),
    ('nexa_lspd', 'phase8b_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_ems', 'faction_name', JSON_QUOTE('ems')),
    ('nexa_ems', 'records_access', JSON_QUOTE('basic_only')),
    ('nexa_ems', 'billing_access', JSON_QUOTE('account_invoice_only')),
    ('nexa_ems', 'phase8c_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_government', 'faction_name', JSON_QUOTE('government')),
    ('nexa_government', 'documents_access', JSON_QUOTE('existing_api_only')),
    ('nexa_government', 'licenses_access', JSON_QUOTE('existing_api_only')),
    ('nexa_government', 'billing_access', JSON_QUOTE('account_invoice_only')),
    ('nexa_government', 'phase8d_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_weazel', 'faction_name', JSON_QUOTE('weazel')),
    ('nexa_weazel', 'press_pass_access', JSON_QUOTE('document_api_only')),
    ('nexa_weazel', 'announcements_access', JSON_QUOTE('server_validated_ephemeral')),
    ('nexa_weazel', 'phase8e_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_illegal_core', 'phase9a_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_illegal_core', 'reputation_access', JSON_QUOTE('nexa_api_criminal_only')),
    ('nexa_illegal_core', 'cooldowns', JSON_ARRAY('illegal.contact', 'illegal.reputation.adjust', 'blackmarket.buy', 'blackmarket.sell', 'drugs.plant', 'drugs.harvest', 'drugs.process', 'drugs.sell', 'moneywash.wash', 'chopshop.dismantle', 'chopshop.sell')),
    ('nexa_blackmarket', 'phase9b_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_blackmarket', 'trade_access', JSON_QUOTE('illegal_core_only')),
    ('nexa_blackmarket', 'catalog_source', JSON_QUOTE('server_config')),
    ('nexa_drugs', 'phase9c_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_drugs', 'lifecycle_access', JSON_QUOTE('illegal_core_only')),
    ('nexa_drugs', 'catalog_source', JSON_QUOTE('server_config')),
    ('nexa_moneywash', 'phase9d_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_moneywash', 'wash_access', JSON_QUOTE('illegal_core_only')),
    ('nexa_moneywash', 'ledger_source', JSON_QUOTE('nexa_api_account')),
    ('nexa_chopshop', 'phase9e_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_chopshop', 'vehicle_access', JSON_QUOTE('illegal_core_only')),
    ('nexa_chopshop', 'parts_source', JSON_QUOTE('server_config')),
    ('nexa_evidence', 'phase9f_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_evidence', 'police_api_access', JSON_QUOTE('nexa_api_police_only')),
    ('nexa_evidence', 'forensic_types', JSON_ARRAY('dna', 'fingerprint', 'shell_casing', 'blood', 'generic')),
    ('nexa_worldstates', 'phase10a_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_worldstates', 'state_storage', JSON_QUOTE('resource_settings')),
    ('nexa_worldstates', 'broadcast_policy', JSON_QUOTE('request_only')),
    ('nexa_blips', 'phase10b_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_blips', 'source', JSON_QUOTE('server_config')),
    ('nexa_blips', 'player_blips', JSON_QUOTE('forbidden')),
    ('nexa_zones', 'phase10c_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_zones', 'source', JSON_QUOTE('server_config')),
    ('nexa_zones', 'critical_validation', JSON_QUOTE('server_authoritative')),
    ('nexa_zones', 'safezones', JSON_QUOTE('foundation_only')),
    ('nexa_interiors', 'phase10d_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_interiors', 'registry_source', JSON_QUOTE('server_config')),
    ('nexa_interiors', 'doorlock_integration', JSON_QUOTE('prepared_only')),
    ('nexa_interiors', 'teleport', JSON_QUOTE('forbidden')),
    ('nexa_interiors', 'mlo_assets', JSON_QUOTE('external_registry_only')),
    ('nexa_maps', 'phase10e_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_maps', 'registry_source', JSON_QUOTE('server_config')),
    ('nexa_maps', 'asset_creation', JSON_QUOTE('forbidden')),
    ('nexa_maps', 'asset_storage', JSON_QUOTE('external_addon_resources_only')),
    ('nexa_maps', 'environment_config', JSON_QUOTE('registry_only')),
    ('nexa_npcs', 'phase10f_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_npcs', 'registry_source', JSON_QUOTE('server_config')),
    ('nexa_npcs', 'spawn_policy', JSON_QUOTE('disabled_in_phase10f')),
    ('nexa_npcs', 'target_policy', JSON_QUOTE('ox_target_compatible_metadata_only')),
    ('nexa_npcs', 'gameplay_policy', JSON_QUOTE('fach_api_only')),
    ('nexa_admin', 'admin_core_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_admin', 'actions_contract_only', JSON_EXTRACT('true', '$')),
    ('nexa_admin', 'reports_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_admin', 'reports_storage', JSON_QUOTE('server_runtime_audited')),
    ('nexa_admin', 'tickets_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_admin', 'tickets_storage', JSON_QUOTE('server_runtime_audited')),
    ('nexa_admin', 'moderation_actions_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_admin', 'moderation_storage', JSON_QUOTE('server_runtime_audited')),
    ('nexa_admin', 'tempban_policy', JSON_QUOTE('prepared_only')),
    ('nexa_admin', 'spectate_policy', JSON_QUOTE('prepared_only')),
    ('nexa_admin', 'admin_utility_enabled', JSON_EXTRACT('true', '$')),
    ('nexa_admin', 'teleport_policy', JSON_QUOTE('server_authorized_client_effect')),
    ('nexa_admin', 'heal_policy', JSON_QUOTE('prepared_only')),
    ('nexa_admin', 'revive_policy', JSON_QUOTE('prepared_only_no_ems_override')),
    ('nexa_admin', 'devtools_policy', JSON_QUOTE('forbidden_in_production'))
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

INSERT INTO permission_roles (name, label, scope, priority, is_system, is_active, metadata)
VALUES
    ('admin', 'Administration', 'system', 1000, TRUE, TRUE, JSON_OBJECT('source', 'phase3_1_seed')),
    ('team', 'Team', 'system', 700, TRUE, TRUE, JSON_OBJECT('source', 'phase3_1_seed')),
    ('support', 'Support', 'system', 500, TRUE, TRUE, JSON_OBJECT('source', 'phase3_1_seed'))
ON DUPLICATE KEY UPDATE
    label = VALUES(label),
    scope = VALUES(scope),
    priority = VALUES(priority),
    is_system = VALUES(is_system),
    is_active = VALUES(is_active),
    metadata = VALUES(metadata);

INSERT INTO role_permissions (role_id, permission, is_allowed, metadata)
SELECT permission_roles.id, seeded_permissions.permission, TRUE, JSON_OBJECT('source', 'phase3_1_seed')
FROM permission_roles
JOIN (
    SELECT 'admin' AS role_name, 'admin.kick' AS permission UNION ALL
    SELECT 'admin', 'admin.ban' UNION ALL
    SELECT 'admin', 'admin.warn' UNION ALL
    SELECT 'admin', 'admin.menu' UNION ALL
    SELECT 'admin', 'admin.players.view' UNION ALL
    SELECT 'admin', 'admin.actions.preview' UNION ALL
    SELECT 'admin', 'admin.audit.view' UNION ALL
    SELECT 'admin', 'admin.permissions.view' UNION ALL
    SELECT 'admin', 'admin.reports.view' UNION ALL
    SELECT 'admin', 'admin.reports.accept' UNION ALL
    SELECT 'admin', 'admin.reports.close' UNION ALL
    SELECT 'admin', 'admin.tickets.view' UNION ALL
    SELECT 'admin', 'admin.tickets.assign' UNION ALL
    SELECT 'admin', 'admin.tickets.close' UNION ALL
    SELECT 'admin', 'admin.moderation.warn' UNION ALL
    SELECT 'admin', 'admin.moderation.kick' UNION ALL
    SELECT 'admin', 'admin.moderation.freeze' UNION ALL
    SELECT 'admin', 'admin.moderation.tempban.prepare' UNION ALL
    SELECT 'admin', 'admin.moderation.spectate.prepare' UNION ALL
    SELECT 'admin', 'admin.moderation.notes.add' UNION ALL
    SELECT 'admin', 'admin.moderation.notes.view' UNION ALL
    SELECT 'admin', 'admin.utility.bring' UNION ALL
    SELECT 'admin', 'admin.utility.goto' UNION ALL
    SELECT 'admin', 'admin.utility.return' UNION ALL
    SELECT 'admin', 'admin.utility.coords' UNION ALL
    SELECT 'admin', 'admin.utility.heal.prepare' UNION ALL
    SELECT 'admin', 'admin.utility.revive.prepare' UNION ALL
    SELECT 'team', 'admin.menu' UNION ALL
    SELECT 'team', 'admin.players.view' UNION ALL
    SELECT 'team', 'admin.actions.preview' UNION ALL
    SELECT 'team', 'admin.audit.view' UNION ALL
    SELECT 'team', 'admin.reports.view' UNION ALL
    SELECT 'team', 'admin.reports.accept' UNION ALL
    SELECT 'team', 'admin.reports.close' UNION ALL
    SELECT 'team', 'admin.tickets.view' UNION ALL
    SELECT 'team', 'admin.tickets.assign' UNION ALL
    SELECT 'team', 'admin.tickets.close' UNION ALL
    SELECT 'team', 'admin.moderation.warn' UNION ALL
    SELECT 'team', 'admin.moderation.kick' UNION ALL
    SELECT 'team', 'admin.moderation.freeze' UNION ALL
    SELECT 'team', 'admin.moderation.spectate.prepare' UNION ALL
    SELECT 'team', 'admin.moderation.notes.add' UNION ALL
    SELECT 'team', 'admin.moderation.notes.view' UNION ALL
    SELECT 'team', 'admin.utility.bring' UNION ALL
    SELECT 'team', 'admin.utility.goto' UNION ALL
    SELECT 'team', 'admin.utility.return' UNION ALL
    SELECT 'team', 'admin.utility.coords' UNION ALL
    SELECT 'team', 'admin.utility.heal.prepare' UNION ALL
    SELECT 'team', 'admin.utility.revive.prepare' UNION ALL
    SELECT 'support', 'admin.menu' UNION ALL
    SELECT 'support', 'admin.players.view' UNION ALL
    SELECT 'support', 'admin.actions.preview' UNION ALL
    SELECT 'support', 'admin.reports.view' UNION ALL
    SELECT 'support', 'admin.tickets.view' UNION ALL
    SELECT 'support', 'admin.moderation.notes.add' UNION ALL
    SELECT 'admin', 'logs.read' UNION ALL
    SELECT 'admin', 'security.review' UNION ALL
    SELECT 'admin', 'permissions.manage' UNION ALL
    SELECT 'admin', 'documents.issue' UNION ALL
    SELECT 'admin', 'documents.revoke' UNION ALL
    SELECT 'admin', 'licenses.issue' UNION ALL
    SELECT 'admin', 'licenses.revoke' UNION ALL
    SELECT 'admin', 'account.admin.credit' UNION ALL
    SELECT 'admin', 'account.admin.debit' UNION ALL
    SELECT 'admin', 'account.audit' UNION ALL
    SELECT 'admin', 'jobs.manage' UNION ALL
    SELECT 'admin', 'jobs.assign' UNION ALL
    SELECT 'admin', 'jobs.salary' UNION ALL
    SELECT 'admin', 'business.create' UNION ALL
    SELECT 'admin', 'business.manage' UNION ALL
    SELECT 'admin', 'business.manageMembers' UNION ALL
    SELECT 'admin', 'business.transfer' UNION ALL
    SELECT 'admin', 'dispatch.view' UNION ALL
    SELECT 'admin', 'dispatch.create' UNION ALL
    SELECT 'admin', 'dispatch.assign' UNION ALL
    SELECT 'admin', 'dispatch.status' UNION ALL
    SELECT 'admin', 'dispatch.priority' UNION ALL
    SELECT 'admin', 'dispatch.manage' UNION ALL
    SELECT 'admin', 'police.mdt.view' UNION ALL
    SELECT 'admin', 'police.mdt.records' UNION ALL
    SELECT 'admin', 'vehicledealer.manage' UNION ALL
    SELECT 'admin', 'vehicledealer.audit' UNION ALL
    SELECT 'admin', 'fuel.audit' UNION ALL
    SELECT 'admin', 'fuel.manage' UNION ALL
    SELECT 'admin', 'impound.status' UNION ALL
    SELECT 'admin', 'impound.create' UNION ALL
    SELECT 'admin', 'impound.release' UNION ALL
    SELECT 'admin', 'impound.manage' UNION ALL
    SELECT 'admin', 'impound.audit' UNION ALL
    SELECT 'admin', 'admin.impound' UNION ALL
    SELECT 'admin', 'housing.manage' UNION ALL
    SELECT 'admin', 'housing.audit' UNION ALL
    SELECT 'admin', 'housing.access.grant' UNION ALL
    SELECT 'admin', 'housing.access.revoke' UNION ALL
    SELECT 'admin', 'housing.access.list' UNION ALL
    SELECT 'admin', 'housing.furniture.audit' UNION ALL
    SELECT 'team', 'logs.read' UNION ALL
    SELECT 'team', 'security.review' UNION ALL
    SELECT 'team', 'documents.issue' UNION ALL
    SELECT 'team', 'documents.revoke' UNION ALL
    SELECT 'team', 'licenses.issue' UNION ALL
    SELECT 'team', 'licenses.revoke' UNION ALL
    SELECT 'team', 'account.audit' UNION ALL
    SELECT 'team', 'jobs.assign' UNION ALL
    SELECT 'team', 'business.create' UNION ALL
    SELECT 'team', 'business.manage' UNION ALL
    SELECT 'team', 'dispatch.view' UNION ALL
    SELECT 'team', 'dispatch.assign' UNION ALL
    SELECT 'team', 'dispatch.status' UNION ALL
    SELECT 'team', 'dispatch.priority' UNION ALL
    SELECT 'team', 'police.mdt.view' UNION ALL
    SELECT 'team', 'police.mdt.records' UNION ALL
    SELECT 'team', 'vehicledealer.audit' UNION ALL
    SELECT 'team', 'fuel.audit' UNION ALL
    SELECT 'team', 'impound.status' UNION ALL
    SELECT 'team', 'impound.create' UNION ALL
    SELECT 'team', 'impound.release' UNION ALL
    SELECT 'team', 'impound.audit' UNION ALL
    SELECT 'team', 'housing.audit' UNION ALL
    SELECT 'team', 'housing.access.list' UNION ALL
    SELECT 'team', 'housing.furniture.audit' UNION ALL
    SELECT 'admin', 'government.admin' UNION ALL
    SELECT 'admin', 'faction.official.manage' UNION ALL
    SELECT 'admin', 'security.anticheat.manage' UNION ALL
    SELECT 'support', 'logs.read'
) AS seeded_permissions
    ON permission_roles.name = seeded_permissions.role_name
ON DUPLICATE KEY UPDATE
    is_allowed = VALUES(is_allowed),
    metadata = VALUES(metadata);

INSERT INTO role_permissions (role_id, permission, is_allowed, metadata)
SELECT permission_roles.id, seeded_permissions.permission, TRUE, JSON_OBJECT('source', 'phase8a_seed')
FROM permission_roles
JOIN (
    SELECT 'admin' AS role_name, 'faction.members.view' AS permission UNION ALL
    SELECT 'admin', 'faction.members.manage' UNION ALL
    SELECT 'admin', 'faction.callsign.self' UNION ALL
    SELECT 'admin', 'faction.callsign.manage' UNION ALL
    SELECT 'admin', 'faction.duty.toggle' UNION ALL
    SELECT 'admin', 'faction.accounts.view' UNION ALL
    SELECT 'admin', 'faction.accounts.manage' UNION ALL
    SELECT 'admin', 'faction.accounts.transfer' UNION ALL
    SELECT 'admin', 'faction.audit' UNION ALL
    SELECT 'admin', 'government.members.manage' UNION ALL
    SELECT 'admin', 'government.documents.issue' UNION ALL
    SELECT 'admin', 'government.documents.revoke' UNION ALL
    SELECT 'admin', 'government.licenses.issue' UNION ALL
    SELECT 'admin', 'government.licenses.revoke' UNION ALL
    SELECT 'admin', 'government.fees.create' UNION ALL
    SELECT 'admin', 'weazel.press.issue' UNION ALL
    SELECT 'admin', 'weazel.announcement.create' UNION ALL
    SELECT 'admin', 'criminal.reputation.view' UNION ALL
    SELECT 'admin', 'criminal.reputation.adjust' UNION ALL
    SELECT 'admin', 'criminal.cooldown.bypass' UNION ALL
    SELECT 'admin', 'criminal.audit' UNION ALL
    SELECT 'admin', 'criminal.blackmarket.view' UNION ALL
    SELECT 'admin', 'criminal.blackmarket.trade' UNION ALL
    SELECT 'admin', 'criminal.drugs.trade' UNION ALL
    SELECT 'admin', 'criminal.moneywash.trade' UNION ALL
    SELECT 'admin', 'criminal.chopshop.trade' UNION ALL
    SELECT 'admin', 'police.evidence.collect' UNION ALL
    SELECT 'admin', 'police.evidence.read' UNION ALL
    SELECT 'admin', 'police.evidence.manage' UNION ALL
    SELECT 'admin', 'world.state.read' UNION ALL
    SELECT 'admin', 'world.state.manage' UNION ALL
    SELECT 'team', 'faction.members.view' UNION ALL
    SELECT 'team', 'faction.callsign.self' UNION ALL
    SELECT 'team', 'faction.accounts.view' UNION ALL
    SELECT 'team', 'faction.audit' UNION ALL
    SELECT 'team', 'government.documents.issue' UNION ALL
    SELECT 'team', 'government.licenses.issue' UNION ALL
    SELECT 'team', 'weazel.press.issue' UNION ALL
    SELECT 'team', 'weazel.announcement.create' UNION ALL
    SELECT 'team', 'criminal.reputation.view' UNION ALL
    SELECT 'team', 'criminal.audit' UNION ALL
    SELECT 'team', 'criminal.blackmarket.view' UNION ALL
    SELECT 'team', 'criminal.drugs.trade' UNION ALL
    SELECT 'team', 'criminal.moneywash.trade' UNION ALL
    SELECT 'team', 'criminal.chopshop.trade' UNION ALL
    SELECT 'team', 'police.evidence.read' UNION ALL
    SELECT 'team', 'world.state.read'
) AS seeded_permissions
    ON seeded_permissions.role_name = permission_roles.name
ON DUPLICATE KEY UPDATE
    is_allowed = VALUES(is_allowed),
    metadata = VALUES(metadata);

INSERT INTO document_types (name, label, requires_signature, default_valid_days, is_active)
VALUES
    ('identity_card', 'Personalausweis', TRUE, 365, TRUE),
    ('residence_certificate', 'Meldebescheinigung', TRUE, 180, TRUE),
    ('medical_clearance', 'Medizinische Bescheinigung', TRUE, 90, TRUE),
    ('press_card', 'Presseausweis', TRUE, 180, TRUE)
ON DUPLICATE KEY UPDATE
    label = VALUES(label),
    requires_signature = VALUES(requires_signature),
    default_valid_days = VALUES(default_valid_days),
    is_active = VALUES(is_active);

INSERT INTO license_types (name, label, category, is_active)
VALUES
    ('driver_car', 'Fuehrerschein Klasse B', 'driving', TRUE),
    ('driver_motorcycle', 'Fuehrerschein Klasse A', 'driving', TRUE),
    ('weapon_basic', 'Waffenlizenz Basis', 'weapon', TRUE),
    ('business_general', 'Gewerbelizenz Allgemein', 'business', TRUE)
ON DUPLICATE KEY UPDATE
    label = VALUES(label),
    category = VALUES(category),
    is_active = VALUES(is_active);

INSERT INTO jobs (name, label, job_type, is_active, metadata)
VALUES
    ('unemployed', 'Arbeitslos', 'civilian', TRUE, JSON_OBJECT('source', 'phase4d_seed')),
    ('taxi', 'Downtown Cab Co.', 'civilian', TRUE, JSON_OBJECT('source', 'phase4d_seed')),
    ('mechanic', 'Los Santos Customs', 'civilian', TRUE, JSON_OBJECT('source', 'phase4d_seed')),
    ('news', 'Weazel News', 'civilian', TRUE, JSON_OBJECT('source', 'phase4d_seed'))
ON DUPLICATE KEY UPDATE
    label = VALUES(label),
    job_type = VALUES(job_type),
    is_active = VALUES(is_active),
    metadata = VALUES(metadata);

INSERT INTO job_grades (job_id, grade_level, name, label, salary, permissions)
SELECT jobs.id, seeded_grades.grade_level, seeded_grades.name, seeded_grades.label, seeded_grades.salary, seeded_grades.permissions
FROM jobs
JOIN (
    SELECT 'unemployed' AS job_name, 0 AS grade_level, 'none' AS name, 'Ohne Anstellung' AS label, 0 AS salary, JSON_ARRAY() AS permissions UNION ALL
    SELECT 'taxi', 0, 'driver', 'Fahrer', 125, JSON_ARRAY('job.duty', 'job.salary') UNION ALL
    SELECT 'taxi', 1, 'dispatcher', 'Disposition', 175, JSON_ARRAY('job.duty', 'job.salary') UNION ALL
    SELECT 'mechanic', 0, 'trainee', 'Azubi', 150, JSON_ARRAY('job.duty', 'job.salary') UNION ALL
    SELECT 'mechanic', 1, 'mechanic', 'Mechaniker', 225, JSON_ARRAY('job.duty', 'job.salary') UNION ALL
    SELECT 'news', 0, 'reporter', 'Reporter', 150, JSON_ARRAY('job.duty', 'job.salary') UNION ALL
    SELECT 'news', 1, 'editor', 'Redaktion', 200, JSON_ARRAY('job.duty', 'job.salary')
) AS seeded_grades
    ON jobs.name = seeded_grades.job_name
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    label = VALUES(label),
    salary = VALUES(salary),
    permissions = VALUES(permissions);

INSERT INTO factions (name, label, faction_type, status, metadata)
VALUES
    ('lspd', 'Los Santos Police Department', 'law', 'active', JSON_OBJECT('source', 'adr004', 'official', TRUE)),
    ('ems', 'San Andreas Medical Services', 'medical', 'active', JSON_OBJECT('source', 'adr004', 'official', TRUE)),
    ('government', 'Government', 'government', 'active', JSON_OBJECT('source', 'adr004', 'official', TRUE, 'adminOnly', TRUE)),
    ('weazel', 'Weazel News', 'media', 'active', JSON_OBJECT('source', 'adr004', 'official', TRUE))
ON DUPLICATE KEY UPDATE
    label = VALUES(label),
    faction_type = VALUES(faction_type),
    status = VALUES(status),
    metadata = VALUES(metadata);

UPDATE factions
SET status = 'disabled',
    metadata = JSON_SET(COALESCE(metadata, JSON_OBJECT()), '$.disabledBy', 'adr004', '$.official', FALSE)
WHERE name IN ('bcso', 'sahp', 'fib');

INSERT INTO faction_grades (faction_id, grade_level, name, label, permissions)
SELECT factions.id, seeded_grades.grade_level, seeded_grades.name, seeded_grades.label, seeded_grades.permissions
FROM factions
JOIN (
    SELECT 'lspd' AS faction_name, 0 AS grade_level, 'cadet' AS name, 'Cadet' AS label,
        JSON_ARRAY('faction.members.view', 'faction.duty.toggle', 'faction.callsign.self', 'faction.accounts.view', 'dispatch.view', 'police.mdt.view', 'police.mdt.records', 'police.evidence.read') AS permissions UNION ALL
    SELECT 'lspd', 1, 'officer', 'Officer I',
        JSON_ARRAY('faction.members.view', 'faction.duty.toggle', 'faction.callsign.self', 'faction.accounts.view', 'dispatch.view', 'police.mdt.view', 'police.mdt.records', 'police.evidence.collect', 'police.evidence.read') UNION ALL
    SELECT 'lspd', 2, 'sergeant', 'Sergeant',
        JSON_ARRAY('faction.members.view', 'faction.members.manage', 'faction.duty.toggle', 'faction.callsign.self', 'faction.callsign.manage', 'faction.accounts.view', 'dispatch.view', 'dispatch.assign', 'dispatch.status', 'police.mdt.view', 'police.mdt.records', 'police.evidence.collect', 'police.evidence.read', 'police.evidence.manage') UNION ALL
    SELECT 'lspd', 3, 'captain', 'Captain',
        JSON_ARRAY('faction.members.view', 'faction.members.manage', 'faction.duty.toggle', 'faction.callsign.self', 'faction.callsign.manage', 'faction.accounts.view', 'faction.accounts.manage', 'faction.accounts.transfer', 'dispatch.view', 'dispatch.assign', 'dispatch.status', 'dispatch.priority', 'police.mdt.view', 'police.mdt.records', 'police.evidence.collect', 'police.evidence.read', 'police.evidence.manage') UNION ALL
    SELECT 'ems', 0, 'trainee', 'Trainee',
        JSON_ARRAY('faction.members.view', 'faction.duty.toggle', 'faction.callsign.self', 'faction.accounts.view', 'ems.records.view') UNION ALL
    SELECT 'ems', 1, 'paramedic', 'Paramedic',
        JSON_ARRAY('faction.members.view', 'faction.duty.toggle', 'faction.callsign.self', 'faction.accounts.view', 'ems.records.view', 'ems.records.create', 'ems.treatments.create') UNION ALL
    SELECT 'ems', 2, 'supervisor', 'Supervisor',
        JSON_ARRAY('faction.members.view', 'faction.members.manage', 'faction.duty.toggle', 'faction.callsign.self', 'faction.callsign.manage', 'faction.accounts.view', 'ems.records.view', 'ems.records.create', 'ems.treatments.create', 'ems.billing.create') UNION ALL
    SELECT 'ems', 3, 'chief', 'Chief',
        JSON_ARRAY('faction.members.view', 'faction.members.manage', 'faction.duty.toggle', 'faction.callsign.self', 'faction.callsign.manage', 'faction.accounts.view', 'faction.accounts.manage', 'faction.accounts.transfer', 'ems.records.view', 'ems.records.create', 'ems.treatments.create', 'ems.billing.create') UNION ALL
    SELECT 'government', 0, 'clerk', 'Clerk',
        JSON_ARRAY('faction.members.view', 'faction.duty.toggle', 'faction.accounts.view', 'government.documents.issue', 'government.licenses.issue') UNION ALL
    SELECT 'government', 1, 'advisor', 'Advisor',
        JSON_ARRAY('faction.members.view', 'faction.duty.toggle', 'faction.accounts.view', 'faction.callsign.self', 'government.documents.issue', 'government.licenses.issue', 'government.fees.create') UNION ALL
    SELECT 'government', 2, 'director', 'Director',
        JSON_ARRAY('faction.members.view', 'faction.duty.toggle', 'faction.accounts.view', 'faction.accounts.manage', 'faction.callsign.self', 'faction.callsign.manage', 'government.documents.issue', 'government.documents.revoke', 'government.licenses.issue', 'government.licenses.revoke', 'government.fees.create') UNION ALL
    SELECT 'government', 3, 'administrator', 'Administrator',
        JSON_ARRAY('faction.members.view', 'faction.members.manage', 'faction.duty.toggle', 'faction.accounts.view', 'faction.accounts.manage', 'faction.accounts.transfer', 'faction.callsign.self', 'faction.callsign.manage', 'government.documents.issue', 'government.documents.revoke', 'government.licenses.issue', 'government.licenses.revoke', 'government.fees.create') UNION ALL
    SELECT 'weazel', 0, 'intern', 'Intern',
        JSON_ARRAY('faction.members.view', 'faction.duty.toggle', 'faction.callsign.self', 'faction.accounts.view') UNION ALL
    SELECT 'weazel', 1, 'reporter', 'Reporter',
        JSON_ARRAY('faction.members.view', 'faction.duty.toggle', 'faction.callsign.self', 'faction.accounts.view', 'weazel.announcement.create') UNION ALL
    SELECT 'weazel', 2, 'producer', 'Producer',
        JSON_ARRAY('faction.members.view', 'faction.members.manage', 'faction.duty.toggle', 'faction.callsign.self', 'faction.callsign.manage', 'faction.accounts.view', 'weazel.press.issue', 'weazel.announcement.create') UNION ALL
    SELECT 'weazel', 3, 'editor', 'Editor',
        JSON_ARRAY('faction.members.view', 'faction.members.manage', 'faction.duty.toggle', 'faction.callsign.self', 'faction.callsign.manage', 'faction.accounts.view', 'faction.accounts.manage', 'faction.accounts.transfer', 'weazel.press.issue', 'weazel.announcement.create')
) AS seeded_grades
    ON seeded_grades.faction_name = factions.name
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    label = VALUES(label),
    permissions = VALUES(permissions);

INSERT INTO faction_permissions (faction_grade_id, permission, is_allowed)
SELECT faction_grades.id, permission_matrix.permission, TRUE
FROM faction_grades
JOIN (
    SELECT 'cadet' AS grade_name, 'faction.members.view' AS permission UNION ALL
    SELECT 'cadet', 'faction.duty.toggle' UNION ALL
    SELECT 'cadet', 'faction.callsign.self' UNION ALL
    SELECT 'cadet', 'faction.accounts.view' UNION ALL
    SELECT 'cadet', 'dispatch.view' UNION ALL
    SELECT 'cadet', 'police.mdt.view' UNION ALL
    SELECT 'cadet', 'police.mdt.records' UNION ALL
    SELECT 'officer', 'faction.members.view' UNION ALL
    SELECT 'officer', 'faction.duty.toggle' UNION ALL
    SELECT 'officer', 'faction.callsign.self' UNION ALL
    SELECT 'officer', 'faction.accounts.view' UNION ALL
    SELECT 'officer', 'dispatch.view' UNION ALL
    SELECT 'officer', 'police.mdt.view' UNION ALL
    SELECT 'officer', 'police.mdt.records' UNION ALL
    SELECT 'sergeant', 'faction.members.view' UNION ALL
    SELECT 'sergeant', 'faction.members.manage' UNION ALL
    SELECT 'sergeant', 'faction.duty.toggle' UNION ALL
    SELECT 'sergeant', 'faction.callsign.self' UNION ALL
    SELECT 'sergeant', 'faction.callsign.manage' UNION ALL
    SELECT 'sergeant', 'faction.accounts.view' UNION ALL
    SELECT 'sergeant', 'dispatch.view' UNION ALL
    SELECT 'sergeant', 'dispatch.assign' UNION ALL
    SELECT 'sergeant', 'dispatch.status' UNION ALL
    SELECT 'sergeant', 'police.mdt.view' UNION ALL
    SELECT 'sergeant', 'police.mdt.records' UNION ALL
    SELECT 'captain', 'faction.members.view' UNION ALL
    SELECT 'captain', 'faction.members.manage' UNION ALL
    SELECT 'captain', 'faction.duty.toggle' UNION ALL
    SELECT 'captain', 'faction.callsign.self' UNION ALL
    SELECT 'captain', 'faction.callsign.manage' UNION ALL
    SELECT 'captain', 'faction.accounts.view' UNION ALL
    SELECT 'captain', 'faction.accounts.manage' UNION ALL
    SELECT 'captain', 'faction.accounts.transfer' UNION ALL
    SELECT 'captain', 'dispatch.view' UNION ALL
    SELECT 'captain', 'dispatch.assign' UNION ALL
    SELECT 'captain', 'dispatch.status' UNION ALL
    SELECT 'captain', 'dispatch.priority' UNION ALL
    SELECT 'captain', 'police.mdt.view' UNION ALL
    SELECT 'captain', 'police.mdt.records' UNION ALL
    SELECT 'cadet', 'police.evidence.read' UNION ALL
    SELECT 'officer', 'police.evidence.collect' UNION ALL
    SELECT 'officer', 'police.evidence.read' UNION ALL
    SELECT 'sergeant', 'police.evidence.collect' UNION ALL
    SELECT 'sergeant', 'police.evidence.read' UNION ALL
    SELECT 'sergeant', 'police.evidence.manage' UNION ALL
    SELECT 'captain', 'police.evidence.collect' UNION ALL
    SELECT 'captain', 'police.evidence.read' UNION ALL
    SELECT 'captain', 'police.evidence.manage' UNION ALL
    SELECT 'trainee', 'faction.members.view' UNION ALL
    SELECT 'trainee', 'faction.duty.toggle' UNION ALL
    SELECT 'trainee', 'faction.callsign.self' UNION ALL
    SELECT 'trainee', 'faction.accounts.view' UNION ALL
    SELECT 'trainee', 'ems.records.view' UNION ALL
    SELECT 'paramedic', 'faction.members.view' UNION ALL
    SELECT 'paramedic', 'faction.duty.toggle' UNION ALL
    SELECT 'paramedic', 'faction.callsign.self' UNION ALL
    SELECT 'paramedic', 'faction.accounts.view' UNION ALL
    SELECT 'paramedic', 'ems.records.view' UNION ALL
    SELECT 'paramedic', 'ems.records.create' UNION ALL
    SELECT 'paramedic', 'ems.treatments.create' UNION ALL
    SELECT 'supervisor', 'faction.members.view' UNION ALL
    SELECT 'supervisor', 'faction.members.manage' UNION ALL
    SELECT 'supervisor', 'faction.duty.toggle' UNION ALL
    SELECT 'supervisor', 'faction.callsign.self' UNION ALL
    SELECT 'supervisor', 'faction.callsign.manage' UNION ALL
    SELECT 'supervisor', 'faction.accounts.view' UNION ALL
    SELECT 'supervisor', 'ems.records.view' UNION ALL
    SELECT 'supervisor', 'ems.records.create' UNION ALL
    SELECT 'supervisor', 'ems.treatments.create' UNION ALL
    SELECT 'supervisor', 'ems.billing.create' UNION ALL
    SELECT 'chief', 'faction.members.view' UNION ALL
    SELECT 'chief', 'faction.members.manage' UNION ALL
    SELECT 'chief', 'faction.duty.toggle' UNION ALL
    SELECT 'chief', 'faction.callsign.self' UNION ALL
    SELECT 'chief', 'faction.callsign.manage' UNION ALL
    SELECT 'chief', 'faction.accounts.view' UNION ALL
    SELECT 'chief', 'faction.accounts.manage' UNION ALL
    SELECT 'chief', 'faction.accounts.transfer' UNION ALL
    SELECT 'chief', 'ems.records.view' UNION ALL
    SELECT 'chief', 'ems.records.create' UNION ALL
    SELECT 'chief', 'ems.treatments.create' UNION ALL
    SELECT 'chief', 'ems.billing.create' UNION ALL
    SELECT 'clerk', 'faction.members.view' UNION ALL
    SELECT 'clerk', 'faction.accounts.view' UNION ALL
    SELECT 'clerk', 'faction.duty.toggle' UNION ALL
    SELECT 'clerk', 'government.documents.issue' UNION ALL
    SELECT 'clerk', 'government.licenses.issue' UNION ALL
    SELECT 'advisor', 'faction.members.view' UNION ALL
    SELECT 'advisor', 'faction.accounts.view' UNION ALL
    SELECT 'advisor', 'faction.callsign.self' UNION ALL
    SELECT 'advisor', 'faction.duty.toggle' UNION ALL
    SELECT 'advisor', 'government.documents.issue' UNION ALL
    SELECT 'advisor', 'government.licenses.issue' UNION ALL
    SELECT 'advisor', 'government.fees.create' UNION ALL
    SELECT 'director', 'faction.members.view' UNION ALL
    SELECT 'director', 'faction.accounts.view' UNION ALL
    SELECT 'director', 'faction.accounts.manage' UNION ALL
    SELECT 'director', 'faction.callsign.self' UNION ALL
    SELECT 'director', 'faction.callsign.manage' UNION ALL
    SELECT 'director', 'faction.duty.toggle' UNION ALL
    SELECT 'director', 'government.documents.issue' UNION ALL
    SELECT 'director', 'government.documents.revoke' UNION ALL
    SELECT 'director', 'government.licenses.issue' UNION ALL
    SELECT 'director', 'government.licenses.revoke' UNION ALL
    SELECT 'director', 'government.fees.create' UNION ALL
    SELECT 'administrator', 'faction.members.view' UNION ALL
    SELECT 'administrator', 'faction.members.manage' UNION ALL
    SELECT 'administrator', 'faction.accounts.view' UNION ALL
    SELECT 'administrator', 'faction.accounts.manage' UNION ALL
    SELECT 'administrator', 'faction.accounts.transfer' UNION ALL
    SELECT 'administrator', 'faction.callsign.self' UNION ALL
    SELECT 'administrator', 'faction.callsign.manage' UNION ALL
    SELECT 'administrator', 'faction.duty.toggle' UNION ALL
    SELECT 'administrator', 'government.documents.issue' UNION ALL
    SELECT 'administrator', 'government.documents.revoke' UNION ALL
    SELECT 'administrator', 'government.licenses.issue' UNION ALL
    SELECT 'administrator', 'government.licenses.revoke' UNION ALL
    SELECT 'administrator', 'government.fees.create' UNION ALL
    SELECT 'intern', 'faction.members.view' UNION ALL
    SELECT 'intern', 'faction.duty.toggle' UNION ALL
    SELECT 'intern', 'faction.callsign.self' UNION ALL
    SELECT 'intern', 'faction.accounts.view' UNION ALL
    SELECT 'reporter', 'faction.members.view' UNION ALL
    SELECT 'reporter', 'faction.duty.toggle' UNION ALL
    SELECT 'reporter', 'faction.callsign.self' UNION ALL
    SELECT 'reporter', 'faction.accounts.view' UNION ALL
    SELECT 'reporter', 'weazel.announcement.create' UNION ALL
    SELECT 'producer', 'faction.members.view' UNION ALL
    SELECT 'producer', 'faction.members.manage' UNION ALL
    SELECT 'producer', 'faction.duty.toggle' UNION ALL
    SELECT 'producer', 'faction.callsign.self' UNION ALL
    SELECT 'producer', 'faction.callsign.manage' UNION ALL
    SELECT 'producer', 'faction.accounts.view' UNION ALL
    SELECT 'producer', 'weazel.press.issue' UNION ALL
    SELECT 'producer', 'weazel.announcement.create' UNION ALL
    SELECT 'editor', 'faction.members.view' UNION ALL
    SELECT 'editor', 'faction.members.manage' UNION ALL
    SELECT 'editor', 'faction.duty.toggle' UNION ALL
    SELECT 'editor', 'faction.callsign.self' UNION ALL
    SELECT 'editor', 'faction.callsign.manage' UNION ALL
    SELECT 'editor', 'faction.accounts.view' UNION ALL
    SELECT 'editor', 'faction.accounts.manage' UNION ALL
    SELECT 'editor', 'faction.accounts.transfer' UNION ALL
    SELECT 'editor', 'weazel.press.issue' UNION ALL
    SELECT 'editor', 'weazel.announcement.create'
) AS permission_matrix
    ON permission_matrix.grade_name = faction_grades.name
ON DUPLICATE KEY UPDATE
    is_allowed = VALUES(is_allowed);

INSERT INTO radio_channels (frequency, name, label, channel_type, faction_id, is_active, metadata)
SELECT seeded_channels.frequency, seeded_channels.name, seeded_channels.label, 'faction', factions.id, TRUE,
    JSON_OBJECT('source', 'phase8a_seed', 'official', TRUE)
FROM factions
JOIN (
    SELECT 'lspd' AS faction_name, 1.10 AS frequency, 'lspd_main' AS name, 'LSPD Hauptfunk' AS label UNION ALL
    SELECT 'ems', 2.10, 'ems_main', 'EMS Hauptfunk' UNION ALL
    SELECT 'government', 3.10, 'government_main', 'Government Hauptfunk' UNION ALL
    SELECT 'weazel', 4.10, 'weazel_main', 'Weazel Hauptfunk'
) AS seeded_channels
    ON seeded_channels.faction_name = factions.name
ON DUPLICATE KEY UPDATE
    label = VALUES(label),
    faction_id = VALUES(faction_id),
    is_active = VALUES(is_active),
    metadata = VALUES(metadata);

INSERT INTO radio_access (radio_channel_id, faction_id, min_grade_level, access_type, created_at)
SELECT radio_channels.id, factions.id, 0, 'listen', NOW()
FROM radio_channels
JOIN factions ON factions.id = radio_channels.faction_id
WHERE radio_channels.name IN ('lspd_main', 'ems_main', 'government_main', 'weazel_main')
    AND NOT EXISTS (
        SELECT 1
        FROM radio_access
        WHERE radio_channel_id = radio_channels.id
            AND faction_id = factions.id
            AND access_type = 'listen'
            AND min_grade_level = 0
    );

INSERT INTO accounts (account_number, owner_type, owner_id, account_type, balance, currency, is_frozen, created_at, updated_at)
SELECT seeded_accounts.account_number, 'faction', factions.id, 'faction', 0, 'USD', FALSE, NOW(), NOW()
FROM factions
JOIN (
    SELECT 'lspd' AS faction_name, 'FACLSPD0001' AS account_number UNION ALL
    SELECT 'ems', 'FACEMS0001' UNION ALL
    SELECT 'government', 'FACGOV0001' UNION ALL
    SELECT 'weazel', 'FACWEAZ0001'
) AS seeded_accounts
    ON seeded_accounts.faction_name = factions.name
WHERE NOT EXISTS (
    SELECT 1
    FROM accounts
    WHERE owner_type = 'faction'
        AND owner_id = factions.id
        AND account_type = 'faction'
)
ON DUPLICATE KEY UPDATE
    updated_at = VALUES(updated_at);
