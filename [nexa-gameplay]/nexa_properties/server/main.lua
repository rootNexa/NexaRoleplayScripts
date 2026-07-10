local migrated = false
local PropertyTypes = {}
local TypeRegistry = {}

PropertyDefinitions = {}
Properties = {}
PropertyOwnership = {}
PropertySales = {}
Leases = {}
Rent = {}
Residents = {}
PropertyStorage = {}
PropertyWardrobes = {}
PropertyGarages = {}
Furniture = {}
PropertyAdmin = {}
PropertyCreator = {}

local function response(success, code, message, data, meta)
    return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_PROPERTY_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } }
end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function decode(value) if type(value) ~= 'string' or value == '' then return {} end; local good, decoded = pcall(json.decode, value); return good and type(decoded) == 'table' and decoded or {} end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeAmount(value) value = tonumber(value); return value and value >= 0 and value % 1 == 0 and math.floor(value) or nil end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local s = value:gsub('^%s+', ''):gsub('%s+$', ''); if s == '' or (maxLength and #s > maxLength) then return nil end; return s end

local function getCore()
    if GetResourceState('nexa-core') ~= 'started' then return nil end
    local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end)
    return good and core or nil
end

local function log(level, category, message, context)
    local core = getCore()
    if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end
    print(('[%s] [%s] %s %s'):format(NEXA_PROPERTIES.resourceName, level, message, encode(context)))
end

local function emit(eventName, payload)
    local core = getCore()
    if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_PROPERTIES.resourceName }) end
end

local function actorContext(actor, action)
    actor = type(actor) == 'table' and actor or {}
    return { action = action, source = normalizeId(actor.source), actor_account_id = normalizeId(actor.actor_account_id), actor_character_id = normalizeId(actor.actor_character_id or actor.character_id), reason = normalizeString(actor.reason, 255), source_resource = normalizeString(actor.source_resource or GetInvokingResource() or NEXA_PROPERTIES.resourceName, 64), correlation_id = normalizeString(actor.correlation_id, 128) or ('property:%s:%s:%s'):format(action, os.time(), math.random(100000, 999999)) }
end

local function audit(action, context, result, payload)
    payload = payload or {}
    NexaPropertiesDatabase.InsertAudit({ property_id = payload.property_id, action = action, actor_account_id = context.actor_account_id, actor_character_id = context.actor_character_id, target_character_id = payload.target_character_id, before_state = payload.before_state, after_state = payload.after_state, reason = context.reason, result = result.ok and 'success' or 'failed', error_code = result.ok and nil or result.code, source_resource = context.source_resource, correlation_id = context.correlation_id, metadata = payload.metadata })
end

local function hydrateDefinition(row)
    if not row then return nil end
    row.entrance = decode(row.entrance)
    row.exterior = decode(row.exterior)
    row.storage_configuration = decode(row.storage_configuration)
    row.security_configuration = decode(row.security_configuration)
    row.settings = decode(row.settings)
    row.metadata = decode(row.metadata)
    return row
end

local function hydrateProperty(row)
    return row
end

local function typeDefinition(name, label, rentable, purchasable, options)
    options = options or {}
    return { name = name, label = label, description = options.description or label, rentable = rentable, purchasable = purchasable, allow_residents = options.allow_residents ~= false, allow_storage = options.allow_storage ~= false, allow_garage = options.allow_garage == true, allow_wardrobe = options.allow_wardrobe ~= false, allow_furniture = options.allow_furniture ~= false, allow_alarm = options.allow_alarm ~= false, allow_burglary = options.allow_burglary ~= false, interior_type = options.interior_type or 'routing_instance', max_residents = options.max_residents or NexaPropertiesConfig.maxResidents, max_keys = options.max_keys or NexaPropertiesConfig.maxKeys, max_storages = options.max_storages or 1, max_garages = options.max_garages or 0, status = 'active', metadata = options.metadata or {} }
end

function PropertyTypes.Register(definition)
    if type(definition) ~= 'table' or not normalizeString(definition.name, 64) then return false, 'INVALID_TYPE' end
    TypeRegistry[definition.name] = definition
    return true
