local migrated = false
local ShopTypes = {}
local TypeRegistry = {}
local stockReservations = {}

Shops = {}
ShopCatalog = {}
Pricing = {}
Stock = {}
ShopTransactions = {}
Deliveries = {}
ShopCreator = {}

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_SHOP_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeAmount(value) value = tonumber(value); return value and value > 0 and value % 1 == 0 and math.floor(value) or nil end
local function normalizeMoney(value) value = tonumber(value); return value and value >= 0 and value % 1 == 0 and math.floor(value) or nil end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local s = value:gsub('^%s+', ''):gsub('%s+$', ''); if s == '' or (maxLength and #s > maxLength) then return nil end; return s end

local function getCore() if GetResourceState('nexa-core') ~= 'started' then return nil end; local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return good and core or nil end
local function log(level, category, message, context) local core = getCore(); if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s %s'):format(NEXA_SHOPS.resourceName, level, message, encode(context))) end
local function emit(eventName, payload) local core = getCore(); if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_SHOPS.resourceName }) end end
local function actorContext(actor, action) actor = type(actor) == 'table' and actor or {}; return { action = action, source = normalizeId(actor.source), actor_account_id = normalizeId(actor.actor_account_id), actor_character_id = normalizeId(actor.actor_character_id or actor.character_id), reason = normalizeString(actor.reason, 255), source_resource = normalizeString(actor.source_resource or GetInvokingResource() or NEXA_SHOPS.resourceName, 64), correlation_id = normalizeString(actor.correlation_id, 128) or ('shop:%s:%s:%s'):format(action, os.time(), math.random(100000,999999)), idempotency_key = normalizeString(actor.idempotency_key, 128) or ('shopidem:%s:%s'):format(os.time(), math.random(100000,999999)) } end
local function audit(action, context, result, payload) payload = payload or {}; NexaShopsDatabase.InsertAudit({ shop_id = payload.shop_id, action = action, actor_account_id = context.actor_account_id, actor_character_id = context.actor_character_id, before_state = payload.before_state, after_state = payload.after_state, reason = context.reason, result = result.ok and 'success' or 'failed', error_code = result.ok and nil or result.code, source_resource = context.source_resource, correlation_id = context.correlation_id, metadata = payload.metadata }) end

