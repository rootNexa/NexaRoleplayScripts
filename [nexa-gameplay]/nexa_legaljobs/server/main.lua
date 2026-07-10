local registered = false
local definitions = {}

local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function getCore() if GetResourceState('nexa-core') ~= 'started' then return nil end; local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return good and core or nil end
local function log(level, category, message, context) local core = getCore(); if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s %s'):format(NEXA_LEGALJOBS.resourceName, level, message, encode(context))) end
local function emit(eventName, payload) local core = getCore(); if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_LEGALJOBS.resourceName }) end end

local function phase(key, label, taskType, taskKey, target, amount)
    return {
        phase_key = key,
        label = label,
        phase_type = 'standard',
        completion_policy = { all_tasks_required = true },
        timeout_seconds = NexaLegalJobsConfig.defaultDurationSeconds,
        tasks = {
            {
                task_key = taskKey,
                task_type = taskType,
                amount_required = amount or 1,
                target_definition = target or {},
                progress_policy = { model = amount and 'quantity' or 'boolean' },
                validation_policy = { server_authoritative = true },
                reward_fragment = {}
            }
        }
    }
end

local function buildDefinitions()
    definitions = {
        {
            job_key = NEXA_LEGAL_JOB_KEYS.mining,
            label = 'Mining',
            description = 'Mine ore from server-controlled resource nodes and deliver it for processing.',
            job_type = 'gathering',
            status = 'active',
            group_allowed = true,
            minimum_group_size = 1,
            maximum_group_size = 4,
            cooldown_seconds = NexaLegalJobsConfig.defaultCooldownSeconds,
            reward_policy = { type = 'mixed', economy = { currency = 'bank', amount = 250 }, inventory = { item_name = 'stone', amount = 3 }, idempotent = true },
            phases = {
                phase('travel_to_mine', 'Travel to mine', 'go_to', 'reach_mine', { checkpoint_key = 'mine_entry', radius = 8 }),
                phase('mine_ore', 'Mine ore', 'collect_item', 'collect_ore', { resource_node_type = 'node', item_name = 'stone', tool = 'pickaxe' }, 3),
                phase('deliver_ore', 'Deliver ore', 'deliver_item', 'deliver_ore', { item_name = 'stone', amount = 3 })
            },
            metadata = { category = 'legal', anti_afk = true }
        },
        {
            job_key = NEXA_LEGAL_JOB_KEYS.farming,
            label = 'Farming',
            description = 'Harvest crops from controlled fields and deliver produce.',
            job_type = 'gathering',
            status = 'active',
            group_allowed = true,
            reward_policy = { type = 'mixed', economy = { currency = 'bank', amount = 180 }, inventory = { item_name = 'wheat', amount = 5 }, idempotent = true },
            phases = {
                phase('travel_to_field', 'Travel to field', 'go_to', 'reach_field', { checkpoint_key = 'farm_field', radius = 12 }),
                phase('harvest_crops', 'Harvest crops', 'collect_item', 'collect_wheat', { resource_node_type = 'field', item_name = 'wheat' }, 5),
                phase('deliver_crops', 'Deliver crops', 'deliver_item', 'deliver_wheat', { item_name = 'wheat', amount = 5 })
            },
            metadata = { category = 'legal', anti_afk = true }
        },
        {
            job_key = NEXA_LEGAL_JOB_KEYS.fishing,
            label = 'Fishing',
            description = 'Fish in validated water zones with tool checks and server-side harvest limits.',
            job_type = 'gathering',
            status = 'active',
            group_allowed = false,
            reward_policy = { type = 'mixed', economy = { currency = 'bank', amount = 160 }, inventory = { item_name = 'fish', amount = 3 }, idempotent = true },
            phases = {
                phase('reach_water', 'Reach fishing zone', 'go_to', 'reach_fishing_zone', { checkpoint_key = 'fishing_water', radius = 20 }),
                phase('catch_fish', 'Catch fish', 'collect_item', 'catch_fish', { resource_node_type = 'water_zone', item_name = 'fish', tool = 'fishing_rod' }, 3)
            },
            metadata = { category = 'legal', anti_afk = true }
        },
        {
            job_key = NEXA_LEGAL_JOB_KEYS.delivery,
            label = 'Delivery',
            description = 'Pick up packages and deliver them through validated checkpoints.',
            job_type = 'delivery',
            status = 'active',
            group_allowed = false,
            reward_policy = { type = 'economy', currency = 'bank', amount = 220, idempotent = true },
            phases = {
                phase('pickup_package', 'Pick up package', 'collect_item', 'pickup_package', { item_name = 'delivery_package' }, 1),
                phase('deliver_package', 'Deliver package', 'deliver_item', 'deliver_package', { item_name = 'delivery_package', route_required = true })
            },
            metadata = { vehicle_service = 'optional' }
        },
        {
            job_key = NEXA_LEGAL_JOB_KEYS.trucking,
            label = 'Trucking',
            description = 'Transport cargo with server-authoritative vehicle and cargo validation.',
            job_type = 'transport',
            status = 'active',
            group_allowed = true,
            maximum_group_size = 2,
            reward_policy = { type = 'economy', currency = 'bank', amount = 650, idempotent = true },
            phases = {
                phase('load_cargo', 'Load cargo', 'load_vehicle', 'load_truck', { vehicle_class = 'truck', cargo_key = 'standard_cargo' }),
                phase('drive_route', 'Drive route', 'drive_route', 'complete_route', { checkpoint_sequence = true }),
                phase('unload_cargo', 'Unload cargo', 'unload_vehicle', 'unload_truck', { cargo_key = 'standard_cargo' })
            },
            metadata = { requires_vehicle_service = true }
        },
        {
            job_key = NEXA_LEGAL_JOB_KEYS.taxi,
            label = 'Taxi',
            description = 'Transport passengers through validated route checkpoints.',
            job_type = 'service',
            status = 'active',
            group_allowed = false,
            reward_policy = { type = 'economy', currency = 'bank', amount = 300, idempotent = true },
            phases = {
                phase('pickup_passenger', 'Pick up passenger', 'go_to', 'reach_passenger', { passenger_anchor = true, radius = 8 }),
                phase('transport_passenger', 'Transport passenger', 'transport_passenger', 'drive_passenger', { checkpoint_sequence = true })
            },
            metadata = { npc_foundation = true }
        },
        {
            job_key = NEXA_LEGAL_JOB_KEYS.garbage,
            label = 'Garbage',
            description = 'Collect waste on a server-defined route and deliver it to disposal.',
            job_type = 'route',
            status = 'active',
            group_allowed = true,
            maximum_group_size = 4,
            reward_policy = { type = 'economy', currency = 'bank', amount = 360, idempotent = true },
            phases = {
                phase('drive_collection_route', 'Drive collection route', 'drive_route', 'garbage_route', { checkpoint_sequence = true }),
                phase('collect_bins', 'Collect bins', 'interact', 'collect_bins', { interaction_type = 'garbage_bin' }, 4),
                phase('dispose_waste', 'Dispose waste', 'deliver_item', 'dispose_waste', { item_name = 'waste_bag' })
            },
            metadata = { anti_afk = true }
        },
        {
            job_key = NEXA_LEGAL_JOB_KEYS.mechanic,
            label = 'Mechanic Service',
            description = 'Basic service calls for inspecting and repairing vehicles without tuning logic.',
            job_type = 'service',
            status = 'active',
            group_allowed = false,
            reward_policy = { type = 'economy', currency = 'bank', amount = 280, idempotent = true },
            phases = {
                phase('inspect_vehicle', 'Inspect vehicle', 'inspect_vehicle', 'inspect_customer_vehicle', { vehicle_required = true }),
                phase('repair_vehicle', 'Repair vehicle', 'repair_vehicle', 'repair_customer_vehicle', { tool = 'repair_kit', vehicle_required = true })
            },
            metadata = { tuning = false }
        },
        {
            job_key = NEXA_LEGAL_JOB_KEYS.courier,
            label = 'Courier',
            description = 'Short-distance document and parcel delivery foundation.',
            job_type = 'delivery',
            status = 'active',
            group_allowed = false,
            reward_policy = { type = 'economy', currency = 'bank', amount = 190, idempotent = true },
            phases = {
                phase('collect_courier_item', 'Collect item', 'collect_item', 'collect_courier_item', { item_name = 'courier_parcel' }, 1),
                phase('deliver_courier_item', 'Deliver item', 'deliver_item', 'deliver_courier_item', { item_name = 'courier_parcel' })
            },
            metadata = { small_vehicle = true }
        },
        {
            job_key = NEXA_LEGAL_JOB_KEYS.logistics,
            label = 'Warehouse Logistics',
            description = 'Warehouse picking, packing and loading foundation.',
            job_type = 'production',
            status = 'active',
            group_allowed = true,
            maximum_group_size = 4,
            reward_policy = { type = 'economy', currency = 'bank', amount = 320, idempotent = true },
            phases = {
                phase('pick_items', 'Pick items', 'collect_item', 'warehouse_pick', { item_name = 'logistics_box' }, 3),
                phase('pack_items', 'Pack items', 'process_item', 'warehouse_pack', { station_type = 'packing' }),
                phase('load_items', 'Load items', 'load_vehicle', 'warehouse_load', { cargo_key = 'warehouse_cargo' })
            },
            metadata = { production_chain = true }
        }
    }
