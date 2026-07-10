local migrated = false

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or 'INVALID_INPUT'), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end

function CreateDigitalDocument(payload)
    payload = type(payload) == 'table' and payload or {}
    if type(payload.document_type) ~= 'string' or payload.document_type == '' then return fail('INVALID_INPUT', 'Document type is required.') end
    local number = payload.document_number or ('DOC-' .. os.time() .. '-' .. math.random(1000, 9999))
    local id, err = NexaDocumentsDatabase.InsertDocument({ document_number = number, document_type = payload.document_type, owner_character_id = normalizeId(payload.owner_character_id), status = payload.status or 'active', visibility = payload.visibility or 'private', created_by = normalizeId(payload.created_by), metadata = payload.metadata or {} })
    if err then return fail('DATABASE_ERROR', 'Document could not be created.', err) end
    NexaDocumentsDatabase.InsertVersion({ document_id = id, version = 1, content = payload.content or {}, created_by = normalizeId(payload.created_by) })
    return ok({ document_id = id, document_number = number }, 'Document created.')
end

function SignDocument(documentId, payload)
    payload = type(payload) == 'table' and payload or {}
    local signer = normalizeId(payload.signer_character_id)
    if not signer then return fail('INVALID_INPUT', 'Signer is invalid.') end
    local hash = payload.signature_hash or ('sig-' .. tostring(documentId) .. '-' .. tostring(signer) .. '-' .. os.time())
    local id, err = NexaDocumentsDatabase.InsertSignature({ document_id = normalizeId(documentId), signer_character_id = signer, signature_hash = hash, metadata = payload.metadata or {} })
    return err and fail('DATABASE_ERROR', 'Document could not be signed.', err) or ok({ signature_id = id, signature_hash = hash }, 'Document signed.')
end

function ShareDocument(documentId, payload)
    payload = type(payload) == 'table' and payload or {}
    if type(payload.target_type) ~= 'string' or type(payload.target_id) ~= 'string' then return fail('INVALID_INPUT', 'Share target is invalid.') end
    local id, err = NexaDocumentsDatabase.InsertShare({ document_id = normalizeId(documentId), target_type = payload.target_type, target_id = payload.target_id, permission = payload.permission or 'view', expires_hours = payload.expires_hours, metadata = payload.metadata or {} })
    return err and fail('DATABASE_ERROR', 'Document could not be shared.', err) or ok({ share_id = id }, 'Document shared.')
end

local function getStatus()
    return {
        resourceName = NEXA_DOCUMENTS.resourceName,
        version = NEXA_DOCUMENTS.version,
        api = GetResourceState('nexa_api') == 'started',
        migrated = migrated
    }
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    migrated = NexaDocumentsDatabase.Migrate() == true
    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info(NEXA_DOCUMENTS.resourceName, 'Dokumentenresource gestartet.', {
            version = NEXA_DOCUMENTS.version,
            migrated = migrated
        })
    end
end)

exports('getStatus', getStatus)
exports('CreateDigitalDocument', CreateDigitalDocument)
exports('SignDocument', SignDocument)
exports('ShareDocument', ShareDocument)
exports('getSchema', NexaDocumentsDatabase.GetSchema)
