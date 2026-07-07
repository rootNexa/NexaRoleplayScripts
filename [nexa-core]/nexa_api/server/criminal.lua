local criminalPermissions = {
    view = 'criminal.reputation.view',
    adjust = 'criminal.reputation.adjust',
    blackmarketView = 'criminal.blackmarket.view',
    blackmarketTrade = 'criminal.blackmarket.trade'
}

local blackmarketLimits = {
    maxCatalogIdLength = 64,
    maxDealerIdLength = 64,
    maxItemNameLength = 64,
    maxCategoryLength = 64,
    maxAmount = 100,
    maxPrice = 1000000
}

local drugLimits = {
    maxCropIdLength = 64,
    maxRecipeIdLength = 64,
    maxBuyerIdLength = 64,
    maxItemNameLength = 64,
    maxAmount = 25,
    maxPrice = 1000000,
    maxGrowthSeconds = 86400
}

local moneywashLimits = {
    maxStationIdLength = 64,
    maxItemNameLength = 64,
    maxAmount = 1000,
    maxRatePercent = 95
}

local chopshopLimits = {
    maxYardIdLength = 64,
    maxBuyerIdLength = 64,
    maxItemNameLength = 64,
    maxAmount = 25,
    maxPrice = 1000000
}

local function respond(success, code, message, data, meta, auditId)
    return NexaApiResponse(success, code, message, data, meta, auditId)
end

local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 or math.floor(number) ~= number then
        return nil
    end

    return number
end

local function normalizeText(value, fallback, maxLength)
    if value == nil then
        return fallback
    end

    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' then
        return fallback
    end

    if maxLength ~= nil and #trimmed > maxLength then
        return nil
    end

    return trimmed
end

local function normalizeAmount(value)
    local amount = tonumber(value)

    if amount == nil or amount < 1 or amount > blackmarketLimits.maxAmount or math.floor(amount) ~= amount then
        return nil
    end

    return amount
end

local function normalizePrice(value)
    local price = tonumber(value)

    if price == nil or price < 1 or price > blackmarketLimits.maxPrice or math.floor(price) ~= price then
        return nil
    end

    return price
end

local function getActor(source)
    local active = getActiveCharacter(source)

    if active == nil or not active.success or active.data == nil or active.data.character == nil then
        return nil, 'CHARACTER_NOT_LOADED'
    end

    return active.data.character, 'OK'
end

local function hasPermission(source, permission)
    if GetResourceState('nexa_permissions') ~= 'started' then
        return false
    end

    local result = exports.nexa_permissions:has(source, permission)

    return result ~= nil and result.success == true
end