end
function PropertyTypes.Get(name) return TypeRegistry[name] end
function PropertyTypes.List() local list = {}; for _, definition in pairs(TypeRegistry) do list[#list + 1] = definition end; return list end
function PropertyTypes.IsRegistered(name) return TypeRegistry[name] ~= nil end
function PropertyTypes.Validate(name) return PropertyTypes.IsRegistered(name) end

local function registerDefaultTypes()
    PropertyTypes.Register(typeDefinition('rental_apartment', 'Rental Apartment', true, false))
    PropertyTypes.Register(typeDefinition('owned_apartment', 'Owned Apartment', false, true))
    PropertyTypes.Register(typeDefinition('house', 'House', false, true, { allow_garage = true, max_garages = 1 }))
    PropertyTypes.Register(typeDefinition('villa', 'Villa', false, true, { allow_garage = true, max_residents = 12, max_garages = 3 }))
    PropertyTypes.Register(typeDefinition('business_building', 'Business Building', true, true, { allow_garage = true, max_residents = 20 }))
    PropertyTypes.Register(typeDefinition('garage', 'Garage', false, true, { allow_residents = false, allow_storage = true, allow_garage = true, allow_wardrobe = false, allow_furniture = false, max_residents = 0, max_garages = 1 }))
    PropertyTypes.Register(typeDefinition('motel', 'Motel', true, false))
    PropertyTypes.Register(typeDefinition('hotel', 'Hotel', true, false))
    PropertyTypes.Register(typeDefinition('warehouse', 'Warehouse', true, true))
    PropertyTypes.Register(typeDefinition('office', 'Office', true, true))
    PropertyTypes.Register(typeDefinition('shop', 'Shop', true, true))
    PropertyTypes.Register(typeDefinition('land', 'Land', false, true, { interior_type = 'exterior_only', allow_furniture = false }))
end

local function generatePropertyNumber()
    for _ = 1, 20 do
        local number = ('%s%s'):format(NexaPropertiesConfig.propertyNumberPrefix, math.random(10 ^ (NexaPropertiesConfig.propertyNumberLength - 1), (10 ^ NexaPropertiesConfig.propertyNumberLength) - 1))
        if not NexaPropertiesDatabase.GetPropertyByNumber(number) then return number end
    end
    return nil
end

function PropertyDefinitions.Create(definition, actor)
    definition = type(definition) == 'table' and definition or {}
    local context = actorContext(actor, 'property.definition.create')
    local propertyKey = normalizeString(definition.property_key or definition.key, 64)
    local label = normalizeString(definition.label, 128)
    local propertyType = normalizeString(definition.property_type, 32)
    if not propertyKey or not label or not PropertyTypes.IsRegistered(propertyType) then return fail(NEXA_PROPERTY_ERRORS.typeInvalid, 'Property definition is invalid.') end
    local id, err = NexaPropertiesDatabase.InsertDefinition({ property_key = propertyKey, label = label, property_type = propertyType, status = definition.status or NEXA_PROPERTY_STATUS.draft, purchase_price = normalizeAmount(definition.purchase_price) or 0, rent_amount = normalizeAmount(definition.rent_amount) or 0, rent_interval_seconds = normalizeId(definition.rent_interval_seconds) or NexaPropertiesConfig.defaultRentIntervalSeconds, entrance = definition.entrance or {}, exterior = definition.exterior or {}, interior_definition_id = normalizeId(definition.interior_definition_id), garage_definition_id = definition.garage_definition_id, storage_configuration = definition.storage_configuration or {}, security_configuration = definition.security_configuration or {}, settings = definition.settings or {}, metadata = definition.metadata or {} })
    if err then return fail(NEXA_PROPERTY_ERRORS.databaseError, 'Property definition could not be created.', err) end
    local result = ok({ definition_id = id, property_key = propertyKey }, 'Property definition created.')
    audit('property.definition.create', context, result, { after_state = definition })
    return result
end

function PropertyDefinitions.Get(idOrKey) local row, err = NexaPropertiesDatabase.GetDefinition(idOrKey); return err and fail(NEXA_PROPERTY_ERRORS.databaseError, 'Property definition could not be loaded.', err) or (row and ok(hydrateDefinition(row), 'Property definition loaded.') or fail(NEXA_PROPERTY_ERRORS.definitionNotFound, 'Property definition not found.')) end
function PropertyDefinitions.List(filters) local rows, err = NexaPropertiesDatabase.ListDefinitions(); return err and fail(NEXA_PROPERTY_ERRORS.databaseError, 'Property definitions could not be listed.', err) or ok(rows or {}, 'Property definitions listed.') end
function PropertyDefinitions.Activate(id, actor) local context = actorContext(actor, 'property.definition.activate'); NexaPropertiesDatabase.UpdateDefinitionStatus(normalizeId(id), NEXA_PROPERTY_STATUS.active); local result = ok({ definition_id = normalizeId(id), status = NEXA_PROPERTY_STATUS.active }, 'Property definition activated.'); audit('property.definition.activate', context, result, { metadata = result.data }); emit(NEXA_PROPERTY_EVENTS.activated, result.data); return result end
function PropertyDefinitions.Disable(id, actor, reason) local context = actorContext(actor or { reason = reason }, 'property.definition.disable'); NexaPropertiesDatabase.UpdateDefinitionStatus(normalizeId(id), NEXA_PROPERTY_STATUS.disabled); local result = ok({ definition_id = normalizeId(id) }, 'Property definition disabled.'); audit('property.definition.disable', context, result, { metadata = result.data }); return result end
function PropertyDefinitions.Archive(id, actor, reason) local context = actorContext(actor or { reason = reason }, 'property.definition.archive'); NexaPropertiesDatabase.UpdateDefinitionStatus(normalizeId(id), NEXA_PROPERTY_STATUS.archived); local result = ok({ definition_id = normalizeId(id) }, 'Property definition archived.'); audit('property.definition.archive', context, result, { metadata = result.data }); return result end

function Properties.Create(definitionId, context)
    context = actorContext(context, 'property.create')
    local definition = PropertyDefinitions.Get(definitionId)
    if not definition.ok then return definition end
    local number = generatePropertyNumber()
    if not number then return fail(NEXA_PROPERTY_ERRORS.invalidInput, 'Property number could not be generated.') end
    local id, err = NexaPropertiesDatabase.InsertProperty({ definition_id = definition.data.id, property_number = number, owner_type = NEXA_PROPERTY_OWNER_TYPES.system, owner_id = NexaPropertiesConfig.systemOwnerId, ownership_status = NEXA_PROPERTY_OWNERSHIP_STATUS.for_sale, lease_status = nil, primary_storage_id = ('property:%s:main'):format(number), garage_id = definition.data.garage_definition_id, security_status = 'inactive' })
    if err then return fail(NEXA_PROPERTY_ERRORS.databaseError, 'Property could not be created.', err) end
    NexaPropertiesDatabase.InsertOwnershipHistory({ property_id = id, owner_type = NEXA_PROPERTY_OWNER_TYPES.system, owner_id = NexaPropertiesConfig.systemOwnerId, ownership_type = 'initial', reason = context.reason, metadata = {} })
    local result = ok({ property_id = id, property_number = number }, 'Property created.')
    audit('property.create', context, result, { property_id = id, after_state = result.data })
    emit(NEXA_PROPERTY_EVENTS.created, result.data)
    return result
end

function Properties.Get(propertyId) local row, err = NexaPropertiesDatabase.GetProperty(normalizeId(propertyId)); return err and fail(NEXA_PROPERTY_ERRORS.databaseError, 'Property could not be loaded.', err) or (row and ok(hydrateProperty(row), 'Property loaded.') or fail(NEXA_PROPERTY_ERRORS.notFound, 'Property not found.')) end
function Properties.GetByNumber(number) local row, err = NexaPropertiesDatabase.GetPropertyByNumber(normalizeString(number, 32)); return err and fail(NEXA_PROPERTY_ERRORS.databaseError, 'Property could not be loaded.', err) or (row and ok(hydrateProperty(row), 'Property loaded.') or fail(NEXA_PROPERTY_ERRORS.notFound, 'Property not found.')) end
function Properties.List(filters) local rows, err = NexaPropertiesDatabase.ListProperties(); return err and fail(NEXA_PROPERTY_ERRORS.databaseError, 'Properties could not be listed.', err) or ok(rows or {}, 'Properties listed.') end
function Properties.GetForCharacter(characterId) local owned = Properties.GetOwnedByCharacter(characterId); local rented = Properties.GetRentedByCharacter(characterId); return ok({ owned = owned.ok and owned.data or {}, rented = rented.ok and rented.data or {} }, 'Character properties listed.') end
function Properties.GetOwnedByCharacter(characterId) local rows, err = NexaPropertiesDatabase.ListForOwner(NEXA_PROPERTY_OWNER_TYPES.character, normalizeId(characterId)); return err and fail(NEXA_PROPERTY_ERRORS.databaseError, 'Owned properties could not be listed.', err) or ok(rows or {}, 'Owned properties listed.') end
function Properties.GetRentedByCharacter(characterId) local lease = NexaPropertiesDatabase.GetCharacterLease(normalizeId(characterId)); return ok(lease and { lease } or {}, 'Rented properties listed.') end
function Properties.UpdateStatus(propertyId, status, actor, reason) local context = actorContext(actor or { reason = reason }, 'property.status.update'); NexaPropertiesDatabase.UpdatePropertyStatus(normalizeId(propertyId), status); local result = ok({ property_id = normalizeId(propertyId), status = status }, 'Property status updated.'); audit('property.status.update', context, result, { property_id = normalizeId(propertyId) }); return result end
function Properties.Delete(propertyId, actor, reason) local context = actorContext(actor or { reason = reason }, 'property.delete'); NexaPropertiesDatabase.SoftDeleteProperty(normalizeId(propertyId)); local result = ok({ property_id = normalizeId(propertyId) }, 'Property deleted.'); audit('property.delete', context, result, { property_id = normalizeId(propertyId) }); return result end

function PropertyOwnership.Get(propertyId) local property = Properties.Get(propertyId); return property.ok and ok({ owner_type = property.data.owner_type, owner_id = property.data.owner_id, ownership_status = property.data.ownership_status }, 'Property ownership loaded.') or property end
function PropertyOwnership.Assign(propertyId, ownerType, ownerId, context) context = actorContext(context, 'property.ownership.assign'); if not NEXA_PROPERTY_OWNER_TYPES[ownerType] or not ownerId then return fail(NEXA_PROPERTY_ERRORS.ownerInvalid, 'Property owner is invalid.') end; NexaPropertiesDatabase.UpdatePropertyOwner(normalizeId(propertyId), ownerType, tostring(ownerId), NEXA_PROPERTY_OWNERSHIP_STATUS.owned); NexaPropertiesDatabase.InsertOwnershipHistory({ property_id = normalizeId(propertyId), owner_type = ownerType, owner_id = tostring(ownerId), ownership_type = 'assigned', reason = context.reason, metadata = {} }); local result = ok({ property_id = normalizeId(propertyId), owner_type = ownerType, owner_id = tostring(ownerId) }, 'Property ownership assigned.'); audit('property.ownership.assign', context, result, { property_id = normalizeId(propertyId) }); emit(NEXA_PROPERTY_EVENTS.ownershipChanged, result.data); return result end
function PropertyOwnership.Transfer(propertyId, targetOwnerType, targetOwnerId, context) return PropertyOwnership.Assign(propertyId, targetOwnerType, targetOwnerId, actorContext(context, 'property.ownership.transfer')) end
function PropertyOwnership.ListForOwner(ownerType, ownerId) local rows, err = NexaPropertiesDatabase.ListForOwner(ownerType, ownerId); return err and fail(NEXA_PROPERTY_ERRORS.databaseError, 'Owner properties could not be listed.', err) or ok(rows or {}, 'Owner properties listed.') end
function PropertyOwnership.CanManage(actor, propertyId, action) return ok({ property_id = propertyId, action = action, allowed = true }, 'Property management evaluated.') end

function PropertySales.GetQuote(propertyId, action, actor) local property = Properties.Get(propertyId); if not property.ok then return property end; local definition = PropertyDefinitions.Get(property.data.definition_id); if not definition.ok then return definition end; local amount = action == 'sell' and math.floor((tonumber(definition.data.purchase_price) or 0) * 0.75) or tonumber(definition.data.purchase_price) or 0; return ok({ property_id = propertyId, action = action, amount = amount }, 'Property quote created.') end
function PropertySales.Buy(source, propertyId, context) context = actorContext(context or { source = source }, 'property.buy'); local quote = PropertySales.GetQuote(propertyId, 'buy', context); if not quote.ok then return quote end; local property = Properties.Get(propertyId); if not property.ok then return property end; if property.data.ownership_status ~= NEXA_PROPERTY_OWNERSHIP_STATUS.for_sale and property.data.ownership_status ~= NEXA_PROPERTY_OWNERSHIP_STATUS.unowned then return fail(NEXA_PROPERTY_ERRORS.notForSale, 'Property is not for sale.') end; local assign = PropertyOwnership.Assign(propertyId, NEXA_PROPERTY_OWNER_TYPES.character, context.actor_character_id or source, context); local result = assign.ok and ok({ property_id = propertyId, amount = quote.data.amount }, 'Property purchased.') or assign; audit('property.buy', context, result, { property_id = propertyId, metadata = { economy_required = 'nexa_economy', amount = quote.data.amount } }); if result.ok then emit(NEXA_PROPERTY_EVENTS.purchased, result.data) end; return result end
function PropertySales.SellToSystem(source, propertyId, context) context = actorContext(context or { source = source }, 'property.sell'); local result = PropertyOwnership.Assign(propertyId, NEXA_PROPERTY_OWNER_TYPES.system, NexaPropertiesConfig.systemOwnerId, context); if result.ok then NexaPropertiesDatabase.UpdatePropertyStatus(normalizeId(propertyId), NEXA_PROPERTY_OWNERSHIP_STATUS.for_sale); emit(NEXA_PROPERTY_EVENTS.sold, result.data) end; return result end
function PropertySales.Transfer(actor, propertyId, target, context) target = type(target) == 'table' and target or {}; return PropertyOwnership.Transfer(propertyId, target.owner_type, target.owner_id, context or actor) end

function Leases.Create(propertyId, tenantCharacterId, actor, context) context = actorContext(context or actor, 'property.lease.create'); propertyId = normalizeId(propertyId); tenantCharacterId = normalizeId(tenantCharacterId); if NexaPropertiesDatabase.GetActiveLease(propertyId) then return fail(NEXA_PROPERTY_ERRORS.leaseAlreadyActive, 'Property already has an active lease.') end; local property = Properties.Get(propertyId); if not property.ok then return property end; local definition = PropertyDefinitions.Get(property.data.definition_id); if not definition.ok then return definition end; local typeDef = PropertyTypes.Get(definition.data.property_type); if not typeDef or not typeDef.rentable then return fail(NEXA_PROPERTY_ERRORS.notRentable, 'Property is not rentable.') end; local id, err = NexaPropertiesDatabase.InsertLease({ property_id = propertyId, tenant_character_id = tenantCharacterId, status = NEXA_PROPERTY_LEASE_STATUS.active, rent_amount = tonumber(definition.data.rent_amount) or 0, interval_seconds = tonumber(definition.data.rent_interval_seconds) or NexaPropertiesConfig.defaultRentIntervalSeconds, next_due_at = os.time() + (tonumber(definition.data.rent_interval_seconds) or NexaPropertiesConfig.defaultRentIntervalSeconds), deposit_amount = 0, economy_account_id = nil, created_by = context.actor_character_id, metadata = {} }); if err then return fail(NEXA_PROPERTY_ERRORS.databaseError, 'Lease could not be created.', err) end; Residents.Invite(context, propertyId, tenantCharacterId, { enter = true, access_storage = true }, { resident_type = NEXA_PROPERTY_RESIDENT_TYPES.tenant, auto_accept = true }); local result = ok({ lease_id = id, property_id = propertyId }, 'Lease created.'); audit('property.lease.create', context, result, { property_id = propertyId, target_character_id = tenantCharacterId }); emit(NEXA_PROPERTY_EVENTS.leaseCreated, result.data); return result end
function Leases.Get(leaseId) local row, err = NexaPropertiesDatabase.GetLease(normalizeId(leaseId)); return err and fail(NEXA_PROPERTY_ERRORS.databaseError, 'Lease could not be loaded.', err) or (row and ok(row, 'Lease loaded.') or fail(NEXA_PROPERTY_ERRORS.leaseNotFound, 'Lease not found.')) end
function Leases.GetForCharacter(characterId) local row = NexaPropertiesDatabase.GetCharacterLease(normalizeId(characterId)); return row and ok(row, 'Lease loaded.') or fail(NEXA_PROPERTY_ERRORS.leaseNotFound, 'Lease not found.') end
function Leases.Terminate(actor, leaseId, reason) local context = actorContext(actor or { reason = reason }, 'property.lease.terminate'); NexaPropertiesDatabase.UpdateLeaseStatus(normalizeId(leaseId), NEXA_PROPERTY_LEASE_STATUS.terminated, context.reason); local result = ok({ lease_id = normalizeId(leaseId) }, 'Lease terminated.'); audit('property.lease.terminate', context, result, {}); emit(NEXA_PROPERTY_EVENTS.leaseEnded, result.data); return result end
function Leases.Evict(actor, leaseId, reason) local context = actorContext(actor or { reason = reason }, 'property.lease.evict'); NexaPropertiesDatabase.UpdateLeaseStatus(normalizeId(leaseId), NEXA_PROPERTY_LEASE_STATUS.evicted, context.reason); local result = ok({ lease_id = normalizeId(leaseId) }, 'Lease evicted.'); audit('property.lease.evict', context, result, {}); return result end
function Leases.Renew(actor, leaseId, context) return ok({ lease_id = normalizeId(leaseId) }, 'Lease renewal foundation recorded.') end
function Rent.Pay(source, leaseId, context) context = actorContext(context or { source = source }, 'property.rent.pay'); local lease = Leases.Get(leaseId); if not lease.ok then return lease end; local nextDueAt = os.time() + tonumber(lease.data.interval_seconds or NexaPropertiesConfig.defaultRentIntervalSeconds); NexaPropertiesDatabase.MarkRentPaid(lease.data.id, nextDueAt); local result = ok({ lease_id = lease.data.id, amount = lease.data.rent_amount, next_due_at = nextDueAt }, 'Rent paid.'); audit('property.rent.pay', context, result, { property_id = lease.data.property_id, metadata = { economy_required = 'nexa_economy' } }); emit(NEXA_PROPERTY_EVENTS.rentPaid, result.data); return result end
function Rent.GetStatus(leaseId) local lease = Leases.Get(leaseId); if not lease.ok then return lease end; return ok({ lease_id = lease.data.id, status = lease.data.status, next_due_at = lease.data.next_due_at }, 'Rent status loaded.') end
function Rent.MarkOverdue(leaseId, context) context = actorContext(context, 'property.rent.overdue'); NexaPropertiesDatabase.UpdateLeaseStatus(normalizeId(leaseId), NEXA_PROPERTY_LEASE_STATUS.overdue, 'rent overdue'); local result = ok({ lease_id = normalizeId(leaseId) }, 'Lease marked overdue.'); emit(NEXA_PROPERTY_EVENTS.rentOverdue, result.data); return result end
function Rent.ProcessDue(nowValue) return ok({ processed_at = nowValue or os.time() }, 'Rent due processing foundation completed.') end

function Residents.List(propertyId) local rows, err = NexaPropertiesDatabase.ListResidents(normalizeId(propertyId)); return err and fail(NEXA_PROPERTY_ERRORS.databaseError, 'Residents could not be listed.', err) or ok(rows or {}, 'Residents listed.') end
function Residents.Invite(actorSource, propertyId, targetCharacterId, permissions, context) context = actorContext(context or actorSource, 'property.resident.invite'); propertyId = normalizeId(propertyId); targetCharacterId = normalizeId(targetCharacterId); if NexaPropertiesDatabase.GetResident(propertyId, targetCharacterId) then return fail(NEXA_PROPERTY_ERRORS.residentAlreadyExists, 'Resident already exists.') end; local current = NexaPropertiesDatabase.ListResidents(propertyId) or {}; if #current >= NexaPropertiesConfig.maxResidents then return fail(NEXA_PROPERTY_ERRORS.residentLimitReached, 'Resident limit reached.') end; local status = context.auto_accept and NEXA_PROPERTY_RESIDENT_STATUS.active or NEXA_PROPERTY_RESIDENT_STATUS.invited; local id, err = NexaPropertiesDatabase.InsertResident({ property_id = propertyId, character_id = targetCharacterId, resident_type = context.resident_type or NEXA_PROPERTY_RESIDENT_TYPES.roommate, status = status, permissions = permissions or {}, invited_by = context.actor_character_id, metadata = {} }); if err then return fail(NEXA_PROPERTY_ERRORS.databaseError, 'Resident could not be invited.', err) end; local result = ok({ resident_id = id, property_id = propertyId, character_id = targetCharacterId, status = status }, 'Resident invited.'); audit('property.resident.invite', context, result, { property_id = propertyId, target_character_id = targetCharacterId }); return result end
function Residents.Accept(source, invitationId) NexaPropertiesDatabase.UpdateResidentStatus(normalizeId(invitationId), NEXA_PROPERTY_RESIDENT_STATUS.active); return ok({ resident_id = normalizeId(invitationId) }, 'Resident invitation accepted.') end
function Residents.Decline(source, invitationId) NexaPropertiesDatabase.UpdateResidentStatus(normalizeId(invitationId), NEXA_PROPERTY_RESIDENT_STATUS.removed); return ok({ resident_id = normalizeId(invitationId) }, 'Resident invitation declined.') end
function Residents.Remove(actor, propertyId, characterId, reason) local context = actorContext(actor or { reason = reason }, 'property.resident.remove'); local resident = NexaPropertiesDatabase.GetResident(normalizeId(propertyId), normalizeId(characterId)); if not resident then return fail(NEXA_PROPERTY_ERRORS.residentNotFound, 'Resident not found.') end; NexaPropertiesDatabase.UpdateResidentStatus(resident.id, NEXA_PROPERTY_RESIDENT_STATUS.removed); local result = ok({ resident_id = resident.id }, 'Resident removed.'); audit('property.resident.remove', context, result, { property_id = normalizeId(propertyId), target_character_id = normalizeId(characterId) }); emit(NEXA_PROPERTY_EVENTS.residentRemoved, result.data); return result end
function Residents.UpdatePermissions(actor, propertyId, characterId, permissions, reason) local context = actorContext(actor or { reason = reason }, 'property.resident.permissions'); local resident = NexaPropertiesDatabase.GetResident(normalizeId(propertyId), normalizeId(characterId)); if not resident then return fail(NEXA_PROPERTY_ERRORS.residentNotFound, 'Resident not found.') end; NexaPropertiesDatabase.UpdateResidentPermissions(resident.id, permissions or {}); local result = ok({ resident_id = resident.id, permissions = permissions or {} }, 'Resident permissions updated.'); audit('property.resident.permissions', context, result, { property_id = normalizeId(propertyId), target_character_id = normalizeId(characterId) }); return result end
function Residents.IsResident(characterId, propertyId) return NexaPropertiesDatabase.GetResident(normalizeId(propertyId), normalizeId(characterId)) ~= nil end

function PropertyStorage.Get(propertyId, storageKey) return ok({ owner_type = NexaPropertiesConfig.storageOwnerType, owner_id = ('%s:%s'):format(propertyId, storageKey or 'main') }, 'Property storage resolved.') end
function PropertyStorage.Open(actor, propertyId, storageKey) return PropertyStorage.Get(propertyId, storageKey) end
function PropertyWardrobes.Get(propertyId) return ok({ property_id = propertyId, wardrobes = { 'default' } }, 'Property wardrobes loaded.') end
function PropertyWardrobes.CanAccess(actor, propertyId, wardrobeKey) return ok({ property_id = propertyId, wardrobe_key = wardrobeKey, allowed = true }, 'Wardrobe access evaluated.') end
function PropertyGarages.Get(propertyId) local property = Properties.Get(propertyId); return property.ok and ok({ property_id = propertyId, garage_id = property.data.garage_id }, 'Property garage loaded.') or property end
function PropertyGarages.ListVehicles(actor, propertyId) local garage = PropertyGarages.Get(propertyId); if not garage.ok or not garage.data.garage_id then return ok({}, 'Property has no garage.') end; return exports['nexa_garages']:GetStoredVehicles(garage.data.garage_id) end

function Furniture.Place(source, propertyId, furnitureName, transform, context) context = actorContext(context or { source = source }, 'property.furniture.place'); transform = type(transform) == 'table' and transform or {}; local id, err = NexaPropertiesDatabase.InsertFurniture({ property_id = normalizeId(propertyId), model = normalizeString(furnitureName, 64), position = transform.position or {}, rotation = transform.rotation or {}, scale = transform.scale or {}, state = {}, placed_by = context.actor_character_id, status = 'active', metadata = transform.metadata or {} }); if err then return fail(NEXA_PROPERTY_ERRORS.databaseError, 'Furniture could not be placed.', err) end; local result = ok({ furniture_id = id, property_id = normalizeId(propertyId) }, 'Furniture placed.'); audit('property.furniture.place', context, result, { property_id = normalizeId(propertyId) }); return result end
function Furniture.Move(source, propertyId, furnitureId, transform, context) context = actorContext(context or { source = source }, 'property.furniture.move'); NexaPropertiesDatabase.UpdateFurniture(normalizeId(furnitureId), transform or {}); local result = ok({ furniture_id = normalizeId(furnitureId), property_id = normalizeId(propertyId) }, 'Furniture moved.'); audit('property.furniture.move', context, result, { property_id = normalizeId(propertyId) }); return result end
function Furniture.Remove(source, propertyId, furnitureId, reason) local context = actorContext({ source = source, reason = reason }, 'property.furniture.remove'); NexaPropertiesDatabase.RemoveFurniture(normalizeId(furnitureId)); local result = ok({ furniture_id = normalizeId(furnitureId) }, 'Furniture removed.'); audit('property.furniture.remove', context, result, { property_id = normalizeId(propertyId) }); return result end
function Furniture.List(propertyId) local rows, err = NexaPropertiesDatabase.ListFurniture(normalizeId(propertyId)); return err and fail(NEXA_PROPERTY_ERRORS.databaseError, 'Furniture could not be listed.', err) or ok(rows or {}, 'Furniture listed.') end

function PropertyAdmin.SetStatus(actor, propertyId, status, reason) return Properties.UpdateStatus(propertyId, status, actor, reason) end
function PropertyCreator.CreateDefinition(definition, actor) return PropertyDefinitions.Create(definition, actor) end
function PropertyCreator.PublishDefinition(id, actor) return PropertyDefinitions.Activate(id, actor) end

function GetProperty(...) return Properties.Get(...) end
function GetPropertyByNumber(...) return Properties.GetByNumber(...) end
function ListProperties(...) return Properties.List(...) end
function GetCharacterProperties(...) return Properties.GetForCharacter(...) end
function GetOwnedProperties(...) return Properties.GetOwnedByCharacter(...) end
function GetRentedProperties(...) return Properties.GetRentedByCharacter(...) end
function CreateProperty(...) return Properties.Create(...) end
function UpdateProperty(...) return Properties.UpdateStatus(...) end
function BuyProperty(...) return PropertySales.Buy(...) end
function SellProperty(...) return PropertySales.SellToSystem(...) end
function TransferProperty(...) return PropertySales.Transfer(...) end
function GetLease(...) return Leases.Get(...) end
function GetCharacterLease(...) return Leases.GetForCharacter(...) end
function CreateLease(...) return Leases.Create(...) end
function TerminateLease(...) return Leases.Terminate(...) end
function PayRent(...) return Rent.Pay(...) end
function GetRentStatus(...) return Rent.GetStatus(...) end
function ListResidents(...) return Residents.List(...) end
function InviteResident(...) return Residents.Invite(...) end
function AcceptResidentInvitation(...) return Residents.Accept(...) end
function RemoveResident(...) return Residents.Remove(...) end
function UpdateResidentPermissions(...) return Residents.UpdatePermissions(...) end
function GetPropertyStorage(...) return PropertyStorage.Get(...) end
function OpenPropertyStorage(...) return PropertyStorage.Open(...) end
function GetPropertyGarage(...) return PropertyGarages.Get(...) end
function ListPropertyVehicles(...) return PropertyGarages.ListVehicles(...) end
function PlaceFurniture(...) return Furniture.Place(...) end
function MoveFurniture(...) return Furniture.Move(...) end
function RemoveFurniture(...) return Furniture.Remove(...) end
function ListFurniture(...) return Furniture.List(...) end
function AdminSetPropertyStatus(...) return PropertyAdmin.SetStatus(...) end
function CreatorCreateDefinition(...) return PropertyCreator.CreateDefinition(...) end
function CreatorPublishDefinition(...) return PropertyCreator.PublishDefinition(...) end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    registerDefaultTypes()
    if NexaPropertiesConfig.autoMigrate then migrated = NexaPropertiesDatabase.Migrate() == true end
    log('Info', 'properties.start', 'nexa_properties started.', { migrated = migrated, propertyTypes = #PropertyTypes.List() })
end)

exports('GetProperty', GetProperty)
exports('GetPropertyByNumber', GetPropertyByNumber)
exports('ListProperties', ListProperties)
exports('GetCharacterProperties', GetCharacterProperties)
exports('GetOwnedProperties', GetOwnedProperties)
exports('GetRentedProperties', GetRentedProperties)
exports('CreateProperty', CreateProperty)
exports('UpdateProperty', UpdateProperty)
exports('BuyProperty', BuyProperty)
exports('SellProperty', SellProperty)
exports('TransferProperty', TransferProperty)
exports('GetLease', GetLease)
exports('GetCharacterLease', GetCharacterLease)
exports('CreateLease', CreateLease)
exports('TerminateLease', TerminateLease)
exports('PayRent', PayRent)
exports('GetRentStatus', GetRentStatus)
exports('ListResidents', ListResidents)
exports('InviteResident', InviteResident)
exports('AcceptResidentInvitation', AcceptResidentInvitation)
exports('RemoveResident', RemoveResident)
exports('UpdateResidentPermissions', UpdateResidentPermissions)
exports('GetPropertyStorage', GetPropertyStorage)
exports('OpenPropertyStorage', OpenPropertyStorage)
exports('GetPropertyGarage', GetPropertyGarage)
exports('ListPropertyVehicles', ListPropertyVehicles)
exports('PlaceFurniture', PlaceFurniture)
exports('MoveFurniture', MoveFurniture)
exports('RemoveFurniture', RemoveFurniture)
exports('ListFurniture', ListFurniture)
exports('AdminSetPropertyStatus', AdminSetPropertyStatus)
exports('CreatorCreateDefinition', CreatorCreateDefinition)
exports('CreatorPublishDefinition', CreatorPublishDefinition)
exports('getStatus', function() return { resourceName = NEXA_PROPERTIES.resourceName, version = NEXA_PROPERTIES.version, migrated = migrated, propertyTypes = PropertyTypes.List() } end)
exports('getSchema', NexaPropertiesDatabase.GetSchema)
