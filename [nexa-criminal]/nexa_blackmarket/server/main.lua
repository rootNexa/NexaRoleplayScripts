local migrated = false

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_BLACKMARKET_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeMoney(value) local amount = tonumber(value); return amount and amount > 0 and amount % 1 == 0 and math.floor(amount) or nil end
local function getCore() if GetResourceState('nexa-core') ~= 'started' then return nil end; local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return good and core or nil end
local function log(level, category, message, context) local core = getCore(); if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s %s'):format(NEXA_BLACKMARKET.resourceName, level, message, encode(context))) end
local function emit(eventName, payload) local core = getCore(); if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_BLACKMARKET.resourceName }) end end

function GetAccessibleBlackMarkets(actor) local rows, err = NexaBlackmarketDatabase.ListMarkets(); return err and fail(NEXA_BLACKMARKET_ERRORS.databaseError, 'Markets could not be listed.', err) or ok(rows or {}, 'Accessible blackmarkets listed.') end
function GetBlackMarketCatalog(marketId, actor) local market, err = NexaBlackmarketDatabase.GetMarket(marketId); if err then return fail(NEXA_BLACKMARKET_ERRORS.databaseError, 'Market could not be loaded.', err) end; if not market then return fail(NEXA_BLACKMARKET_ERRORS.notFound, 'Blackmarket not found.') end; local rows = NexaBlackmarketDatabase.ListCatalog(market.id) or {}; return ok(rows, 'Blackmarket catalog listed.') end
function BuyFromBlackMarket(source, marketId, itemName, amount, context) amount = normalizeMoney(amount) or 1; local catalog = GetBlackMarketCatalog(marketId, context); if not catalog.ok then return catalog end; emit(NEXA_BLACKMARKET_EVENTS.purchaseCompleted, { market_id = marketId, item_name = itemName, amount = amount, saga_required = true }); return ok({ market_id = marketId, item_name = itemName, amount = amount, currency = NexaBlackmarketConfig.defaultCurrency }, 'Blackmarket purchase foundation recorded.') end
function GetFenceOffer(fenceId, itemReference, actor) local base = 100; local quality = type(itemReference) == 'table' and tonumber(itemReference.quality) or nil; local price = base + (quality or 0); return ok({ fence_id = fenceId, item = itemReference, price = price, server_priced = true }, 'Fence offer generated.') end
function SellToFence(source, fenceId, itemReference, actor) local offer = GetFenceOffer(fenceId, itemReference, actor); if not offer.ok then return offer end; emit(NEXA_BLACKMARKET_EVENTS.fenceSaleCompleted, { fence_id = fenceId, price = offer.data.price, saga_required = true }); return ok({ fence_id = fenceId, price = offer.data.price, currency = NexaBlackmarketConfig.defaultCurrency }, 'Fence sale foundation recorded.') end
function BeginMoneyLaundering(source, amount, actor) amount = normalizeMoney(amount); if not amount then return fail(NEXA_BLACKMARKET_ERRORS.launderingAmountInvalid, 'Laundering amount is invalid.') end; actor = type(actor) == 'table' and actor or {}; local fee = math.floor(amount * NexaBlackmarketConfig.defaultLaunderingFeePercent / 100); local payout = amount - fee; local id, err = NexaBlackmarketDatabase.InsertLaunderingJob({ character_id = normalizeId(actor.character_id or actor.actor_character_id or source) or 0, amount = amount, fee_amount = fee, payout_amount = payout, status = 'active', completes_at = os.time() + NexaBlackmarketConfig.defaultLaunderingDurationSeconds, idempotency_key = actor.idempotency_key or ('launder:%s:%s'):format(source, os.time()), correlation_id = actor.correlation_id, metadata = { saga = true, dirty_cash = true } }); if err then return fail(NEXA_BLACKMARKET_ERRORS.databaseError, 'Laundering job could not be started.', err) end; emit(NEXA_BLACKMARKET_EVENTS.launderingStarted, { laundering_job_id = id, amount = amount, payout = payout }); return ok({ laundering_job_id = id, amount = amount, fee = fee, payout = payout }, 'Money laundering started.') end
function GetMoneyLaunderingJob(jobId) local row, err = NexaBlackmarketDatabase.GetLaunderingJob(normalizeId(jobId)); return err and fail(NEXA_BLACKMARKET_ERRORS.databaseError, 'Laundering job could not be loaded.', err) or (row and ok(row, 'Laundering job loaded.') or fail(NEXA_BLACKMARKET_ERRORS.launderingNotFound, 'Laundering job not found.')) end

AddEventHandler('onResourceStart', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; if NexaBlackmarketConfig.autoMigrate then migrated = NexaBlackmarketDatabase.Migrate() == true end; log('Info', 'blackmarket.start', 'nexa_blackmarket started.', { migrated = migrated }) end)

exports('GetAccessibleBlackMarkets', GetAccessibleBlackMarkets)
exports('GetBlackMarketCatalog', GetBlackMarketCatalog)
exports('BuyFromBlackMarket', BuyFromBlackMarket)
exports('SellToFence', SellToFence)
exports('GetFenceOffer', GetFenceOffer)
exports('BeginMoneyLaundering', BeginMoneyLaundering)
exports('GetMoneyLaunderingJob', GetMoneyLaunderingJob)
exports('getStatus', function() return { resourceName = NEXA_BLACKMARKET.resourceName, version = NEXA_BLACKMARKET.version, migrated = migrated, currency = NexaBlackmarketConfig.defaultCurrency } end)
exports('getSchema', NexaBlackmarketDatabase.GetSchema)
