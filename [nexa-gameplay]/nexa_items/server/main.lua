local migrated = false

ItemTypes = { entries = {} }
Items = { cache = {}, ready = false, version = 0 }
Metadata = {}
Stacking = {}
Durability = {}
Expiration = {}
ItemActions = { handlers = {}, cooldowns = {} }
Assets = {}

local function response(success, code, message, data, meta)
    return {
        ok = success == true,
        success = success == true,
        code = code or (success and 'OK' or NEXA_ITEMS_ERRORS.invalidInput),
        message = message or '',
        data = data,
        meta = meta,
        error = success == true and nil or {
            code = code,
            message = message
        }
    }
end

local function ok(data, message, meta)
    return response(true, 'OK', message or 'OK', data, meta)
end

local function fail(code, message, meta)
    return response(false, code, message or code, nil, meta)
end

local function encode(value)
    local encodedOk, encoded = pcall(json.encode, value or {})
    return encodedOk and encoded or '{}'
end

local function decode(value, fallback)
    if type(value) ~= 'string' or value == '' then
        return fallback
    end

    local decodedOk, decoded = pcall(json.decode, value)
    return decodedOk and decoded or fallback
end

local function getCore()
    if GetResourceState('nexa-core') ~= 'started' then
        return nil
    end

    local coreOk, core = pcall(function()
        return exports['nexa-core']:GetCoreObject()
    end)

    return coreOk and core or nil
end

local function log(level, category, message, context)
    local core = getCore()

    if core and core.Logger and core.Logger[level] then
        core.Logger[level](category, message, context)
        return
    end

    print(('[%s] [%s] %s %s'):format(NEXA_ITEMS.resourceName, level, message, encode(context)))
end

local function normalizeId(value)
    local id = tonumber(value)
    return id and id > 0 and id % 1 == 0 and math.floor(id) or nil
end

