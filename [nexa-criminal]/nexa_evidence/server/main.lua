local function isEnabled()
    return GetResourceState('nexa_featureflags') ~= 'started'
        or exports.nexa_featureflags:isEnabled(NexaEvidenceConfig.featureFlag)
end

local function buildConfigPayload()
    return {
        evidenceTypes = NexaEvidenceServer.evidenceTypes
    }
end

local function getStatus()
    return {
        resourceName = NEXA_EVIDENCE.resourceName,
        version = NEXA_EVIDENCE.version,
        enabled = isEnabled(),
        policeApi = GetResourceState('nexa_api') == 'started'
    }
end

local function collect(source, payload)
    if not isEnabled() then
        return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Evidence ist deaktiviert.', nil, nil, nil)
    end

    payload = payload or {}
    payload.config = buildConfigPayload()

    return exports.nexa_api['police.collectEvidence'](source, payload)
end

local function collectDna(source, payload)
    payload = payload or {}
    payload.evidenceType = 'dna'

    return collect(source, payload)
end

local function collectFingerprint(source, payload)
    payload = payload or {}
    payload.evidenceType = 'fingerprint'

    return collect(source, payload)
end

local function collectShellCasing(source, payload)
    payload = payload or {}
    payload.evidenceType = 'shell_casing'

    return collect(source, payload)
end

local function collectBlood(source, payload)
    payload = payload or {}
    payload.evidenceType = 'blood'

    return collect(source, payload)
end

local function listEvidence(source, payload)
    if not isEnabled() then
        return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Evidence ist deaktiviert.', nil, nil, nil)
    end

    return exports.nexa_api['police.listEvidence'](source, payload or {})
end

local function updateStatus(source, payload)
    if not isEnabled() then
        return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Evidence ist deaktiviert.', nil, nil, nil)
    end

    return exports.nexa_api['police.updateEvidenceStatus'](source, payload or {})
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_EVIDENCE.resourceName, 'Evidence gestartet.', {
        version = NEXA_EVIDENCE.version,
        featureFlag = NexaEvidenceConfig.featureFlag
    })
end)

exports('getStatus', getStatus)
exports('evidence.collect', collect)
exports('evidence.collectDna', collectDna)
exports('evidence.collectFingerprint', collectFingerprint)
exports('evidence.collectShellCasing', collectShellCasing)
exports('evidence.collectBlood', collectBlood)
exports('evidence.list', listEvidence)
exports('evidence.updateStatus', updateStatus)
