local migrated = false

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_RADIO_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function emit(eventName, payload) if GetResourceState('nexa-core') ~= 'started' then return end; local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); if good and core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_RADIO.resourceName }) end end
local function registerCallback(name, handler) if GetResourceState('nexa_api') == 'started' then exports.nexa_api:RegisterServerCallback(name, handler) end end

function RegisterChannel(payload)
    payload = type(payload) == 'table' and payload or {}
    if type(payload.channel_key) ~= 'string' or payload.channel_key == '' or type(payload.frequency) ~= 'string' or payload.frequency == '' then return fail(NEXA_RADIO_ERRORS.invalidInput, 'Radio channel is invalid.') end
    local id, err = NexaRadioDatabase.UpsertChannel({ channel_key = payload.channel_key, label = payload.label or payload.channel_key, frequency = payload.frequency, organization_id = normalizeId(payload.organization_id), encryption_class = payload.encryption_class or NexaRadioConfig.defaultEncryptionClass, priority = tonumber(payload.priority) or 3, enabled = payload.enabled ~= false, metadata = payload.metadata or {} })
    if err then return fail(NEXA_RADIO_ERRORS.databaseError, 'Radio channel could not be registered.', err) end
    emit(NEXA_RADIO_EVENTS.channelRegistered, { channel_key = payload.channel_key })
    return ok({ channel_id = id, channel_key = payload.channel_key }, 'Radio channel registered.')
end

function ListChannels() local rows, err = NexaRadioDatabase.ListChannels(); return err and fail(NEXA_RADIO_ERRORS.databaseError, 'Radio channels could not be listed.', err) or ok(rows or {}, 'Radio channels listed.') end
function JoinChannel(channelKey, characterId, payload) payload = type(payload) == 'table' and payload or {}; characterId = normalizeId(characterId); if not characterId or type(channelKey) ~= 'string' then return fail(NEXA_RADIO_ERRORS.invalidInput, 'Radio membership is invalid.') end; local id, err = NexaRadioDatabase.InsertMembership({ channel_key = channelKey, character_id = characterId, role = payload.role, metadata = payload.metadata or {} }); if err then return fail(NEXA_RADIO_ERRORS.databaseError, 'Radio channel could not be joined.', err) end; emit(NEXA_RADIO_EVENTS.joined, { channel_key = channelKey, character_id = characterId }); return ok({ membership_id = id }, 'Radio channel joined.') end
function LeaveChannel(channelKey, characterId) characterId = normalizeId(characterId); if not characterId or type(channelKey) ~= 'string' then return fail(NEXA_RADIO_ERRORS.invalidInput, 'Radio membership is invalid.') end; NexaRadioDatabase.DeleteMembership(channelKey, characterId); emit(NEXA_RADIO_EVENTS.left, { channel_key = channelKey, character_id = characterId }); return ok({ channel_key = channelKey, character_id = characterId }, 'Radio channel left.') end
function SetPriority(channelKey, priority) local value = math.max(1, math.min(9, tonumber(priority) or 3)); NexaRadioDatabase.SetPriority(channelKey, value); emit(NEXA_RADIO_EVENTS.priorityChanged, { channel_key = channelKey, priority = value }); return ok({ channel_key = channelKey, priority = value }, 'Radio priority updated.') end

local function registerCallbacks()
    registerCallback('nexa:radio:cb:registerChannel', function(_, payload) return RegisterChannel(payload) end)
    registerCallback('nexa:radio:cb:listChannels', function() return ListChannels() end)
    registerCallback('nexa:radio:cb:joinChannel', function(_, payload) payload = type(payload) == 'table' and payload or {}; return JoinChannel(payload.channel_key, payload.character_id, payload) end)
    registerCallback('nexa:radio:cb:leaveChannel', function(_, payload) payload = type(payload) == 'table' and payload or {}; return LeaveChannel(payload.channel_key, payload.character_id) end)
end

AddEventHandler('onResourceStart', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; if NexaRadioConfig.autoMigrate then migrated = NexaRadioDatabase.Migrate() == true end; registerCallbacks(); print(('[nexa_radio] bereit. migrated=%s'):format(tostring(migrated))) end)

exports('RegisterChannel', RegisterChannel)
exports('JoinChannel', JoinChannel)
exports('LeaveChannel', LeaveChannel)
exports('SetPriority', SetPriority)
exports('ListChannels', ListChannels)
exports('getSchema', NexaRadioDatabase.GetSchema)
exports('getStatus', function() return { resourceName = NEXA_RADIO.resourceName, migrated = migrated } end)