local function normalizeString(value, maxLength)
    if type(value) ~= 'string' then
        return nil
    end

    local normalized = value:gsub('^%s+', ''):gsub('%s+$', '')

    if normalized == '' or (maxLength and #normalized > maxLength) then
        return nil
    end

    return normalized
end

local function normalizeName(value)
    value = normalizeString(value, NexaItemsConfig.maxNameLength)

    if not value then
        return nil
    end

    value = value:lower()

    if value:find('^[a-z0-9_]+$') == nil or value:find('^_') or value:find('_$') or value:find('__', 1, true) then
        return nil
    end

    if NexaItemsConfig.reservedNames[value] then
        return nil
    end

    return value
end

local function normalizeType(value)
    value = normalizeString(value, 32)
    return value and value:lower() or nil
end

local function normalizeBool(value, defaultValue)
    if value == nil then
        return defaultValue
    end

    return value == true or tonumber(value) == 1
end

local function normalizeRow(row)
    if type(row) ~= 'table' then
        return row
    end

    row.id = normalizeId(row.id)
    row.weight = tonumber(row.weight) or 0
    row.max_stack = tonumber(row.max_stack) or 1
    row.version = tonumber(row.version) or 1

    for _, field in ipairs({ 'stackable', 'usable', 'quickslot_allowed', 'droppable', 'tradeable', 'destroyable', 'container_allowed' }) do
        row[field] = row[field] == true or tonumber(row[field]) == 1
    end

    row.metadata_schema = decode(row.metadata_schema, {})
    row.default_metadata = decode(row.default_metadata, {})
    row.durability_config = decode(row.durability_config, nil)
    row.expiration_config = decode(row.expiration_config, nil)
    row.image_url = row.image_reference
    row.enabled = row.status == NEXA_ITEM_STATUS.published
    return row
end

local function correlationId()
    return ('item:%s:%s:%s'):format(os.time(), GetGameTimer and GetGameTimer() or 0, math.random(100000, 999999))
end

local function contextOf(context, action)
    context = type(context) == 'table' and context or {}
    return {
        actor_account_id = normalizeId(context.actor_account_id),
        reason = normalizeString(context.reason, 128),
        correlation_id = normalizeString(context.correlation_id, 96) or correlationId(),
        source_resource = normalizeString(context.source_resource or GetInvokingResource() or NEXA_ITEMS.resourceName, 64),
        action = action
    }
end

local function requireReason(context)
    if NexaItemsConfig.requireReasonForMutations and not context.reason then
        return fail(NEXA_ITEMS_ERRORS.reasonRequired, 'Reason is required.')
    end

    return nil
end

local function audit(action, context, result, payload)
    context = contextOf(context, action)
    payload = payload or {}
    NexaItemsDatabase.InsertAudit({
        action = action,
        actor_account_id = context.actor_account_id,
        item_name = payload.item_name,
        old_version = payload.old_version,
        new_version = payload.new_version,
        before_state = payload.before_state and encode(payload.before_state) or nil,
        after_state = payload.after_state and encode(payload.after_state) or nil,
        reason = context.reason,
        result = result.ok and 'success' or 'failed',
        error_code = result.ok and nil or result.code,
        correlation_id = context.correlation_id,
        source_resource = context.source_resource
    })
end

function ItemTypes.Register(definition)
    if type(definition) ~= 'table' then
        return fail(NEXA_ITEMS_ERRORS.typeInvalid, 'Item type definition is invalid.')
    end

    local name = normalizeType(definition.name)

    if not name then
        return fail(NEXA_ITEMS_ERRORS.typeInvalid, 'Item type name is invalid.')
    end

    ItemTypes.entries[name] = {
        name = name,
        description = definition.description or name,
        defaults = definition.defaults or {},
        metadata_schema = definition.metadata_schema or {},
        actions = definition.actions or {},
        stackable = definition.stackable,
        usable = definition.usable,
        quickslot_allowed = definition.quickslot_allowed,
        container_allowed = definition.container_allowed
    }
    return ok(ItemTypes.entries[name], 'Item type registered.')
end

function ItemTypes.Get(name)
    return ItemTypes.entries[normalizeType(name)]
end

function ItemTypes.List()
    local list = {}

    for _, entry in pairs(ItemTypes.entries) do
        list[#list + 1] = entry
    end

    table.sort(list, function(left, right)
        return left.name < right.name
    end)
    return list
end

function ItemTypes.IsRegistered(name)
    return ItemTypes.Get(name) ~= nil
end

function ItemTypes.Validate(name)
    if not ItemTypes.IsRegistered(name) then
        return fail(NEXA_ITEMS_ERRORS.typeInvalid, 'Item type is not registered.', {
            item_type = name
        })
    end

    return ok(true)
end

local function registerDefaultTypes()
    local defaults = {
        generic = { stackable = true },
        food = { stackable = true, usable = true, quickslot_allowed = true },
        drink = { stackable = true, usable = true, quickslot_allowed = true },
        medical = { stackable = true, usable = true, quickslot_allowed = true },
        weapon = { stackable = false, usable = true, quickslot_allowed = true },
        ammunition = { stackable = true },
        document = { stackable = false },
        key = { stackable = false },
        container = { stackable = false, usable = true, container_allowed = true },
        currency = { stackable = true },
        material = { stackable = true },
        tool = { stackable = false, usable = true },
        radio = { stackable = false, usable = true, quickslot_allowed = true },
        consumable = { stackable = true, usable = true, quickslot_allowed = true }
    }

    for name, flags in pairs(defaults) do
        flags.name = name
        flags.description = name
        ItemTypes.Register(flags)
    end
end

local function metadataDepth(value, depth, seen)
    if type(value) ~= 'table' then
        return depth
    end

    if seen[value] then
        return 999
    end

    seen[value] = true
    local maxDepth = depth

    for key, child in pairs(value) do
        local keyType = type(key)
        local childType = type(child)

        if keyType == 'function' or keyType == 'thread' or keyType == 'userdata' or childType == 'function' or childType == 'thread' or childType == 'userdata' then
            return 999
        end

        maxDepth = math.max(maxDepth, metadataDepth(child, depth + 1, seen))
    end

    seen[value] = nil
    return maxDepth
end

function Metadata.ApplyDefaults(itemName, metadata)
    local definition = Items.Get(itemName, { includeDraft = true })
    definition = definition and definition.data or nil
    local result = {}

    for key, value in pairs(definition and definition.default_metadata or {}) do
        result[key] = value
    end

    for key, value in pairs(metadata or {}) do
        result[key] = value
    end

    return result
end

function Metadata.Validate(itemName, metadata)
    if metadata == nil then
        metadata = {}
    end

    if type(metadata) ~= 'table' then
        return fail(NEXA_ITEMS_ERRORS.metadataInvalid, 'Metadata must be a table.')
    end

    if metadataDepth(metadata, 1, {}) > NexaItemsConfig.maxMetadataDepth or #encode(metadata) > NexaItemsConfig.maxMetadataBytes then
        return fail(NEXA_ITEMS_ERRORS.metadataInvalid, 'Metadata is invalid.')
    end

    local definition = Items.Get(itemName, { includeDraft = true })
    definition = definition and definition.data or nil
    local schema = definition and definition.metadata_schema or {}

    for field, rule in pairs(schema) do
        if rule.required and metadata[field] == nil then
            return fail(NEXA_ITEMS_ERRORS.metadataInvalid, 'Required metadata is missing.', { field = field })
        end

        local value = metadata[field]

        if value ~= nil and rule.type then
            local valueType = type(value)

            if rule.type == 'integer' and (tonumber(value) == nil or tonumber(value) % 1 ~= 0) then
                return fail(NEXA_ITEMS_ERRORS.metadataInvalid, 'Metadata integer invalid.', { field = field })
            elseif rule.type == 'number' and tonumber(value) == nil then
                return fail(NEXA_ITEMS_ERRORS.metadataInvalid, 'Metadata number invalid.', { field = field })
            elseif rule.type == 'string' and valueType ~= 'string' then
                return fail(NEXA_ITEMS_ERRORS.metadataInvalid, 'Metadata string invalid.', { field = field })
            elseif rule.type == 'boolean' and valueType ~= 'boolean' then
                return fail(NEXA_ITEMS_ERRORS.metadataInvalid, 'Metadata boolean invalid.', { field = field })
            end
        end
    end

    return ok(Metadata.ApplyDefaults(itemName, metadata), 'Metadata valid.')
end

function Metadata.FilterForClient(itemName, metadata)
    local definition = Items.Get(itemName, { includeDraft = true })
    definition = definition and definition.data or nil
    local schema = definition and definition.metadata_schema or {}
    local filtered = {}

    for key, value in pairs(metadata or {}) do
        local rule = schema[key] or {}

        if rule.serverOnly ~= true and rule.sensitive ~= true and rule.clientVisible ~= false then
            filtered[key] = value
        end
    end

    return filtered
end

function Stacking.GetCompatibilityKey(definition, metadata)
    local relevant = {}
    local schema = definition.metadata_schema or {}

    for key, value in pairs(metadata or {}) do
        local rule = schema[key] or {}

        if rule.stackRelevant ~= false and rule.serverOnly ~= true and rule.sensitive ~= true then
            relevant[key] = value
        end
    end

    return definition.name .. ':' .. encode(relevant)
end

function Stacking.GetMaxStack(definition)
    return tonumber(definition.max_stack) or 1
end

function Stacking.CanStack(definition, first, second)
    if not definition or definition.stackable ~= true then
        return false
    end

    if definition.item_type == 'weapon' or definition.item_type == 'document' or definition.item_type == 'key' or definition.item_type == 'container' then
        return false
    end

    return Stacking.GetCompatibilityKey(definition, first or {}) == Stacking.GetCompatibilityKey(definition, second or {})
end

function Durability.CanUse(instance)
    local value = tonumber(instance and instance.durability)
    return value == nil or value > 0
end

function Durability.ApplyLoss(instance, amount)
    amount = tonumber(amount) or 0
    local value = tonumber(instance and instance.durability)

    if value == nil then
        return instance
    end

    instance.durability = math.max(0, value - amount)
    return instance
end

function Durability.Set(instance, value)
    value = tonumber(value)

    if not value or value < 0 then
        return fail(NEXA_ITEMS_ERRORS.durabilityInvalid, 'Durability is invalid.')
    end

    instance.durability = value
    return ok(instance)
end

function Expiration.IsExpired(instance, now)
    now = now or os.time()
    local expiresAt = tonumber(instance and instance.expires_at)
    return expiresAt ~= nil and expiresAt <= now
end

function Expiration.GetRemaining(instance, now)
    now = now or os.time()
    local expiresAt = tonumber(instance and instance.expires_at)
    return expiresAt and math.max(0, expiresAt - now) or nil
end

function Expiration.Resolve(definition, metadata, createdAt)
    local config = definition and definition.expiration_config

    if type(config) ~= 'table' or not config.mode or config.mode == 'none' then
        return nil
    end

    if config.mode == 'after_create' then
        return (createdAt or os.time()) + (tonumber(config.seconds) or 0)
    end

    if config.mode == 'fixed' then
        return tonumber(config.timestamp)
    end

    return nil
end

function ItemActions.RegisterHandler(name, definition)
    name = normalizeName(name)

    if not name or type(definition) ~= 'table' or type(definition.Execute) ~= 'function' then
        return fail(NEXA_ITEMS_ERRORS.actionInvalid, 'Handler definition is invalid.')
    end

    ItemActions.handlers[name] = definition
    return ok(true, 'Handler registered.')
end

function ItemActions.UnregisterHandler(name)
    ItemActions.handlers[normalizeName(name)] = nil
    return ok(true)
end

function ItemActions.IsRegistered(name)
    return ItemActions.handlers[normalizeName(name)] ~= nil
end

function ItemActions.Execute(actorSource, itemReference, actionName, context)
    local handler = ItemActions.handlers[normalizeName(actionName)]

    if not handler then
        return fail(NEXA_ITEMS_ERRORS.handlerNotFound, 'Item action handler is not registered.')
    end

    local executedOk, result = pcall(handler.Execute, actorSource, itemReference, context or {})

    if not executedOk then
        return fail(NEXA_ITEMS_ERRORS.actionInvalid, 'Item action failed.')
    end

    return result or ok(true)
end

function Assets.ValidateReference(reference)
    if reference == nil or reference == '' then
        return ok(nil)
    end

    if type(reference) ~= 'string' then
        return fail(NEXA_ITEMS_ERRORS.assetInvalid, 'Asset reference is invalid.')
    end

    local lower = reference:lower()

    if lower:find('^https://') then
        local host = lower:match('^https://([^/:]+)')

        if not host or host == 'localhost' or host == '127.0.0.1' or host:match('^10%.') or host:match('^192%.168%.') or host:match('^172%.1[6-9]%.') or host:match('^172%.2[0-9]%.') or host:match('^172%.3[0-1]%.') then
            return fail(NEXA_ITEMS_ERRORS.assetSsrfRejected, 'Asset host is not allowed.')
        end

        return ok(reference)
    end

    if lower:find('^nui://') or lower:find('^web/') then
        return ok(reference)
    end

    if lower:find('^http://') or lower:find('^file://') or lower:find('^javascript:') or lower:find('^data:') then
        return fail(NEXA_ITEMS_ERRORS.assetInvalid, 'Asset scheme is not allowed.')
    end

    return fail(NEXA_ITEMS_ERRORS.assetInvalid, 'Asset reference is invalid.')
end

function Assets.Resolve(itemName)
    local definition = Items.Get(itemName)
    return definition.ok and definition.data.image_reference or nil
end

local function validateDefinition(payload, partial)
    if type(payload) ~= 'table' then
        return nil, fail(NEXA_ITEMS_ERRORS.invalidInput, 'Definition payload is invalid.')
    end

    local name = payload.name and normalizeName(payload.name)
    local label = payload.label and normalizeString(payload.label, NexaItemsConfig.maxLabelLength)
    local itemType = normalizeType(payload.item_type or payload.type)

    if not partial and not name then
        return nil, fail(NEXA_ITEMS_ERRORS.nameInvalid, 'Item name is invalid.')
    end

    if name == nil and payload.name ~= nil then
        return nil, fail(NEXA_ITEMS_ERRORS.nameInvalid, 'Item name is invalid.')
    end

    if not partial and not label then
        return nil, fail(NEXA_ITEMS_ERRORS.labelInvalid, 'Item label is invalid.')
    end

    if label == nil and payload.label ~= nil then
        return nil, fail(NEXA_ITEMS_ERRORS.labelInvalid, 'Item label is invalid.')
    end

    if not partial and not itemType then
        return nil, fail(NEXA_ITEMS_ERRORS.typeInvalid, 'Item type is invalid.')
    end

    if itemType and not ItemTypes.IsRegistered(itemType) then
        return nil, fail(NEXA_ITEMS_ERRORS.typeInvalid, 'Item type is not registered.')
    end

    local weight = payload.weight

    if weight ~= nil then
        weight = tonumber(weight)

        if not weight or weight < 0 or weight % 1 ~= 0 then
            return nil, fail(NEXA_ITEMS_ERRORS.weightInvalid, 'Weight is invalid.')
        end
    end

    local stackable = normalizeBool(payload.stackable, nil)
    local maxStack = payload.max_stack or payload.maxStack

    if maxStack ~= nil then
        maxStack = tonumber(maxStack)

        if not maxStack or maxStack < 1 or maxStack % 1 ~= 0 then
            return nil, fail(NEXA_ITEMS_ERRORS.stackInvalid, 'Max stack is invalid.')
        end
    end

    if stackable == false then
        maxStack = 1
    end

    local metadataSchema = payload.metadata_schema or payload.metadataSchema or {}
    local defaultMetadata = payload.default_metadata or payload.defaultMetadata or payload.metadata or {}

    if type(metadataSchema) ~= 'table' or metadataDepth(metadataSchema, 1, {}) > NexaItemsConfig.maxMetadataDepth then
        return nil, fail(NEXA_ITEMS_ERRORS.metadataSchemaInvalid, 'Metadata schema is invalid.')
    end

    local asset = Assets.ValidateReference(payload.image_reference or payload.image or payload.image_url)

    if not asset.ok then
        return nil, asset
    end

    return {
        name = name,
        label = label,
        description = payload.description and normalizeString(payload.description, NexaItemsConfig.maxDescriptionLength) or nil,
        item_type = itemType,
        weight = weight,
        stackable = stackable,
        max_stack = maxStack,
        usable = normalizeBool(payload.usable, nil),
        quickslot_allowed = normalizeBool(payload.quickslot_allowed or payload.quickslotAllowed, nil),
        droppable = normalizeBool(payload.droppable, nil),
        tradeable = normalizeBool(payload.tradeable or payload.tradable, nil),
        destroyable = normalizeBool(payload.destroyable, nil),
        container_allowed = normalizeBool(payload.container_allowed or payload.containerAllowed, nil),
        metadata_schema = metadataSchema,
        default_metadata = defaultMetadata,
        durability_config = payload.durability_config or payload.durability,
        expiration_config = payload.expiration_config or payload.expiration,
        image_reference = asset.data,
        status = payload.status
    }, nil
end

function Items.Validate(definition)
    local normalized, invalid = validateDefinition(definition, false)

    if invalid then
        return invalid
    end

    return ok(normalized, 'Definition valid.')
end

local function applyDefaults(definition)
    local typeDefinition = ItemTypes.Get(definition.item_type) or { defaults = {} }
    local defaults = typeDefinition.defaults or {}

    definition.weight = definition.weight or defaults.weight or NexaItemsConfig.defaultWeight
    definition.stackable = definition.stackable

    if definition.stackable == nil then
        definition.stackable = typeDefinition.stackable
    end

    if definition.stackable == nil then
        definition.stackable = NexaItemsConfig.defaultStackable
    end

    definition.max_stack = definition.stackable and (definition.max_stack or defaults.max_stack or NexaItemsConfig.defaultMaxStack) or 1
    definition.usable = definition.usable

    if definition.usable == nil then
        definition.usable = typeDefinition.usable or NexaItemsConfig.defaultUsable
    end

    definition.quickslot_allowed = definition.quickslot_allowed

    if definition.quickslot_allowed == nil then
        definition.quickslot_allowed = typeDefinition.quickslot_allowed or NexaItemsConfig.defaultQuickslotAllowed
    end

    definition.droppable = definition.droppable

    if definition.droppable == nil then
        definition.droppable = NexaItemsConfig.defaultDroppable
    end

    definition.tradeable = definition.tradeable

    if definition.tradeable == nil then
        definition.tradeable = NexaItemsConfig.defaultTradeable
    end

    definition.destroyable = definition.destroyable

    if definition.destroyable == nil then
        definition.destroyable = NexaItemsConfig.defaultDestroyable
    end

    definition.container_allowed = definition.container_allowed

    if definition.container_allowed == nil then
        definition.container_allowed = typeDefinition.container_allowed or NexaItemsConfig.defaultContainerAllowed
    end

    definition.status = definition.status or NEXA_ITEM_STATUS.draft
    definition.version = definition.version or 1
    return definition
end

function Items.Register(definition, context)
    context = contextOf(context, 'item_register')
    local reasonError = requireReason(context)

    if reasonError then
        return reasonError
    end

    local normalized, invalid = validateDefinition(definition, false)

    if invalid then
        audit('item_register', context, invalid, { item_name = definition and definition.name })
        return invalid
    end

    normalized = applyDefaults(normalized)
    local existing = NexaItemsDatabase.GetDefinitionByName(normalized.name)

    if existing then
        local result = fail(NEXA_ITEMS_ERRORS.alreadyExists, 'Item already exists.')
        audit('item_register', context, result, { item_name = normalized.name })
        return result
    end

    local id, err = NexaItemsDatabase.InsertDefinition({
        name = normalized.name,
        label = normalized.label,
        description = normalized.description,
        item_type = normalized.item_type,
        weight = normalized.weight,
        stackable = normalized.stackable,
        max_stack = normalized.max_stack,
        usable = normalized.usable,
        quickslot_allowed = normalized.quickslot_allowed,
        droppable = normalized.droppable,
        tradeable = normalized.tradeable,
        destroyable = normalized.destroyable,
        container_allowed = normalized.container_allowed,
        metadata_schema = encode(normalized.metadata_schema),
        default_metadata = encode(normalized.default_metadata),
        durability_config = encode(normalized.durability_config),
        expiration_config = encode(normalized.expiration_config),
        image_reference = normalized.image_reference,
        status = normalized.status,
        version = normalized.version,
        created_by = context.actor_account_id,
        updated_by = context.actor_account_id,
        published_at = normalized.status == NEXA_ITEM_STATUS.published and os.date('!%Y-%m-%d %H:%M:%S') or nil
    })

    if err then
        local result = fail(NEXA_ITEMS_ERRORS.databaseError, 'Definition could not be inserted.', err)
        audit('item_register', context, result, { item_name = normalized.name })
        return result
    end

    local row = NexaItemsDatabase.GetDefinitionById(id)
    row = normalizeRow(row)
    NexaItemsDatabase.InsertVersion({
        item_definition_id = row.id,
        version = row.version,
        snapshot = encode(row),
        change_reason = context.reason,
        created_by = context.actor_account_id
    })
    Items.cache[row.name] = row
    Items.version = Items.version + 1
    local result = ok(row, 'Definition registered.')
    audit('item_register', context, result, { item_name = row.name, new_version = row.version, after_state = row })
    return result
end

function Items.Get(name, options)
    name = normalizeName(name)

    if not name then
        return fail(NEXA_ITEMS_ERRORS.nameInvalid, 'Item name is invalid.')
    end

    local cached = Items.cache[name]

    if cached and (cached.status == NEXA_ITEM_STATUS.published or (options and options.includeDraft)) then
        return ok(cached, 'Definition loaded.')
    end

    local row, err = NexaItemsDatabase.GetDefinitionByName(name)

    if err then
        return fail(NEXA_ITEMS_ERRORS.databaseError, 'Definition lookup failed.', err)
    end

    if not row then
        return fail(NEXA_ITEMS_ERRORS.definitionNotFound, 'Definition not found.')
    end

    row = normalizeRow(row)
    Items.cache[name] = row

    if row.status ~= NEXA_ITEM_STATUS.published and not (options and options.includeDraft) then
        return fail(NEXA_ITEMS_ERRORS.definitionNotFound, 'Definition is not published.')
    end

    return ok(row, 'Definition loaded.')
end

function Items.Exists(name)
    return Items.Get(name, { includeDraft = true }).ok == true
end

function Items.List(filters)
    filters = type(filters) == 'table' and filters or {}
    local rows, err = NexaItemsDatabase.ListDefinitions(filters)

    if err then
        return fail(NEXA_ITEMS_ERRORS.databaseError, 'Definitions could not be listed.', err)
    end

    for _, row in ipairs(rows or {}) do
        normalizeRow(row)
        Items.cache[row.name] = row
    end

    return ok(rows or {}, 'Definitions listed.', { count = #(rows or {}) })
end

function Items.Update(name, changes, context)
    context = contextOf(context, 'item_update')
    local reasonError = requireReason(context)

    if reasonError then
        return reasonError
    end

    local currentResponse = Items.Get(name, { includeDraft = true })

    if not currentResponse.ok then
        return currentResponse
    end

    local current = currentResponse.data
    local normalized, invalid = validateDefinition(changes, true)

    if invalid then
        return invalid
    end

    normalized.version = current.version + 1
    normalized.updated_by = context.actor_account_id
    normalized.metadata_schema = normalized.metadata_schema and encode(normalized.metadata_schema) or nil
    normalized.default_metadata = normalized.default_metadata and encode(normalized.default_metadata) or nil
    normalized.durability_config = normalized.durability_config and encode(normalized.durability_config) or nil
    normalized.expiration_config = normalized.expiration_config and encode(normalized.expiration_config) or nil

    local _, err = NexaItemsDatabase.UpdateDefinition(current.id, normalized)

    if err then
        return fail(NEXA_ITEMS_ERRORS.databaseError, 'Definition could not be updated.', err)
    end

    local updated = normalizeRow(NexaItemsDatabase.GetDefinitionById(current.id))
    NexaItemsDatabase.InsertVersion({
        item_definition_id = updated.id,
        version = updated.version,
        snapshot = encode(updated),
        change_reason = context.reason,
        created_by = context.actor_account_id
    })
    Items.cache[updated.name] = updated
    Items.version = Items.version + 1
    local result = ok(updated, 'Definition updated.')
    audit('item_update', context, result, { item_name = updated.name, old_version = current.version, new_version = updated.version, before_state = current, after_state = updated })
    return result
end

function Items.Publish(name, context)
    return Items.Update(name, { status = NEXA_ITEM_STATUS.published, published_at = os.date('!%Y-%m-%d %H:%M:%S') }, context)
end

function Items.Disable(name, context)
    return Items.Update(name, { status = NEXA_ITEM_STATUS.disabled }, context)
end

function Items.Deprecate(name, context)
    return Items.Update(name, { status = NEXA_ITEM_STATUS.deprecated }, context)
end

function Items.Delete(name, context)
    return Items.Update(name, { status = NEXA_ITEM_STATUS.deleted, deleted_at = os.date('!%Y-%m-%d %H:%M:%S') }, context)
end

function Items.Reload(name)
    Items.cache[normalizeName(name)] = nil
    return Items.Get(name, { includeDraft = true })
end

function Items.ReloadAll()
    Items.cache = {}
    return Items.List({})
end

function Items.GetVersion(name)
    local definition = Items.Get(name, { includeDraft = true })
    return definition.ok and definition.data.version or nil
end

function Items.ResolveDefaults(name, metadata)
    return Metadata.ApplyDefaults(name, metadata)
end

function Items.GetClientDefinition(name)
    local definition = Items.Get(name)

    if not definition.ok then
        return definition
    end

    local data = definition.data
    return ok({
        name = data.name,
        label = data.label,
        description = data.description,
        item_type = data.item_type,
        image_reference = data.image_reference,
        weight = data.weight,
        stackable = data.stackable,
        max_stack = data.max_stack,
        usable = data.usable,
        quickslot_allowed = data.quickslot_allowed,
        droppable = data.droppable,
        tradeable = data.tradeable,
        version = data.version,
        metadata_schema = Metadata.FilterForClient(data.name, data.metadata_schema or {})
    }, 'Client definition loaded.')
end

function Items.GetClientCatalog(filters)
    local listed = Items.List(filters or { status = NEXA_ITEM_STATUS.published })

    if not listed.ok then
        return listed
    end

    local catalog = {}

    for _, definition in ipairs(listed.data) do
        if definition.status == NEXA_ITEM_STATUS.published then
            catalog[#catalog + 1] = Items.GetClientDefinition(definition.name).data
        end
    end

    return ok(catalog, 'Client catalog loaded.', { version = Items.version })
end

local function registerCallbacks()
    if GetResourceState('nexa_api') ~= 'started' then
        return
    end

    exports.nexa_api:RegisterServerCallback(NEXA_ITEMS_CALLBACKS.createItem, function(source, payload)
        return Items.Register(payload, { source = source, reason = payload and payload.reason or 'studio_create' })
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_ITEMS_CALLBACKS.getItem, function(_, payload)
        local name = type(payload) == 'table' and (payload.name or payload.id) or payload
        return GetItem(name)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_ITEMS_CALLBACKS.listItems, function(_, payload)
        return ListItems(payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_ITEMS_CALLBACKS.updateItem, function(source, payload)
        if type(payload) ~= 'table' then
            return fail(NEXA_ITEMS_ERRORS.invalidInput, 'Payload invalid.')
        end

        return Items.Update(payload.name, payload, { source = source, reason = payload.reason or 'studio_update' })
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_ITEMS_CALLBACKS.setItemEnabled, function(source, payload)
        if type(payload) ~= 'table' then
            return fail(NEXA_ITEMS_ERRORS.invalidInput, 'Payload invalid.')
        end

        return SetItemEnabled(payload.name, payload.enabled, { source = source, reason = payload.reason or 'studio_enable' })
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_ITEMS_CALLBACKS.deleteItem, function(source, payload)
        local name = type(payload) == 'table' and payload.name or payload
        return Items.Delete(name, { source = source, reason = type(payload) == 'table' and payload.reason or 'studio_delete' })
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_ITEMS_CALLBACKS.publishItem, function(source, payload)
        return Items.Publish(payload and payload.name, { source = source, reason = payload and payload.reason or 'studio_publish' })
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_ITEMS_CALLBACKS.getClientCatalog, function(_, payload)
        return Items.GetClientCatalog(payload)
    end)
end

local function ensureBuiltInDefinitions()
    local builtins = {
        {
            name = 'water',
            label = 'Water',
            description = 'Basic water bottle.',
            item_type = 'drink',
            weight = 500,
            stackable = true,
            max_stack = 10,
            usable = true,
            quickslot_allowed = true,
            status = NEXA_ITEM_STATUS.published
        },
        {
            name = 'bread',
            label = 'Bread',
            description = 'Basic bread ration.',
            item_type = 'food',
            weight = 250,
            stackable = true,
            max_stack = 10,
            usable = true,
            quickslot_allowed = true,
            status = NEXA_ITEM_STATUS.published
        },
        {
            name = 'radio',
            label = 'Radio',
            description = 'Basic communication radio.',
            item_type = 'radio',
            weight = 750,
            stackable = false,
            max_stack = 1,
            usable = true,
            quickslot_allowed = true,
            status = NEXA_ITEM_STATUS.published
        }
    }

    for _, definition in ipairs(builtins) do
        if not Items.Exists(definition.name) then
            Items.Register(definition, {
                reason = 'bootstrap_builtin_definition',
                source_resource = NEXA_ITEMS.resourceName
            })
        end
    end
end

function CreateItem(payload)
    payload = type(payload) == 'table' and payload or {}
    payload.status = payload.status or NEXA_ITEM_STATUS.published
    return Items.Register(payload, { reason = payload.reason or 'legacy_create' })
end

function GetItem(idOrName)
    return Items.Get(idOrName)
end

function ListItems(filter)
    return Items.List(filter)
end

function UpdateItem(idOrName, payload)
    return Items.Update(idOrName, payload, { reason = payload and payload.reason or 'legacy_update' })
end

function SetItemEnabled(idOrName, enabled, context)
    if enabled == true then
        return Items.Publish(idOrName, context or { reason = 'legacy_enable' })
    end

    return Items.Disable(idOrName, context or { reason = 'legacy_disable' })
end

function DeleteItem(idOrName, context)
    return Items.Delete(idOrName, context or { reason = 'legacy_delete' })
end

function PublishItem(name, context)
    return Items.Publish(name, context)
end

function DeprecateItem(name, context)
    return Items.Deprecate(name, context)
end

function GetItemDefinition(name)
    return Items.Get(name)
end

function ItemExists(name)
    return Items.Exists(name)
end

function GetItemWeight(name)
    local definition = Items.Get(name)
    return definition.ok and definition.data.weight or nil
end

function GetMaxStack(name)
    local definition = Items.Get(name)
    return definition.ok and definition.data.max_stack or nil
end

function IsStackable(name)
    local definition = Items.Get(name)
    return definition.ok and definition.data.stackable == true or false
end

function ValidateMetadata(name, metadata)
    return Metadata.Validate(name, metadata)
end

function CanUse(name)
    local definition = Items.Get(name)
    return definition.ok and definition.data.usable == true or false
end

function CanQuickslot(name)
    local definition = Items.Get(name)
    return definition.ok and definition.data.quickslot_allowed == true or false
end

function CanDrop(name)
    local definition = Items.Get(name)
    return definition.ok and definition.data.droppable == true or false
end

function CanTrade(name)
    local definition = Items.Get(name)
    return definition.ok and definition.data.tradeable == true or false
end

function IsContainer(name)
    local definition = Items.Get(name)
    return definition.ok and definition.data.container_allowed == true or false
end

function GetClientDefinition(name)
    return Items.GetClientDefinition(name)
end

function GetClientCatalog(filters)
    return Items.GetClientCatalog(filters)
end

function RegisterItemType(definition)
    return ItemTypes.Register(definition)
end

function RegisterActionHandler(name, definition)
    return ItemActions.RegisterHandler(name, definition)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    registerDefaultTypes()

    if NexaItemsConfig.autoMigrate then
        local migrateOk, migrateErr = NexaItemsDatabase.Migrate()
        migrated = migrateOk == true

        if not migrated then
            log('Error', 'items.migration', 'Item registry migrations failed.', { error = migrateErr })
        end
    end

    ensureBuiltInDefinitions()
    Items.ReloadAll()
    Items.ready = true
    registerCallbacks()
    log('Info', 'items.start', 'nexa_items registry started.', { migrated = migrated })
end)

exports('CreateItem', CreateItem)
exports('GetItem', GetItem)
exports('ListItems', ListItems)
exports('UpdateItem', UpdateItem)
exports('SetItemEnabled', SetItemEnabled)
exports('DeleteItem', DeleteItem)
exports('PublishItem', PublishItem)
exports('DeprecateItem', DeprecateItem)
exports('GetItemDefinition', GetItemDefinition)
exports('ItemExists', ItemExists)
exports('GetItemWeight', GetItemWeight)
exports('GetMaxStack', GetMaxStack)
exports('IsStackable', IsStackable)
exports('ValidateMetadata', ValidateMetadata)
exports('CanUse', CanUse)
exports('CanQuickslot', CanQuickslot)
exports('CanDrop', CanDrop)
exports('CanTrade', CanTrade)
exports('IsContainer', IsContainer)
exports('GetClientDefinition', GetClientDefinition)
exports('GetClientCatalog', GetClientCatalog)
exports('RegisterItemType', RegisterItemType)
exports('RegisterActionHandler', RegisterActionHandler)
exports('getStatus', function()
    return { resourceName = NEXA_ITEMS.resourceName, version = NEXA_ITEMS.version, ready = Items.ready, migrated = migrated, cacheVersion = Items.version }
end)
exports('getSchema', NexaItemsDatabase.GetSchema)
exports('isSupportedItemType', function(itemType)
    return ItemTypes.IsRegistered(itemType)
end)