local function writeCriminalAudit(action, actor, targetCharacterId, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'criminal',
        severity = 'info',
        actorPlayerId = actor and actor.player_id or nil,
        actorCharacterId = actor and actor.id or nil,
        targetType = 'character',
        targetId = targetCharacterId,
        action = action,
        resourceName = 'nexa_api',
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function createOrderNumber(prefix)
    return ('%s%s%04d'):format(prefix, os.date('%y%m%d%H%M%S'), math.random(0, 9999))
end

local function generateOrderNumber(prefix)
    for _ = 1, 10 do
        local orderNumber = createOrderNumber(prefix)
        local existing = MySQL.scalar.await('SELECT id FROM blackmarket_orders WHERE order_number = ? LIMIT 1', {
            orderNumber
        })

        if existing == nil then
            return orderNumber
        end
    end

    return nil
end

local function encodeJson(value)
    if type(value) ~= 'table' then
        return json.encode({})
    end

    return json.encode(value)
end

local function findCatalogEntry(catalog, catalogId)
    if type(catalog) ~= 'table' then
        return nil
    end

    return catalog[catalogId]
end

local function dealerAllowsItem(entry, dealerId)
    if type(entry) ~= 'table' or type(entry.dealers) ~= 'table' then
        return false
    end

    for _, allowedDealerId in ipairs(entry.dealers) do
        if allowedDealerId == dealerId then
            return true
        end
    end

    return false
end

local function normalizeBlackmarketPayload(payload)
    if type(payload) ~= 'table' then
        return nil
    end

    local catalogId = normalizeText(payload.catalogId, nil, blackmarketLimits.maxCatalogIdLength)
    local dealerId = normalizeText(payload.dealerId, nil, blackmarketLimits.maxDealerIdLength)
    local amount = normalizeAmount(payload.amount)

    if catalogId == nil or dealerId == nil or amount == nil then
        return nil
    end

    return {
        catalogId = catalogId,
        dealerId = dealerId,
        amount = amount,
        accountId = normalizeId(payload.accountId),
        accountNumber = normalizeText(payload.accountNumber, nil, 32)
    }
end

local function validateCatalogEntry(entry, dealerId, amount, mode)
    if type(entry) ~= 'table' then
        return nil, 'NOT_FOUND', 'Ware wurde nicht gefunden.'
    end

    local itemName = normalizeText(entry.itemName, nil, blackmarketLimits.maxItemNameLength)
    local category = normalizeText(entry.category, nil, blackmarketLimits.maxCategoryLength)
    local maxAmount = normalizeAmount(entry.maxAmount or blackmarketLimits.maxAmount)
    local price = normalizePrice(mode == 'buy' and entry.buyPrice or entry.sellPrice)

    if itemName == nil or category == nil or maxAmount == nil or price == nil then
        return nil, 'INVALID_INPUT', 'Ware ist ungueltig konfiguriert.'
    end

    if amount > maxAmount then
        return nil, 'INVALID_INPUT', 'Die Menge ist zu hoch.'
    end

    if not dealerAllowsItem(entry, dealerId) then
        return nil, 'NO_PERMISSION', 'Dieser Haendler bietet diese Ware nicht an.'
    end

    return {
        itemName = itemName,
        category = category,
        label = normalizeText(entry.label, itemName, 96),
        unitPrice = price,
        totalPrice = price * amount
    }, 'OK', 'OK'
end

local function insertBlackmarketOrder(actor, payload, item, mode, status)
    local orderNumber = generateOrderNumber(mode == 'buy' and 'BMK' or 'BMS')

    if orderNumber == nil then
        return nil
    end

    local orderId = MySQL.insert.await([[
        INSERT INTO blackmarket_orders (order_number, character_id, item_name, amount, price, status, metadata, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
    ]], {
        orderNumber,
        actor.id,
        item.itemName,
        payload.amount,
        item.totalPrice,
        status,
        encodeJson({
            mode = mode,
            dealerId = payload.dealerId,
            catalogId = payload.catalogId,
            category = item.category,
            unitPrice = item.unitPrice
        })
    })

    return {
        id = orderId,
        order_number = orderNumber,
        character_id = actor.id,
        item_name = item.itemName,
        amount = payload.amount,
        price = item.totalPrice,
        status = status
    }
end

local function createDrugNumber(prefix)
    return ('%s%s%04d'):format(prefix, os.date('%y%m%d%H%M%S'), math.random(0, 9999))
end

local function generateDrugBatchNumber()
    for _ = 1, 10 do
        local batchNumber = createDrugNumber('DRB')
        local existing = MySQL.scalar.await('SELECT id FROM drug_batches WHERE batch_number = ? LIMIT 1', {
            batchNumber
        })

        if existing == nil then
            return batchNumber
        end
    end

    return nil
end

local function generateDrugSaleNumber()
    for _ = 1, 10 do
        local saleNumber = createDrugNumber('DRS')
        local existing = MySQL.scalar.await('SELECT id FROM drug_sales WHERE sale_number = ? LIMIT 1', {
            saleNumber
        })

        if existing == nil then
            return saleNumber
        end
    end

    return nil
end

local function generateMoneywashNumber()
    for _ = 1, 10 do
        local transactionNumber = createDrugNumber('MWS')
        local existing = MySQL.scalar.await('SELECT id FROM moneywash_transactions WHERE transaction_number = ? LIMIT 1', {
            transactionNumber
        })

        if existing == nil then
            return transactionNumber
        end
    end

    return nil
end

local function generateChopshopNumber()
    for _ = 1, 10 do
        local orderNumber = createDrugNumber('CHP')
        local existing = MySQL.scalar.await('SELECT id FROM chopshop_orders WHERE order_number = ? LIMIT 1', {
            orderNumber
        })

        if existing == nil then
            return orderNumber
        end
    end

    return nil
end

local function normalizeDrugAmount(value, maxAmount)
    local amount = tonumber(value)
    local limit = maxAmount or drugLimits.maxAmount

    if amount == nil or amount < 1 or amount > limit or math.floor(amount) ~= amount then
        return nil
    end

    return amount
end

local function normalizeDrugPlantPayload(payload)
    if type(payload) ~= 'table' then
        return nil
    end

    local cropId = normalizeText(payload.cropId, nil, drugLimits.maxCropIdLength)

    if cropId == nil then
        return nil
    end

    return {
        cropId = cropId
    }
end

local function normalizeDrugHarvestPayload(payload)
    if type(payload) ~= 'table' then
        return nil
    end

    local batchId = normalizeId(payload.batchId)

    if batchId == nil then
        return nil
    end

    return {
        batchId = batchId
    }
end

local function normalizeDrugProcessPayload(payload)
    if type(payload) ~= 'table' then
        return nil
    end

    local recipeId = normalizeText(payload.recipeId, nil, drugLimits.maxRecipeIdLength)
    local amount = normalizeDrugAmount(payload.amount, drugLimits.maxAmount)

    if recipeId == nil or amount == nil then
        return nil
    end

    return {
        recipeId = recipeId,
        amount = amount
    }
end

local function normalizeDrugSellPayload(payload)
    if type(payload) ~= 'table' then
        return nil
    end

    local buyerId = normalizeText(payload.buyerId, nil, drugLimits.maxBuyerIdLength)
    local amount = normalizeDrugAmount(payload.amount, drugLimits.maxAmount)

    if buyerId == nil or amount == nil then
        return nil
    end

    return {
        buyerId = buyerId,
        amount = amount,
        accountId = normalizeId(payload.accountId),
        accountNumber = normalizeText(payload.accountNumber, nil, 32)
    }
end

local function getDrugCrop(crops, cropId)
    if type(crops) ~= 'table' then
        return nil
    end

    local crop = crops[cropId]

    if type(crop) ~= 'table' then
        return nil
    end

    local seedItem = normalizeText(crop.seedItem, nil, drugLimits.maxItemNameLength)
    local rawItem = normalizeText(crop.rawItem, nil, drugLimits.maxItemNameLength)
    local growthSeconds = tonumber(crop.growthSeconds)
    local harvestAmount = normalizeDrugAmount(crop.harvestAmount, drugLimits.maxAmount)

    if seedItem == nil or rawItem == nil or growthSeconds == nil or growthSeconds < 1
        or growthSeconds > drugLimits.maxGrowthSeconds or math.floor(growthSeconds) ~= growthSeconds
        or harvestAmount == nil then
        return nil
    end

    return {
        cropId = cropId,
        seedItem = seedItem,
        rawItem = rawItem,
        growthSeconds = growthSeconds,
        harvestAmount = harvestAmount,
        maxActive = normalizeDrugAmount(crop.maxActive, 25) or 3,
        reputationType = normalizeText(crop.reputationType, 'drugs', 32),
        reputationDelta = tonumber(crop.reputationDelta) or 0
    }
end

local function getDrugRecipe(recipes, recipeId)
    if type(recipes) ~= 'table' then
        return nil
    end

    local recipe = recipes[recipeId]

    if type(recipe) ~= 'table' then
        return nil
    end

    local inputItem = normalizeText(recipe.inputItem, nil, drugLimits.maxItemNameLength)
    local outputItem = normalizeText(recipe.outputItem, nil, drugLimits.maxItemNameLength)
    local inputAmount = normalizeDrugAmount(recipe.inputAmount, drugLimits.maxAmount)
    local outputAmount = normalizeDrugAmount(recipe.outputAmount, drugLimits.maxAmount)

    if inputItem == nil or outputItem == nil or inputAmount == nil or outputAmount == nil then
        return nil
    end

    return {
        recipeId = recipeId,
        inputItem = inputItem,
        inputAmount = inputAmount,
        outputItem = outputItem,
        outputAmount = outputAmount,
        reputationType = normalizeText(recipe.reputationType, 'drugs', 32),
        reputationDelta = tonumber(recipe.reputationDelta) or 0
    }
end

local function getDrugBuyer(buyers, buyerId, amount)
    if type(buyers) ~= 'table' then
        return nil
    end

    local buyer = buyers[buyerId]

    if type(buyer) ~= 'table' then
        return nil
    end

    local itemName = normalizeText(buyer.itemName, nil, drugLimits.maxItemNameLength)
    local unitPrice = normalizePrice(buyer.unitPrice)
    local maxAmount = normalizeDrugAmount(buyer.maxAmount or drugLimits.maxAmount, drugLimits.maxAmount)

    if itemName == nil or unitPrice == nil or maxAmount == nil or amount > maxAmount then
        return nil
    end

    return {
        buyerId = buyerId,
        itemName = itemName,
        unitPrice = unitPrice,
        totalPrice = unitPrice * amount,
        reputationType = normalizeText(buyer.reputationType, 'drugs', 32),
        reputationDelta = tonumber(buyer.reputationDelta) or 0
    }
end

local function normalizeMoneywashAmount(value)
    local amount = tonumber(value)

    if amount == nil or amount < 1 or amount > moneywashLimits.maxAmount or math.floor(amount) ~= amount then
        return nil
    end

    return amount
end

local function normalizeMoneywashPayload(payload)
    if type(payload) ~= 'table' then
        return nil
    end

    local stationId = normalizeText(payload.stationId, nil, moneywashLimits.maxStationIdLength)
    local amount = normalizeMoneywashAmount(payload.amount)

    if stationId == nil or amount == nil then
        return nil
    end

    return {
        stationId = stationId,
        amount = amount,
        accountId = normalizeId(payload.accountId),
        accountNumber = normalizeText(payload.accountNumber, nil, 32)
    }
end

local function getMoneywashStation(stations, stationId, amount)
    if type(stations) ~= 'table' then
        return nil
    end

    local station = stations[stationId]

    if type(station) ~= 'table' then
        return nil
    end

    local dirtyItem = normalizeText(station.dirtyItem, nil, moneywashLimits.maxItemNameLength)
    local ratePercent = tonumber(station.ratePercent)
    local minAmount = normalizeMoneywashAmount(station.minAmount or 1)
    local maxAmount = normalizeMoneywashAmount(station.maxAmount or moneywashLimits.maxAmount)

    if dirtyItem == nil or ratePercent == nil or ratePercent < 1 or ratePercent > moneywashLimits.maxRatePercent
        or math.floor(ratePercent) ~= ratePercent or minAmount == nil or maxAmount == nil
        or amount < minAmount or amount > maxAmount then
        return nil
    end

    local cleanAmount = math.floor(amount * ratePercent / 100)
    local feeAmount = amount - cleanAmount

    if cleanAmount < 1 then
        return nil
    end

    return {
        stationId = stationId,
        dirtyItem = dirtyItem,
        ratePercent = ratePercent,
        cleanAmount = cleanAmount,
        feeAmount = feeAmount,
        reputationType = normalizeText(station.reputationType, 'moneywash', 32),
        reputationDelta = tonumber(station.reputationDelta) or 0
    }
end

local function normalizeChopshopAmount(value)
    local amount = tonumber(value)

    if amount == nil or amount < 1 or amount > chopshopLimits.maxAmount or math.floor(amount) ~= amount then
        return nil
    end

    return amount
end

local function normalizeChopshopDismantlePayload(payload)
    if type(payload) ~= 'table' then
        return nil
    end

    local yardId = normalizeText(payload.yardId, nil, chopshopLimits.maxYardIdLength)
    local vehicleId = normalizeId(payload.vehicleId)

    if yardId == nil or vehicleId == nil then
        return nil
    end

    return {
        yardId = yardId,
        vehicleId = vehicleId
    }
end

local function normalizeChopshopSellPayload(payload)
    if type(payload) ~= 'table' then
        return nil
    end

    local buyerId = normalizeText(payload.buyerId, nil, chopshopLimits.maxBuyerIdLength)
    local itemName = normalizeText(payload.itemName, nil, chopshopLimits.maxItemNameLength)
    local amount = normalizeChopshopAmount(payload.amount)

    if buyerId == nil or itemName == nil or amount == nil then
        return nil
    end

    return {
        buyerId = buyerId,
        itemName = itemName,
        amount = amount,
        accountId = normalizeId(payload.accountId),
        accountNumber = normalizeText(payload.accountNumber, nil, 32)
    }
end

local function getChopshopYard(yards, yardId)
    if type(yards) ~= 'table' then
        return nil
    end

    local yard = yards[yardId]

    if type(yard) ~= 'table' or type(yard.rewards) ~= 'table' then
        return nil
    end

    local rewards = {}

    for _, reward in ipairs(yard.rewards) do
        local itemName = normalizeText(reward.itemName, nil, chopshopLimits.maxItemNameLength)
        local count = normalizeChopshopAmount(reward.count)

        if itemName == nil or count == nil then
            return nil
        end

        rewards[#rewards + 1] = {
            itemName = itemName,
            count = count
        }
    end

    if #rewards < 1 then
        return nil
    end

    return {
        yardId = yardId,
        allowedStatuses = type(yard.allowedStatuses) == 'table' and yard.allowedStatuses or { active = true },
        rewards = rewards,
        reputationType = normalizeText(yard.reputationType, 'chopshop', 32),
        reputationDelta = tonumber(yard.reputationDelta) or 0
    }
end

local function getChopshopBuyer(buyers, buyerId, itemName, amount)
    if type(buyers) ~= 'table' then
        return nil
    end

    local buyer = buyers[buyerId]

    if type(buyer) ~= 'table' or type(buyer.items) ~= 'table' then
        return nil
    end

    local unitPrice = tonumber(buyer.items[itemName])
    local maxAmount = normalizeChopshopAmount(buyer.maxAmount or chopshopLimits.maxAmount)

    if unitPrice == nil or unitPrice < 1 or unitPrice > chopshopLimits.maxPrice
        or math.floor(unitPrice) ~= unitPrice or maxAmount == nil or amount > maxAmount then
        return nil
    end

    return {
        buyerId = buyerId,
        itemName = itemName,
        amount = amount,
        unitPrice = unitPrice,
        totalPrice = unitPrice * amount,
        reputationType = normalizeText(buyer.reputationType, 'chopshop', 32),
        reputationDelta = tonumber(buyer.reputationDelta) or 0
    }
end

local function getReputationRow(characterId, reputationType)
    return MySQL.single.await([[
        SELECT id, character_id, reputation_type, reputation_score, risk_level, metadata, created_at, updated_at
        FROM illegal_reputation
        WHERE character_id = ? AND reputation_type = ?
        LIMIT 1
    ]], {
        characterId,
        reputationType
    })
end

function getCriminalReputation(source, payload)
    payload = payload or {}

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Reputationsanfrage.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local characterId = normalizeId(payload.characterId) or actor.id
    local reputationType = normalizeText(payload.reputationType, 'general', 32)

    if reputationType == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Reputationstyp.', nil, nil, nil)
    end

    if characterId ~= actor.id and not hasPermission(source, criminalPermissions.view) then
        return respond(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, nil)
    end

    local row = getReputationRow(characterId, reputationType)

    return respond(true, 'OK', 'Illegale Reputation wurde geladen.', {
        reputation = row or {
            character_id = characterId,
            reputation_type = reputationType,
            reputation_score = 0,
            risk_level = 'low',
            metadata = '{}'
        }
    }, nil, nil)
end

function adjustCriminalReputation(source, payload)
    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Reputationsdaten.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if not hasPermission(source, criminalPermissions.adjust) then
        return respond(false, 'NO_PERMISSION', 'Du darfst diese Reputation nicht aendern.', nil, nil, nil)
    end

    local characterId = normalizeId(payload.characterId)
    local reputationType = normalizeText(payload.reputationType, 'general', 32)
    local reason = normalizeText(payload.reason, 'illegal_core', 255)
    local delta = tonumber(payload.delta)

    if characterId == nil or reputationType == nil or reason == nil or delta == nil or math.floor(delta) ~= delta then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Reputationsdaten.', nil, nil, nil)
    end

    local current = getReputationRow(characterId, reputationType)
    local currentScore = current and tonumber(current.reputation_score) or 0
    local nextScore = math.max(0, math.min(1000, currentScore + delta))
    local riskLevel = 'low'

    if nextScore >= 750 then
        riskLevel = 'high'
    elseif nextScore >= 350 then
        riskLevel = 'medium'
    end

    local metadata = json.encode({
        lastReason = reason,
        lastDelta = delta,
        updatedBy = actor.id
    })

    MySQL.insert.await([[
        INSERT INTO illegal_reputation (character_id, reputation_type, reputation_score, risk_level, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, NOW(), NOW())
        ON DUPLICATE KEY UPDATE
            reputation_score = VALUES(reputation_score),
            risk_level = VALUES(risk_level),
            metadata = VALUES(metadata),
            updated_at = NOW()
    ]], {
        characterId,
        reputationType,
        nextScore,
        riskLevel,
        metadata
    })

    local auditId = writeCriminalAudit('criminal.reputationAdjusted', actor, characterId, {
        reputationType = reputationType,
        previousScore = currentScore,
        nextScore = nextScore,
        delta = delta,
        reason = reason
    })

    return respond(true, 'UPDATED', 'Illegale Reputation wurde aktualisiert.', {
        reputation = getReputationRow(characterId, reputationType)
    }, nil, auditId)
end

local function adjustActorDrugReputation(actor, reputationType, delta, reason)
    local normalizedType = normalizeText(reputationType, 'drugs', 32)
    local normalizedDelta = tonumber(delta) or 0

    if actor == nil or normalizedType == nil or normalizedDelta == 0 then
        return nil
    end

    local current = getReputationRow(actor.id, normalizedType)
    local currentScore = current and tonumber(current.reputation_score) or 0
    local nextScore = math.max(0, math.min(1000, currentScore + normalizedDelta))
    local riskLevel = 'low'

    if nextScore >= 750 then
        riskLevel = 'high'
    elseif nextScore >= 350 then
        riskLevel = 'medium'
    end

    MySQL.insert.await([[
        INSERT INTO illegal_reputation (character_id, reputation_type, reputation_score, risk_level, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, NOW(), NOW())
        ON DUPLICATE KEY UPDATE
            reputation_score = VALUES(reputation_score),
            risk_level = VALUES(risk_level),
            metadata = VALUES(metadata),
            updated_at = NOW()
    ]], {
        actor.id,
        normalizedType,
        nextScore,
        riskLevel,
        encodeJson({
            lastReason = reason,
            lastDelta = normalizedDelta,
            updatedBy = 'nexa_api.criminal'
        })
    })

    return {
        reputationType = normalizedType,
        previousScore = currentScore,
        nextScore = nextScore,
        delta = normalizedDelta
    }
end

function plantDrugCrop(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local normalized = normalizeDrugPlantPayload(payload)

    if normalized == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Pflanzdaten.', nil, nil, nil)
    end

    local crop = getDrugCrop(payload.crops, normalized.cropId)

    if crop == nil then
        return respond(false, 'INVALID_INPUT', 'Pflanze ist ungueltig konfiguriert.', nil, nil, nil)
    end

    local activeCount = tonumber(MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM drug_batches
        WHERE character_id = ? AND crop_id = ? AND status = 'planted'
    ]], {
        actor.id,
        crop.cropId
    })) or 0

    if activeCount >= crop.maxActive then
        return respond(false, 'CONFLICT', 'Zu viele aktive Pflanzen.', nil, nil, nil)
    end

    local removeSeed = exports.nexa_api['inventory.removeItem'](source, {
        itemName = crop.seedItem,
        count = 1,
        audit = {
            reason = 'drugs.plant',
            cropId = crop.cropId
        }
    })

    if removeSeed == nil or not removeSeed.success then
        return removeSeed or respond(false, 'INTERNAL_ERROR', 'Saatgut konnte nicht entfernt werden.', nil, nil, nil)
    end

    local batchNumber = generateDrugBatchNumber()

    if batchNumber == nil then
        exports.nexa_api['inventory.addItem'](source, {
            itemName = crop.seedItem,
            count = 1,
            audit = {
                reason = 'drugs.plant_restore',
                cropId = crop.cropId
            }
        })

        return respond(false, 'INTERNAL_ERROR', 'Batch konnte nicht erstellt werden.', nil, nil, nil)
    end

    local readyAtUnix = os.time() + crop.growthSeconds
    local batchId = MySQL.insert.await([[
        INSERT INTO drug_batches (batch_number, character_id, batch_type, crop_id, item_name, amount, status, metadata, ready_at, created_at, updated_at)
        VALUES (?, ?, 'plant', ?, ?, ?, 'planted', ?, FROM_UNIXTIME(?), NOW(), NOW())
    ]], {
        batchNumber,
        actor.id,
        crop.cropId,
        crop.rawItem,
        crop.harvestAmount,
        encodeJson({
            seedItem = crop.seedItem,
            growthSeconds = crop.growthSeconds
        }),
        readyAtUnix
    })

    local reputation = adjustActorDrugReputation(actor, crop.reputationType, crop.reputationDelta, 'drugs.plant')
    local auditId = writeCriminalAudit('criminal.drugsPlant', actor, actor.id, {
        batchId = batchId,
        cropId = crop.cropId,
        seedItem = crop.seedItem,
        rawItem = crop.rawItem,
        harvestAmount = crop.harvestAmount,
        reputation = reputation
    })

    return respond(true, 'OK', 'Pflanze wurde gesetzt.', {
        batch = {
            id = batchId,
            batch_number = batchNumber,
            crop_id = crop.cropId,
            status = 'planted',
            ready_at = readyAtUnix
        }
    }, nil, auditId)