end

function RegisterLegalJobDefinitions()
    buildDefinitions()
    if GetResourceState('nexa_jobframework') ~= 'started' then
        registered = false
        return false
    end

    for _, definition in ipairs(definitions) do
        if NexaLegalJobsConfig.createDefinitionsInDatabase then
            pcall(function()
                exports['nexa_jobframework']:CreateJobDefinition(definition, {
                    source_resource = NEXA_LEGALJOBS.resourceName,
                    reason = 'legaljobs.bootstrap'
                })
            end)
        end
    end

    registered = true
    emit(NEXA_LEGAL_JOB_EVENTS.registered, { count = #definitions })
    return true
end

function GetLegalJobDefinitions()
    if #definitions == 0 then buildDefinitions() end
    return definitions
end

function GetLegalJobDefinition(key)
    if #definitions == 0 then buildDefinitions() end
    for _, definition in ipairs(definitions) do
        if definition.job_key == key then return definition end
    end
    return nil
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    buildDefinitions()
    if NexaLegalJobsConfig.autoRegister then RegisterLegalJobDefinitions() end
    log('Info', 'legaljobs.start', 'nexa_legaljobs started.', { registered = registered, definitions = #definitions })
end)

exports('RegisterLegalJobDefinitions', RegisterLegalJobDefinitions)
exports('GetLegalJobDefinitions', GetLegalJobDefinitions)
exports('GetLegalJobDefinition', GetLegalJobDefinition)
exports('getStatus', function() return { resourceName = NEXA_LEGALJOBS.resourceName, version = NEXA_LEGALJOBS.version, registered = registered, definitions = #definitions } end)
