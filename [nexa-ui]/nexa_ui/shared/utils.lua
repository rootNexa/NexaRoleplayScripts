local function trim(value)
    return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function clampText(value, maxLength)
    if type(value) ~= 'string' then
        return nil
    end

    local cleanValue = trim(value)

    if cleanValue == '' then
        return nil
    end

    if #cleanValue > maxLength then
        return cleanValue:sub(1, maxLength)
    end

    return cleanValue
end

local function copyTable(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}

    for key, item in pairs(value) do
        copy[key] = copyTable(item)
    end

    return copy
end

function NexaUiCopyTable(value)
    return copyTable(value)
end

function NexaUiSanitizeText(value, maxLength)
    return clampText(value, maxLength or NexaUiConfig.maxDialogTextLength)
end

function NexaUiNormalizeNotification(payload)
    if type(payload) == 'string' then
        payload = {
            message = payload
        }
    end

    if type(payload) ~= 'table' then
        return nil
    end

    local message = clampText(payload.message or payload.description, NexaUiConfig.maxNotificationLength)

    if message == nil then
        return nil
    end

    local notificationType = payload.type or 'info'

    if not NEXA_UI_NOTIFICATION_TYPES[notificationType] then
        notificationType = 'info'
    end

    return {
        title = clampText(payload.title or NexaUiLocale.defaultNotificationTitle, 64),
        message = message,
        type = notificationType,
        duration = tonumber(payload.duration) or NexaUiClientConfig.notificationDurationMs
    }
end

function NexaUiNormalizeConfirm(payload)
    if type(payload) ~= 'table' then
        return nil
    end

    local message = clampText(payload.message, NexaUiConfig.maxDialogTextLength)

    if message == nil then
        return nil
    end

    return {
        id = payload.id,
        title = clampText(payload.title or NexaUiLocale.confirmTitle, 64),
        message = message,
        confirmLabel = clampText(payload.confirmLabel or NexaUiLocale.confirm, 32),
        cancelLabel = clampText(payload.cancelLabel or NexaUiLocale.cancel, 32)
    }
end

function NexaUiNormalizeMenu(payload)
    if type(payload) ~= 'table' or type(payload.items) ~= 'table' then
        return nil
    end

    local items = {}

    for index, item in ipairs(payload.items) do
        if index > NexaUiConfig.maxMenuItems then
            break
        end

        if type(item) == 'table' then
            local label = clampText(item.label or item.title, 48)

            if label ~= nil then
                items[#items + 1] = {
                    id = clampText(item.id or ('item_' .. index), 48),
                    label = label,
                    description = clampText(item.description or '', 96),
                    disabled = item.disabled == true
                }
            end
        end
    end

    if #items == 0 then
        return nil
    end

    return {
        title = clampText(payload.title or NexaUiLocale.menuTitle, 64),
        items = items
    }
end