end

function harvestDrugCrop(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local normalized = normalizeDrugHarvestPayload(payload)

    if normalized == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Erntedaten.', nil, nil, nil)
    end

    local batch = MySQL.single.await([[
        SELECT id, batch_number, character_id, crop_id, item_name, amount, status, ready_at
        FROM drug_batches
        WHERE id = ? AND character_id = ? AND batch_type = 'plant'
        LIMIT 1
    ]], {
        normalized.batchId,
        actor.id
    })

    if batch == nil then
        return respond(false, 'NOT_FOUND', 'Pflanze wurde nicht gefunden.', nil, nil, nil)
    end

    if batch.status ~= 'planted' then
        return respond(false, 'CONFLICT', 'Pflanze kann nicht geerntet werden.', nil, nil, nil)
    end

    local ready = MySQL.scalar.await('SELECT CASE WHEN ready_at <= NOW() THEN 1 ELSE 0 END FROM drug_batches WHERE id = ? LIMIT 1', {
        batch.id
    })

    if tonumber(ready) ~= 1 then
        return respond(false, 'CONFLICT', 'Pflanze ist noch nicht erntereif.', nil, nil, nil)
    end

    local crop = getDrugCrop(payload.crops, batch.crop_id)

    if crop == nil then
        return respond(false, 'INVALID_INPUT', 'Pflanze ist ungueltig konfiguriert.', nil, nil, nil)
    end

    local addRaw = exports.nexa_api['inventory.addItem'](source, {
        itemName = crop.rawItem,
        count = tonumber(batch.amount),
        audit = {
            reason = 'drugs.harvest',
            cropId = crop.cropId,
            batchId = batch.id
        }
    })

    if addRaw == nil or not addRaw.success then
        return addRaw or respond(false, 'INTERNAL_ERROR', 'Ernte konnte nicht uebergeben werden.', nil, nil, nil)
    end

    MySQL.update.await([[
        UPDATE drug_batches
        SET status = 'harvested', completed_at = NOW(), updated_at = NOW()
        WHERE id = ? AND character_id = ? AND status = 'planted'
    ]], {
        batch.id,
        actor.id
    })

    local reputation = adjustActorDrugReputation(actor, crop.reputationType, crop.reputationDelta, 'drugs.harvest')
    local auditId = writeCriminalAudit('criminal.drugsHarvest', actor, actor.id, {
        batchId = batch.id,
        cropId = crop.cropId,
        itemName = crop.rawItem,
        amount = tonumber(batch.amount),
        reputation = reputation
    })

    return respond(true, 'OK', 'Ernte abgeschlossen.', {
        batch = {
            id = batch.id,
            batch_number = batch.batch_number,
            status = 'harvested'
        }
    }, nil, auditId)
end

function processDrugItems(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local normalized = normalizeDrugProcessPayload(payload)

    if normalized == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Verarbeitungsdaten.', nil, nil, nil)
    end

    local recipe = getDrugRecipe(payload.recipes, normalized.recipeId)

    if recipe == nil then
        return respond(false, 'INVALID_INPUT', 'Rezept ist ungueltig konfiguriert.', nil, nil, nil)
    end

    local inputCount = recipe.inputAmount * normalized.amount
    local outputCount = recipe.outputAmount * normalized.amount
    local removeInput = exports.nexa_api['inventory.removeItem'](source, {
        itemName = recipe.inputItem,
        count = inputCount,
        audit = {
            reason = 'drugs.process',
            recipeId = recipe.recipeId
        }
    })

    if removeInput == nil or not removeInput.success then
        return removeInput or respond(false, 'INTERNAL_ERROR', 'Eingangswaren konnten nicht entfernt werden.', nil, nil, nil)
    end

    local addOutput = exports.nexa_api['inventory.addItem'](source, {
        itemName = recipe.outputItem,
        count = outputCount,
        audit = {
            reason = 'drugs.process',
            recipeId = recipe.recipeId
        }
    })

    if addOutput == nil or not addOutput.success then
        exports.nexa_api['inventory.addItem'](source, {
            itemName = recipe.inputItem,
            count = inputCount,
            audit = {
                reason = 'drugs.process_restore',
                recipeId = recipe.recipeId
            }
        })

        return addOutput or respond(false, 'INTERNAL_ERROR', 'Verarbeitete Ware konnte nicht uebergeben werden.', nil, nil, nil)
    end

    local batchNumber = generateDrugBatchNumber()
    local batchId = nil

    if batchNumber ~= nil then
        batchId = MySQL.insert.await([[
            INSERT INTO drug_batches (batch_number, character_id, batch_type, recipe_id, item_name, amount, status, metadata, created_at, updated_at, completed_at)
            VALUES (?, ?, 'processed', ?, ?, ?, 'processed', ?, NOW(), NOW(), NOW())
        ]], {
            batchNumber,
            actor.id,
            recipe.recipeId,
            recipe.outputItem,
            outputCount,
            encodeJson({
                inputItem = recipe.inputItem,
                inputAmount = inputCount
            })
        })
    end

    local reputation = adjustActorDrugReputation(actor, recipe.reputationType, recipe.reputationDelta * normalized.amount, 'drugs.process')
    local auditId = writeCriminalAudit('criminal.drugsProcess', actor, actor.id, {
        batchId = batchId,
        recipeId = recipe.recipeId,
        inputItem = recipe.inputItem,
        inputAmount = inputCount,
        outputItem = recipe.outputItem,
        outputAmount = outputCount,
        reputation = reputation
    })

    return respond(true, 'OK', 'Verarbeitung abgeschlossen.', {
        batch = {
            id = batchId,
            batch_number = batchNumber,
            status = 'processed'
        }
    }, nil, auditId)
end

function sellDrugItems(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local normalized = normalizeDrugSellPayload(payload)

    if normalized == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Verkaufsdaten.', nil, nil, nil)
    end

    local buyer = getDrugBuyer(payload.buyers, normalized.buyerId, normalized.amount)

    if buyer == nil then
        return respond(false, 'INVALID_INPUT', 'Kontakt ist ungueltig konfiguriert.', nil, nil, nil)
    end

    local removeItem = exports.nexa_api['inventory.removeItem'](source, {
        itemName = buyer.itemName,
        count = normalized.amount,
        audit = {
            reason = 'drugs.sell',
            buyerId = buyer.buyerId
        }
    })

    if removeItem == nil or not removeItem.success then
        return removeItem or respond(false, 'INTERNAL_ERROR', 'Ware konnte nicht entfernt werden.', nil, nil, nil)
    end

    local transactionId = ('drug_sale_%s_%s_%04d'):format(actor.id, os.time(), math.random(0, 9999))
    local credit = exports.nexa_api['account.addSystemMoney'](source, {
        accountId = normalized.accountId,
        accountNumber = normalized.accountNumber,
        amount = buyer.totalPrice,
        reason = 'Drogenverkauf',
        category = 'drug_sale',
        transactionId = transactionId,
        metadata = {
            buyerId = buyer.buyerId,
            itemName = buyer.itemName,
            amount = normalized.amount
        }
    })

    if credit == nil or not credit.success then
        exports.nexa_api['inventory.addItem'](source, {
            itemName = buyer.itemName,
            count = normalized.amount,
            audit = {
                reason = 'drugs.sell_restore',
                buyerId = buyer.buyerId
            }
        })

        return credit or respond(false, 'INTERNAL_ERROR', 'Auszahlung konnte nicht ausgefuehrt werden.', nil, nil, nil)
    end

    local saleNumber = generateDrugSaleNumber()
    local saleId = nil

    if saleNumber ~= nil then
        saleId = MySQL.insert.await([[
            INSERT INTO drug_sales (sale_number, character_id, buyer_id, item_name, amount, price, status, metadata, created_at)
            VALUES (?, ?, ?, ?, ?, ?, 'completed', ?, NOW())
        ]], {
            saleNumber,
            actor.id,
            buyer.buyerId,
            buyer.itemName,
            normalized.amount,
            buyer.totalPrice,
            encodeJson({
                unitPrice = buyer.unitPrice,
                transactionId = transactionId
            })
        })
    end

    local reputation = adjustActorDrugReputation(actor, buyer.reputationType, buyer.reputationDelta * normalized.amount, 'drugs.sell')
    local auditId = writeCriminalAudit('criminal.drugsSell', actor, actor.id, {
        saleId = saleId,
        buyerId = buyer.buyerId,
        itemName = buyer.itemName,
        amount = normalized.amount,
        price = buyer.totalPrice,
        reputation = reputation
    })

    return respond(true, 'OK', 'Verkauf abgeschlossen.', {
        sale = {
            id = saleId,
            sale_number = saleNumber,
            status = 'completed'
        }
    }, nil, auditId)
end

function washDirtyMoney(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local normalized = normalizeMoneywashPayload(payload)

    if normalized == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Waschdaten.', nil, nil, nil)
    end

    local station = getMoneywashStation(payload.stations, normalized.stationId, normalized.amount)

    if station == nil then
        return respond(false, 'INVALID_INPUT', 'Waschstation ist ungueltig konfiguriert.', nil, nil, nil)
    end

    local removeDirty = exports.nexa_api['inventory.removeItem'](source, {
        itemName = station.dirtyItem,
        count = normalized.amount,
        audit = {
            reason = 'moneywash.wash',
            stationId = station.stationId
        }
    })

    if removeDirty == nil or not removeDirty.success then
        return removeDirty or respond(false, 'INTERNAL_ERROR', 'Dirty Money konnte nicht entfernt werden.', nil, nil, nil)
    end

    local transactionNumber = generateMoneywashNumber()

    if transactionNumber == nil then
        exports.nexa_api['inventory.addItem'](source, {
            itemName = station.dirtyItem,
            count = normalized.amount,
            audit = {
                reason = 'moneywash.restore',
                stationId = station.stationId
            }
        })

        return respond(false, 'INTERNAL_ERROR', 'Waschvorgang konnte nicht erstellt werden.', nil, nil, nil)
    end

    local transactionId = ('moneywash_%s_%s'):format(actor.id, transactionNumber)
    local credit = exports.nexa_api['account.addSystemMoney'](source, {
        accountId = normalized.accountId,
        accountNumber = normalized.accountNumber,
        amount = station.cleanAmount,
        reason = 'Geldwaesche',
        category = 'moneywash_clean',
        transactionId = transactionId,
        metadata = {
            stationId = station.stationId,
            dirtyItem = station.dirtyItem,
            dirtyAmount = normalized.amount,
            cleanAmount = station.cleanAmount,
            feeAmount = station.feeAmount,
            ratePercent = station.ratePercent
        }
    })

    if credit == nil or not credit.success then
        exports.nexa_api['inventory.addItem'](source, {
            itemName = station.dirtyItem,
            count = normalized.amount,
            audit = {
                reason = 'moneywash.restore',
                stationId = station.stationId
            }
        })

        return credit or respond(false, 'INTERNAL_ERROR', 'Clean Money konnte nicht gebucht werden.', nil, nil, nil)
    end

    local ledgerId = credit.data and credit.data.ledger and credit.data.ledger.id or nil
    local transactionIdDb = MySQL.insert.await([[
        INSERT INTO moneywash_transactions (
            transaction_number, character_id, station_id, dirty_item_name, dirty_amount,
            clean_amount, fee_amount, rate_percent, status, ledger_id, metadata, created_at, completed_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'completed', ?, ?, NOW(), NOW())
    ]], {
        transactionNumber,
        actor.id,
        station.stationId,
        station.dirtyItem,
        normalized.amount,
        station.cleanAmount,
        station.feeAmount,
        station.ratePercent,
        ledgerId,
        encodeJson({
            transactionId = transactionId,
            accountId = normalized.accountId,
            accountNumber = normalized.accountNumber
        })
    })

    local reputation = adjustActorDrugReputation(actor, station.reputationType, station.reputationDelta, 'moneywash.wash')
    local auditId = writeCriminalAudit('criminal.moneywashWash', actor, actor.id, {
        transactionId = transactionIdDb,
        transactionNumber = transactionNumber,
        stationId = station.stationId,
        dirtyItem = station.dirtyItem,
        dirtyAmount = normalized.amount,
        cleanAmount = station.cleanAmount,
        feeAmount = station.feeAmount,
        ledgerId = ledgerId,
        reputation = reputation
    })

    return respond(true, 'OK', 'Geldwaesche abgeschlossen.', {
        transaction = {
            id = transactionIdDb,
            transaction_number = transactionNumber,
            status = 'completed',
            ledger_id = ledgerId,
            dirty_amount = normalized.amount,
            clean_amount = station.cleanAmount,
            fee_amount = station.feeAmount
        }
    }, nil, auditId)
end

function dismantleChopshopVehicle(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local normalized = normalizeChopshopDismantlePayload(payload)

    if normalized == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Zerlegedaten.', nil, nil, nil)
    end

    local yard = getChopshopYard(payload.yards, normalized.yardId)

    if yard == nil then
        return respond(false, 'INVALID_INPUT', 'Chopshop ist ungueltig konfiguriert.', nil, nil, nil)
    end

    local vehicle = MySQL.single.await([[
        SELECT id, owner_character_id, plate, model, vehicle_type, status, garage_name, deleted_at
        FROM vehicles
        WHERE id = ? AND deleted_at IS NULL
        LIMIT 1
    ]], {
        normalized.vehicleId
    })

    if vehicle == nil then
        return respond(false, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.', nil, nil, nil)
    end

    if not yard.allowedStatuses[vehicle.status] then
        return respond(false, 'CONFLICT', 'Fahrzeugstatus erlaubt kein Zerlegen.', nil, nil, nil)
    end

    local duplicate = MySQL.scalar.await([[
        SELECT id
        FROM chopshop_orders
        WHERE vehicle_id = ? AND order_type = 'dismantle' AND status = 'completed'
        LIMIT 1
    ]], {
        vehicle.id
    })

    if duplicate ~= nil then
        return respond(false, 'CONFLICT', 'Fahrzeug wurde bereits verwertet.', nil, nil, nil)
    end

    local orderNumber = generateChopshopNumber()

    if orderNumber == nil then
        return respond(false, 'INTERNAL_ERROR', 'Chopshop-Auftrag konnte nicht erstellt werden.', nil, nil, nil)
    end

    local updated = MySQL.update.await([[
        UPDATE vehicles
        SET status = 'deleted', deleted_at = NOW(), updated_at = NOW()
        WHERE id = ? AND deleted_at IS NULL AND status NOT IN ('impounded', 'seized', 'deleted')
    ]], {
        vehicle.id
    }) or 0

    if updated < 1 then
        return respond(false, 'CONFLICT', 'Fahrzeug konnte nicht gesichert werden.', nil, nil, nil)
    end

    MySQL.insert.await([[
        INSERT INTO vehicle_history (vehicle_id, event_type, actor_character_id, old_value, new_value, reason)
        VALUES (?, 'chopshop.dismantle', ?, ?, ?, 'chopshop.dismantle')
    ]], {
        vehicle.id,
        actor.id,
        encodeJson({
            status = vehicle.status,
            garageName = vehicle.garage_name
        }),
        encodeJson({
            status = 'deleted',
            yardId = yard.yardId
        })
    })

    local orderId = MySQL.insert.await([[
        INSERT INTO chopshop_orders (order_number, character_id, order_type, vehicle_id, amount, price, status, metadata, created_at, completed_at)
        VALUES (?, ?, 'dismantle', ?, 1, 0, 'completed', ?, NOW(), NOW())
    ]], {
        orderNumber,
        actor.id,
        vehicle.id,
        encodeJson({
            yardId = yard.yardId,
            plate = vehicle.plate,
            model = vehicle.model,
            vehicleType = vehicle.vehicle_type,
            rewards = yard.rewards
        })
    })

    local granted = {}

    for _, reward in ipairs(yard.rewards) do
        local addItem = exports.nexa_api['inventory.addItem'](source, {
            itemName = reward.itemName,
            count = reward.count,
            audit = {
                reason = 'chopshop.dismantle',
                yardId = yard.yardId,
                vehicleId = vehicle.id,
                orderId = orderId
            }
        })

        if addItem == nil or not addItem.success then
            for _, grantedReward in ipairs(granted) do
                exports.nexa_api['inventory.removeItem'](source, {
                    itemName = grantedReward.itemName,
                    count = grantedReward.count,
                    audit = {
                        reason = 'chopshop.dismantle_restore',
                        yardId = yard.yardId,
                        vehicleId = vehicle.id,
                        orderId = orderId
                    }
                })
            end

            MySQL.update.await([[
                UPDATE vehicles
                SET status = ?, deleted_at = NULL, updated_at = NOW()
                WHERE id = ?
            ]], {
                vehicle.status,
                vehicle.id
            })

            MySQL.update.await("UPDATE chopshop_orders SET status = 'failed' WHERE id = ?", {
                orderId
            })

            return addItem or respond(false, 'INTERNAL_ERROR', 'Teile konnten nicht uebergeben werden.', nil, nil, nil)
        end

        granted[#granted + 1] = reward
    end

    local reputation = adjustActorDrugReputation(actor, yard.reputationType, yard.reputationDelta, 'chopshop.dismantle')
    local auditId = writeCriminalAudit('criminal.chopshopDismantle', actor, actor.id, {
        orderId = orderId,
        orderNumber = orderNumber,
        yardId = yard.yardId,
        vehicleId = vehicle.id,
        plate = vehicle.plate,
        model = vehicle.model,
        rewards = granted,
        reputation = reputation
    })

    return respond(true, 'OK', 'Fahrzeug wurde zerlegt.', {
        order = {
            id = orderId,
            order_number = orderNumber,
            status = 'completed',
            vehicle_id = vehicle.id,
            rewards = granted
        }
    }, nil, auditId)
end

function sellChopshopParts(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local normalized = normalizeChopshopSellPayload(payload)

    if normalized == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Verkaufsdaten.', nil, nil, nil)
    end

    local buyer = getChopshopBuyer(payload.buyers, normalized.buyerId, normalized.itemName, normalized.amount)

    if buyer == nil then
        return respond(false, 'INVALID_INPUT', 'Teilekontakt ist ungueltig konfiguriert.', nil, nil, nil)
    end

    local removeItem = exports.nexa_api['inventory.removeItem'](source, {
        itemName = buyer.itemName,
        count = buyer.amount,
        audit = {
            reason = 'chopshop.sell',
            buyerId = buyer.buyerId
        }
    })

    if removeItem == nil or not removeItem.success then
        return removeItem or respond(false, 'INTERNAL_ERROR', 'Teile konnten nicht entfernt werden.', nil, nil, nil)
    end

    local orderNumber = generateChopshopNumber()

    if orderNumber == nil then
        exports.nexa_api['inventory.addItem'](source, {
            itemName = buyer.itemName,
            count = buyer.amount,
            audit = {
                reason = 'chopshop.sell_restore',
                buyerId = buyer.buyerId
            }
        })

        return respond(false, 'INTERNAL_ERROR', 'Chopshop-Verkauf konnte nicht erstellt werden.', nil, nil, nil)
    end

    local transactionId = ('chopshop_sell_%s_%s'):format(actor.id, orderNumber)
    local credit = exports.nexa_api['account.addSystemMoney'](source, {
        accountId = normalized.accountId,
        accountNumber = normalized.accountNumber,
        amount = buyer.totalPrice,
        reason = 'Chopshop-Teileverkauf',
        category = 'chopshop_sale',
        transactionId = transactionId,
        metadata = {
            buyerId = buyer.buyerId,
            itemName = buyer.itemName,
            amount = buyer.amount,
            unitPrice = buyer.unitPrice
        }
    })

    if credit == nil or not credit.success then
        exports.nexa_api['inventory.addItem'](source, {
            itemName = buyer.itemName,
            count = buyer.amount,
            audit = {
                reason = 'chopshop.sell_restore',
                buyerId = buyer.buyerId
            }
        })

        return credit or respond(false, 'INTERNAL_ERROR', 'Auszahlung konnte nicht ausgefuehrt werden.', nil, nil, nil)
    end

    local ledgerId = credit.data and credit.data.ledger and credit.data.ledger.id or nil
    local orderId = MySQL.insert.await([[
        INSERT INTO chopshop_orders (order_number, character_id, order_type, item_name, amount, price, status, metadata, created_at, completed_at)
        VALUES (?, ?, 'sale', ?, ?, ?, 'completed', ?, NOW(), NOW())
    ]], {
        orderNumber,
        actor.id,
        buyer.itemName,
        buyer.amount,
        buyer.totalPrice,
        encodeJson({
            buyerId = buyer.buyerId,
            unitPrice = buyer.unitPrice,
            transactionId = transactionId,
            ledgerId = ledgerId
        })
    })

    local reputation = adjustActorDrugReputation(actor, buyer.reputationType, buyer.reputationDelta * buyer.amount, 'chopshop.sell')
    local auditId = writeCriminalAudit('criminal.chopshopSell', actor, actor.id, {
        orderId = orderId,
        orderNumber = orderNumber,
        buyerId = buyer.buyerId,
        itemName = buyer.itemName,
        amount = buyer.amount,
        price = buyer.totalPrice,
        ledgerId = ledgerId,
        reputation = reputation
    })

    return respond(true, 'OK', 'Teileverkauf abgeschlossen.', {
        order = {
            id = orderId,
            order_number = orderNumber,
            status = 'completed',
            ledger_id = ledgerId
        }
    }, nil, auditId)
end

function getBlackmarketCatalog(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Katalogdaten.', nil, nil, nil)
    end

    local catalog = {}

    for catalogId, entry in pairs(payload.catalog or {}) do
        local item, code = validateCatalogEntry(entry, entry.dealers and entry.dealers[1] or nil, 1, 'buy')

        if item ~= nil then
            catalog[#catalog + 1] = {
                catalogId = catalogId,
                itemName = item.itemName,
                label = item.label,
                category = item.category,
                buyPrice = entry.buyPrice,
                sellPrice = entry.sellPrice,
                maxAmount = entry.maxAmount,
                dealers = entry.dealers
            }
        elseif code ~= 'NO_PERMISSION' then
            return respond(false, 'INVALID_INPUT', 'Katalog ist ungueltig konfiguriert.', nil, nil, nil)
        end
    end

    local auditId = writeCriminalAudit('criminal.blackmarketCatalogViewed', actor, actor.id, {
        itemCount = #catalog
    })

    return respond(true, 'OK', 'Schwarzmarkt-Katalog wurde geladen.', {
        dealers = payload.dealers or {},
        categories = payload.categories or {},
        catalog = catalog
    }, nil, auditId)
end

function buyBlackmarketItem(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local normalized = normalizeBlackmarketPayload(payload)

    if normalized == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Kaufdaten.', nil, nil, nil)
    end

    local item, code, message = validateCatalogEntry(findCatalogEntry(payload.catalog, normalized.catalogId), normalized.dealerId, normalized.amount, 'buy')

    if item == nil then
        return respond(false, code, message, nil, nil, nil)
    end

    local transactionId = ('blackmarket_buy_%s_%s_%04d'):format(actor.id, os.time(), math.random(0, 9999))
    local debit = exports.nexa_api['account.removeSystemMoney'](source, {
        accountId = normalized.accountId,
        accountNumber = normalized.accountNumber,
        amount = item.totalPrice,
        reason = 'Schwarzmarkt-Kauf',
        category = 'blackmarket_purchase',
        transactionId = transactionId,
        metadata = {
            dealerId = normalized.dealerId,
            catalogId = normalized.catalogId,
            itemName = item.itemName,
            amount = normalized.amount
        }
    })

    if debit == nil or not debit.success then
        return debit or respond(false, 'INTERNAL_ERROR', 'Kauf konnte nicht bezahlt werden.', nil, nil, nil)
    end

    local addItem = exports.nexa_api['inventory.addItem'](source, {
        itemName = item.itemName,
        count = normalized.amount,
        audit = {
            reason = 'blackmarket.buy',
            dealerId = normalized.dealerId,
            catalogId = normalized.catalogId
        }
    })

    if addItem == nil or not addItem.success then
        exports.nexa_api['account.addSystemMoney'](source, {
            accountId = normalized.accountId,
            accountNumber = normalized.accountNumber,
            amount = item.totalPrice,
            reason = 'Rueckerstattung Schwarzmarkt-Kauf',
            category = 'blackmarket_refund',
            transactionId = ('blackmarket_refund_%s_%s_%04d'):format(actor.id, os.time(), math.random(0, 9999)),
            metadata = {
                dealerId = normalized.dealerId,
                catalogId = normalized.catalogId,
                itemName = item.itemName,
                amount = normalized.amount
            }
        })

        return addItem or respond(false, 'INTERNAL_ERROR', 'Ware konnte nicht uebergeben werden.', nil, nil, nil)
    end

    local order = insertBlackmarketOrder(actor, normalized, item, 'buy', 'delivered')
    local auditId = writeCriminalAudit('criminal.blackmarketBuy', actor, actor.id, {
        orderId = order and order.id or nil,
        dealerId = normalized.dealerId,
        catalogId = normalized.catalogId,
        itemName = item.itemName,
        amount = normalized.amount,
        price = item.totalPrice
    })

    return respond(true, 'OK', 'Kauf abgeschlossen.', {
        order = order
    }, nil, auditId)
end

function sellBlackmarketItem(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local normalized = normalizeBlackmarketPayload(payload)

    if normalized == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Verkaufsdaten.', nil, nil, nil)
    end

    local item, code, message = validateCatalogEntry(findCatalogEntry(payload.catalog, normalized.catalogId), normalized.dealerId, normalized.amount, 'sell')

    if item == nil then
        return respond(false, code, message, nil, nil, nil)
    end

    local removeItem = exports.nexa_api['inventory.removeItem'](source, {
        itemName = item.itemName,
        count = normalized.amount,
        audit = {
            reason = 'blackmarket.sell',
            dealerId = normalized.dealerId,
            catalogId = normalized.catalogId
        }
    })

    if removeItem == nil or not removeItem.success then
        return removeItem or respond(false, 'INTERNAL_ERROR', 'Ware konnte nicht entfernt werden.', nil, nil, nil)
    end

    local transactionId = ('blackmarket_sell_%s_%s_%04d'):format(actor.id, os.time(), math.random(0, 9999))
    local credit = exports.nexa_api['account.addSystemMoney'](source, {
        accountId = normalized.accountId,
        accountNumber = normalized.accountNumber,
        amount = item.totalPrice,
        reason = 'Schwarzmarkt-Verkauf',
        category = 'blackmarket_sale',
        transactionId = transactionId,
        metadata = {
            dealerId = normalized.dealerId,
            catalogId = normalized.catalogId,
            itemName = item.itemName,
            amount = normalized.amount
        }
    })

    if credit == nil or not credit.success then
        exports.nexa_api['inventory.addItem'](source, {
            itemName = item.itemName,
            count = normalized.amount,
            audit = {
                reason = 'blackmarket.sell_restore',
                dealerId = normalized.dealerId,
                catalogId = normalized.catalogId
            }
        })

        return credit or respond(false, 'INTERNAL_ERROR', 'Auszahlung konnte nicht ausgefuehrt werden.', nil, nil, nil)
    end

    local order = insertBlackmarketOrder(actor, normalized, item, 'sell', 'delivered')
    local auditId = writeCriminalAudit('criminal.blackmarketSell', actor, actor.id, {
        orderId = order and order.id or nil,
        dealerId = normalized.dealerId,
        catalogId = normalized.catalogId,
        itemName = item.itemName,
        amount = normalized.amount,
        price = item.totalPrice
    })

    return respond(true, 'OK', 'Verkauf abgeschlossen.', {
        order = order
    }, nil, auditId)
end

exports('criminal.getReputation', getCriminalReputation)
exports('criminal.adjustReputation', adjustCriminalReputation)
exports('criminal.blackmarketCatalog', getBlackmarketCatalog)
exports('criminal.blackmarketBuy', buyBlackmarketItem)
exports('criminal.blackmarketSell', sellBlackmarketItem)
exports('criminal.drugsPlant', plantDrugCrop)
exports('criminal.drugsHarvest', harvestDrugCrop)
exports('criminal.drugsProcess', processDrugItems)
exports('criminal.drugsSell', sellDrugItems)
exports('criminal.moneywashWash', washDirtyMoney)
exports('criminal.chopshopDismantle', dismantleChopshopVehicle)
exports('criminal.chopshopSell', sellChopshopParts)