function ShopTypes.Register(definition) if type(definition) ~= 'table' or not normalizeString(definition.name, 64) then return false end; TypeRegistry[definition.name] = definition; return true end
function ShopTypes.Get(name) return TypeRegistry[name] end
function ShopTypes.List() local list = {}; for _, definition in pairs(TypeRegistry) do list[#list + 1] = definition end; return list end
function ShopTypes.IsRegistered(name) return TypeRegistry[name] ~= nil end
function ShopTypes.Validate(name) return ShopTypes.IsRegistered(name) end

local function registerDefaultTypes()
    local function t(name, label, options) options = options or {}; ShopTypes.Register({ name = name, label = label, allow_infinite_stock = options.allow_infinite_stock == true, allow_sell_to_shop = options.allow_sell_to_shop == true, allow_organization_owner = options.allow_organization_owner == true, government = options.government == true, illegal = options.illegal == true, requires_duty = options.requires_duty == true, access_rules = options.access_rules or {}, economy_account_type = options.economy_account_type or 'shop', audit_level = options.audit_level or 'info', metadata = options.metadata or {} }) end
    t('government', 'Government', { allow_infinite_stock = true, government = true, audit_level = 'audit' })
    t('general', 'General', { allow_infinite_stock = true, allow_sell_to_shop = true })
    t('organization', 'Organization', { allow_organization_owner = true, allow_sell_to_shop = true, requires_duty = true })
    t('business', 'Business', { allow_organization_owner = true, allow_sell_to_shop = true })
    t('illegal', 'Illegal', { illegal = true, allow_sell_to_shop = true, audit_level = 'security' })
    t('service', 'Service', { requires_duty = true })
    t('vehicle_related', 'Vehicle Related', { allow_sell_to_shop = true })
    t('medical', 'Medical', { requires_duty = true })
    t('weapon', 'Weapon', { requires_duty = true, audit_level = 'audit' })
    t('temporary', 'Temporary', {})
    t('custom', 'Custom', {})
end

function Shops.Create(definition, actor)
    definition = type(definition) == 'table' and definition or {}
    local context = actorContext(actor, 'shop.create')
    local shopKey = normalizeString(definition.shop_key or definition.name, 64)
    local label = normalizeString(definition.label, 128)
    local shopType = normalizeString(definition.shop_type or 'general', 32)
    if not shopKey or not label or not ShopTypes.IsRegistered(shopType) then return fail(NEXA_SHOP_ERRORS.typeInvalid, 'Shop definition is invalid.') end
    local id, err = NexaShopsDatabase.InsertShop({ shop_key = shopKey, label = label, shop_type = shopType, status = definition.status or NEXA_SHOP_STATUS.draft, owner_type = definition.owner_type, owner_id = definition.owner_id and tostring(definition.owner_id) or nil, organization_id = normalizeId(definition.organization_id), property_id = normalizeId(definition.property_id), economy_account_id = normalizeId(definition.economy_account_id), inventory_id = definition.inventory_id, position = definition.position or {}, access_rules = definition.access_rules or {}, stock_policy = definition.stock_policy or {}, pricing_policy = definition.pricing_policy or {}, settings = definition.settings or {}, created_by = context.actor_character_id })
    if err then return fail(NEXA_SHOP_ERRORS.databaseError, 'Shop could not be created.', err) end
    local result = ok({ shop_id = id, shop_key = shopKey }, 'Shop created.')
    audit('shop.create', context, result, { shop_id = id, after_state = definition })
    emit(NEXA_SHOP_EVENTS.created, result.data)
    return result
end
function Shops.Get(idOrKey) local row, err = NexaShopsDatabase.GetShop(idOrKey); return err and fail(NEXA_SHOP_ERRORS.databaseError, 'Shop could not be loaded.', err) or (row and ok(row, 'Shop loaded.') or fail(NEXA_SHOP_ERRORS.notFound, 'Shop not found.')) end
function Shops.List(filters) local rows, err = NexaShopsDatabase.ListShops(filters); return err and fail(NEXA_SHOP_ERRORS.databaseError, 'Shops could not be listed.', err) or ok(rows or {}, 'Shops listed.') end
function Shops.Update(shopId, changes, actor) return Shops.Activate(shopId, actor) end
function Shops.Activate(shopId, actor) local context = actorContext(actor, 'shop.activate'); NexaShopsDatabase.UpdateShopStatus(normalizeId(shopId), NEXA_SHOP_STATUS.active); local result = ok({ shop_id = normalizeId(shopId), status = NEXA_SHOP_STATUS.active }, 'Shop activated.'); audit('shop.activate', context, result, { shop_id = normalizeId(shopId) }); emit(NEXA_SHOP_EVENTS.activated, result.data); return result end
function Shops.Suspend(shopId, actor, reason) if not normalizeString(reason or (type(actor) == 'table' and actor.reason), 255) then return fail(NEXA_SHOP_ERRORS.reasonRequired, 'Reason is required.') end; NexaShopsDatabase.UpdateShopStatus(normalizeId(shopId), NEXA_SHOP_STATUS.suspended); return ok({ shop_id = normalizeId(shopId) }, 'Shop suspended.') end
function Shops.Disable(shopId, actor, reason) if not normalizeString(reason or (type(actor) == 'table' and actor.reason), 255) then return fail(NEXA_SHOP_ERRORS.reasonRequired, 'Reason is required.') end; NexaShopsDatabase.UpdateShopStatus(normalizeId(shopId), NEXA_SHOP_STATUS.disabled); return ok({ shop_id = normalizeId(shopId) }, 'Shop disabled.') end
function Shops.Archive(shopId, actor, reason) if not normalizeString(reason or (type(actor) == 'table' and actor.reason), 255) then return fail(NEXA_SHOP_ERRORS.reasonRequired, 'Reason is required.') end; NexaShopsDatabase.UpdateShopStatus(normalizeId(shopId), NEXA_SHOP_STATUS.archived); return ok({ shop_id = normalizeId(shopId) }, 'Shop archived.') end

local function validateItemExists(itemName)
    if GetResourceState('nexa_items') ~= 'started' then return true end
    local okCall, result = pcall(function() return exports['nexa_items']:GetItem(itemName) end)
    return okCall and result and (result.ok == true or result.success == true)
end

function ShopCatalog.AddItem(shopId, itemDefinition, actor)
    itemDefinition = type(itemDefinition) == 'table' and itemDefinition or {}
    local context = actorContext(actor, 'shop.catalog.add')
    shopId = normalizeId(shopId)
    local itemName = normalizeString(itemDefinition.item_name, 64)
    if not shopId or not itemName or not validateItemExists(itemName) then return fail(NEXA_SHOP_ERRORS.itemNotFound, 'Shop item is invalid.') end
    local buyPrice = normalizeMoney(itemDefinition.buy_price or itemDefinition.price)
    local sellPrice = normalizeMoney(itemDefinition.sell_price or 0)
    if not buyPrice then return fail(NEXA_SHOP_ERRORS.priceInvalid, 'Shop price is invalid.') end
    local id, err = NexaShopsDatabase.InsertShopItem({ shop_id = shopId, item_name = itemName, buy_price = buyPrice, sell_price = sellPrice or 0, buy_enabled = itemDefinition.buy_enabled ~= false, sell_enabled = itemDefinition.sell_enabled == true, stock_mode = itemDefinition.stock_mode or NexaShopsConfig.defaultStockMode, stock_amount = normalizeMoney(itemDefinition.stock_amount or itemDefinition.stock) or 0, max_stock = normalizeMoney(itemDefinition.max_stock) or 0, restock_threshold = normalizeMoney(itemDefinition.restock_threshold) or 0, purchase_limit = normalizeMoney(itemDefinition.purchase_limit), required_license = itemDefinition.required_license, access_rules = itemDefinition.access_rules or {}, metadata = itemDefinition.metadata or {} })
    if err then return fail(NEXA_SHOP_ERRORS.databaseError, 'Shop item could not be added.', err) end
    local result = ok({ shop_item_id = id, shop_id = shopId, item_name = itemName }, 'Shop item added.')
    audit('shop.catalog.add', context, result, { shop_id = shopId, after_state = itemDefinition })
    return result
end
function ShopCatalog.GetItem(shopId, itemName) local row, err = NexaShopsDatabase.GetShopItem(normalizeId(shopId), normalizeString(itemName, 64)); return err and fail(NEXA_SHOP_ERRORS.databaseError, 'Shop item could not be loaded.', err) or (row and ok(row, 'Shop item loaded.') or fail(NEXA_SHOP_ERRORS.itemNotFound, 'Shop item not found.')) end
function ShopCatalog.List(shopId) local rows, err = NexaShopsDatabase.ListShopItems(normalizeId(shopId)); return err and fail(NEXA_SHOP_ERRORS.databaseError, 'Shop catalog could not be listed.', err) or ok(rows or {}, 'Shop catalog listed.') end
function ShopCatalog.UpdateItem(shopId, itemName, changes, actor) local item = ShopCatalog.GetItem(shopId, itemName); if not item.ok then return item end; changes = type(changes) == 'table' and changes or {}; NexaShopsDatabase.UpdateShopItem(item.data.id, { buy_price = normalizeMoney(changes.buy_price or item.data.buy_price) or 0, sell_price = normalizeMoney(changes.sell_price or item.data.sell_price) or 0, buy_enabled = changes.buy_enabled ~= false, sell_enabled = changes.sell_enabled == true, stock_mode = changes.stock_mode or item.data.stock_mode, stock_amount = normalizeMoney(changes.stock_amount or item.data.stock_amount) or 0, max_stock = normalizeMoney(changes.max_stock or item.data.max_stock) or 0 }); return ok({ shop_id = normalizeId(shopId), item_name = itemName }, 'Shop item updated.') end
function ShopCatalog.RemoveItem(shopId, itemName, actor, reason) local item = ShopCatalog.GetItem(shopId, itemName); if not item.ok then return item end; NexaShopsDatabase.RemoveShopItem(item.data.id); return ok({ shop_id = normalizeId(shopId), item_name = itemName }, 'Shop item removed.') end

function Pricing.ResolveBuyPrice(shopId, itemName, actor, amount, context) local item = ShopCatalog.GetItem(shopId, itemName); if not item.ok then return item end; amount = normalizeAmount(amount) or 1; return ok({ unit_price = tonumber(item.data.buy_price), total_price = tonumber(item.data.buy_price) * amount, amount = amount }, 'Buy price resolved.') end
function Pricing.ResolveSellPrice(shopId, itemName, actor, amount, context) local item = ShopCatalog.GetItem(shopId, itemName); if not item.ok then return item end; amount = normalizeAmount(amount) or 1; return ok({ unit_price = tonumber(item.data.sell_price), total_price = tonumber(item.data.sell_price) * amount, amount = amount }, 'Sell price resolved.') end
function Pricing.Validate(shopId, itemName, price, context) return normalizeMoney(price) ~= nil end
function Pricing.GetBreakdown(shopId, itemName, actor, amount) return Pricing.ResolveBuyPrice(shopId, itemName, actor, amount) end

function Stock.Get(shopId, itemName) local item = ShopCatalog.GetItem(shopId, itemName); if not item.ok then return item end; return ok({ shop_id = normalizeId(shopId), item_name = itemName, stock_mode = item.data.stock_mode, stock_amount = tonumber(item.data.stock_amount), max_stock = tonumber(item.data.max_stock) }, 'Shop stock loaded.') end
function Stock.CanFulfill(shopId, itemName, amount) local stock = Stock.Get(shopId, itemName); if not stock.ok then return stock end; amount = normalizeAmount(amount) or 1; local can = stock.data.stock_mode == NEXA_SHOP_STOCK_MODE.infinite or tonumber(stock.data.stock_amount or 0) >= amount; return ok({ can_fulfill = can, stock = stock.data }, 'Shop stock evaluated.') end
function Stock.Reserve(shopId, itemName, amount, context) local can = Stock.CanFulfill(shopId, itemName, amount); if not can.ok or not can.data.can_fulfill then return fail(NEXA_SHOP_ERRORS.stockInsufficient, 'Shop stock is insufficient.', can) end; local id = ('stock:%s:%s:%s:%s'):format(shopId, itemName, os.time(), math.random(100000,999999)); stockReservations[id] = { shop_id = normalizeId(shopId), item_name = itemName, amount = normalizeAmount(amount) or 1, committed = false }; return ok({ reservation_id = id }, 'Shop stock reserved.') end
function Stock.Commit(reservationId, context) local reservation = stockReservations[reservationId]; if not reservation then return fail(NEXA_SHOP_ERRORS.stockInsufficient, 'Stock reservation not found.') end; local stock = Stock.Get(reservation.shop_id, reservation.item_name); if stock.ok and stock.data.stock_mode ~= NEXA_SHOP_STOCK_MODE.infinite then NexaShopsDatabase.AdjustStock(reservation.shop_id, reservation.item_name, -reservation.amount); NexaShopsDatabase.InsertStockMovement({ shop_id = reservation.shop_id, item_name = reservation.item_name, movement_type = 'purchase', amount = -reservation.amount, stock_before = stock.data.stock_amount, stock_after = stock.data.stock_amount - reservation.amount, source_resource = NEXA_SHOPS.resourceName, reason = 'transaction', correlation_id = context and context.correlation_id, metadata = {} }) end; stockReservations[reservationId] = nil; emit(NEXA_SHOP_EVENTS.stockChanged, reservation); return ok(reservation, 'Shop stock committed.') end
function Stock.Release(reservationId, context) stockReservations[reservationId] = nil; return ok({ reservation_id = reservationId }, 'Shop stock reservation released.') end
function Stock.Adjust(shopId, itemName, amount, direction, actor, reason) local context = actorContext(actor or { reason = reason }, 'shop.stock.adjust'); amount = normalizeAmount(amount); if not amount then return fail(NEXA_SHOP_ERRORS.invalidInput, 'Stock amount is invalid.') end; local delta = direction == 'remove' and -amount or amount; NexaShopsDatabase.AdjustStock(normalizeId(shopId), normalizeString(itemName, 64), delta); local result = ok({ shop_id = normalizeId(shopId), item_name = itemName, delta = delta }, 'Shop stock adjusted.'); audit('shop.stock.adjust', context, result, { shop_id = normalizeId(shopId) }); emit(NEXA_SHOP_EVENTS.stockChanged, result.data); return result end

function ShopTransactions.Buy(source, shopId, itemName, amount, context)
    context = actorContext(context or { source = source }, 'shop.buy')
    local shop = Shops.Get(shopId); if not shop.ok then return shop end
    if shop.data.status ~= NEXA_SHOP_STATUS.active then return fail(NEXA_SHOP_ERRORS.notActive, 'Shop is not active.') end
    local price = Pricing.ResolveBuyPrice(shop.data.id, itemName, context, amount); if not price.ok then return price end
    local reservation = Stock.Reserve(shop.data.id, itemName, price.data.amount, context); if not reservation.ok then return reservation end
    Stock.Commit(reservation.data.reservation_id, context)
    local txId, err = NexaShopsDatabase.InsertTransaction({ shop_id = shop.data.id, transaction_type = 'buy', character_id = context.actor_character_id or source, item_name = itemName, amount = price.data.amount, unit_price = price.data.unit_price, total_price = price.data.total_price, currency = NexaShopsConfig.defaultCurrency, economy_transaction_id = nil, inventory_correlation_id = context.correlation_id, status = NEXA_SHOP_TRANSACTION_STATUS.completed, idempotency_key = context.idempotency_key, correlation_id = context.correlation_id, metadata = { economy_required = 'nexa_economy', inventory_required = 'nexa_inventory' } })
    if err then return fail(NEXA_SHOP_ERRORS.transactionFailed, 'Shop purchase could not be recorded.', err) end
    local result = ok({ transaction_id = txId, shop_id = shop.data.id, item_name = itemName, amount = price.data.amount, total_price = price.data.total_price }, 'Shop purchase completed.')
    audit('shop.buy', context, result, { shop_id = shop.data.id })
    emit(NEXA_SHOP_EVENTS.purchaseCompleted, result.data)
    return result
end
function ShopTransactions.Sell(source, shopId, itemReference, amount, context) context = actorContext(context or { source = source }, 'shop.sell'); local itemName = type(itemReference) == 'table' and itemReference.item_name or itemReference; local price = Pricing.ResolveSellPrice(shopId, itemName, context, amount); if not price.ok then return price end; local txId = NexaShopsDatabase.InsertTransaction({ shop_id = normalizeId(shopId), transaction_type = 'sell', character_id = context.actor_character_id or source, item_name = itemName, amount = price.data.amount, unit_price = price.data.unit_price, total_price = price.data.total_price, currency = NexaShopsConfig.defaultCurrency, status = NEXA_SHOP_TRANSACTION_STATUS.completed, idempotency_key = context.idempotency_key, correlation_id = context.correlation_id, metadata = { economy_required = 'nexa_economy', inventory_required = 'nexa_inventory' } }); local result = ok({ transaction_id = txId, shop_id = normalizeId(shopId), item_name = itemName }, 'Shop sale completed.'); emit(NEXA_SHOP_EVENTS.saleCompleted, result.data); return result end
function ShopTransactions.Get(transactionId) local row, err = NexaShopsDatabase.GetTransaction(normalizeId(transactionId)); return err and fail(NEXA_SHOP_ERRORS.databaseError, 'Transaction could not be loaded.', err) or ok(row, 'Transaction loaded.') end
function ShopTransactions.Retry(transactionId, context) return ok({ transaction_id = normalizeId(transactionId) }, 'Transaction retry foundation recorded.') end
function ShopTransactions.Compensate(transactionId, reason) return ok({ transaction_id = normalizeId(transactionId), reason = reason }, 'Transaction compensation foundation recorded.') end

function Deliveries.Create(shopId, definition, actor) definition = type(definition) == 'table' and definition or {}; local context = actorContext(actor, 'shop.delivery.create'); local id, err = NexaShopsDatabase.InsertDelivery({ shop_id = normalizeId(shopId), item_name = normalizeString(definition.item_name, 64), amount = normalizeAmount(definition.amount) or 1, status = NEXA_SHOP_DELIVERY_STATUS.created, assigned_character_id = normalizeId(definition.assigned_character_id), organization_id = normalizeId(definition.organization_id), correlation_id = context.correlation_id, metadata = definition.metadata or {} }); if err then return fail(NEXA_SHOP_ERRORS.databaseError, 'Delivery could not be created.', err) end; return ok({ delivery_id = id, shop_id = normalizeId(shopId) }, 'Shop delivery created.') end
function Deliveries.Assign(deliveryId, characterId, actor) NexaShopsDatabase.UpdateDeliveryStatus(normalizeId(deliveryId), NEXA_SHOP_DELIVERY_STATUS.assigned, normalizeId(characterId)); return ok({ delivery_id = normalizeId(deliveryId), character_id = normalizeId(characterId) }, 'Shop delivery assigned.') end
function Deliveries.Get(deliveryId) local row, err = NexaShopsDatabase.GetDelivery(normalizeId(deliveryId)); return err and fail(NEXA_SHOP_ERRORS.databaseError, 'Delivery could not be loaded.', err) or (row and ok(row, 'Delivery loaded.') or fail(NEXA_SHOP_ERRORS.deliveryNotFound, 'Delivery not found.')) end
function Deliveries.Deliver(source, deliveryId, context) local delivery = Deliveries.Get(deliveryId); if not delivery.ok then return delivery end; NexaShopsDatabase.UpdateDeliveryStatus(delivery.data.id, NEXA_SHOP_DELIVERY_STATUS.delivered, nil); Stock.Adjust(delivery.data.shop_id, delivery.data.item_name, delivery.data.amount, 'add', context or { source = source, reason = 'delivery' }, 'delivery'); emit(NEXA_SHOP_EVENTS.deliveryCompleted, { delivery_id = delivery.data.id }); return ok({ delivery_id = delivery.data.id }, 'Shop delivery completed.') end
function Deliveries.Pickup(source, deliveryId, context) NexaShopsDatabase.UpdateDeliveryStatus(normalizeId(deliveryId), NEXA_SHOP_DELIVERY_STATUS.picked_up, nil); return ok({ delivery_id = normalizeId(deliveryId) }, 'Shop delivery picked up.') end
function Deliveries.Cancel(actor, deliveryId, reason) NexaShopsDatabase.UpdateDeliveryStatus(normalizeId(deliveryId), NEXA_SHOP_DELIVERY_STATUS.cancelled, nil); return ok({ delivery_id = normalizeId(deliveryId), reason = reason }, 'Shop delivery cancelled.') end

function ShopCreator.Create(definition, actor) return Shops.Create(definition, actor) end
function ShopCreator.Activate(shopId, actor) return Shops.Activate(shopId, actor) end
function ShopCreator.Suspend(shopId, actor, reason) return Shops.Suspend(shopId, actor, reason) end

function GetShop(...) return Shops.Get(...) end
function ListShops(...) return Shops.List(...) end
function GetShopCatalog(...) return ShopCatalog.List(...) end
function GetShopItem(...) return ShopCatalog.GetItem(...) end
function GetShopStock(...) return Stock.Get(...) end
function CanAccessShop(shopId, actor) return ok({ shop_id = normalizeId(shopId), allowed = true }, 'Shop access evaluated.') end
function BuyFromShop(...) return ShopTransactions.Buy(...) end
function SellToShop(...) return ShopTransactions.Sell(...) end
function GetShopTransaction(...) return ShopTransactions.Get(...) end
function RetryShopTransaction(...) return ShopTransactions.Retry(...) end
function CompensateShopTransaction(...) return ShopTransactions.Compensate(...) end
function AdjustShopStock(...) return Stock.Adjust(...) end
function CreateShop(...) return Shops.Create(...) end
function UpdateShop(...) return Shops.Update(...) end
function AddShopItem(...) return ShopCatalog.AddItem(...) end
function UpdateShopItem(...) return ShopCatalog.UpdateItem(...) end
function RemoveShopItem(...) return ShopCatalog.RemoveItem(...) end
function CreateShopDelivery(...) return Deliveries.Create(...) end
function AssignShopDelivery(...) return Deliveries.Assign(...) end
function CompleteShopDelivery(...) return Deliveries.Deliver(...) end

AddEventHandler('onResourceStart', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; registerDefaultTypes(); if NexaShopsConfig.autoMigrate then migrated = NexaShopsDatabase.Migrate() == true end; log('Info', 'shops.start', 'nexa_shops started.', { migrated = migrated }) end)
AddEventHandler('onResourceStop', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; stockReservations = {} end)

exports('GetShop', GetShop)
exports('ListShops', ListShops)
exports('GetShopCatalog', GetShopCatalog)
exports('GetShopItem', GetShopItem)
exports('GetShopStock', GetShopStock)
exports('CanAccessShop', CanAccessShop)
exports('BuyFromShop', BuyFromShop)
exports('SellToShop', SellToShop)
exports('GetShopTransaction', GetShopTransaction)
exports('RetryShopTransaction', RetryShopTransaction)
exports('CompensateShopTransaction', CompensateShopTransaction)
exports('AdjustShopStock', AdjustShopStock)
exports('CreateShop', CreateShop)
exports('UpdateShop', UpdateShop)
exports('AddShopItem', AddShopItem)
exports('UpdateShopItem', UpdateShopItem)
exports('RemoveShopItem', RemoveShopItem)
exports('CreateShopDelivery', CreateShopDelivery)
exports('AssignShopDelivery', AssignShopDelivery)
exports('CompleteShopDelivery', CompleteShopDelivery)
exports('getStatus', function() return { resourceName = NEXA_SHOPS.resourceName, version = NEXA_SHOPS.version, migrated = migrated, shopTypes = ShopTypes.List() } end)
exports('getSchema', NexaShopsDatabase.GetSchema)
