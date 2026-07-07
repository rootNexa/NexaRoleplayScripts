function registerAnticheatSecureEvent(eventName, options)
    return exports.nexa_anticheat:registerSecureEvent(eventName, options)
end

function validateAnticheatEvent(source, eventName, payload, token)
    return exports.nexa_anticheat:validateEvent(source, eventName, payload, token)
end

function listAnticheatSecureEvents()
    return exports.nexa_anticheat:listSecureEvents()
end

function issueAnticheatToken(source, eventName, metadata)
    return exports.nexa_anticheat:issueToken(source, eventName, metadata)
end

function verifyAnticheatEventToken(source, eventName, token)
    return exports.nexa_anticheat:verifyEventToken(source, eventName, token)
end

function validateAnticheatSession(source)
    return exports.nexa_anticheat:validateSession(source)
end

function validateAnticheatResourceIntegrity(resourceName)
    return exports.nexa_anticheat:validateResourceIntegrity(resourceName)
end

function validateMoneyIntegrity(payload)
    return exports.nexa_anticheat:validateMoneyIntegrity(payload)
end

function validateMoneyAccountBalance(payload)
    return exports.nexa_anticheat:validateAccountBalance(payload)
end

function validateMoneyEconomyLedger(payload)
    return exports.nexa_anticheat:validateEconomyLedger(payload)
end

function getMoneyReconciliationReport(payload)
    return exports.nexa_anticheat:getMoneyReconciliationReport(payload)
end

function validateInventoryIntegrity(payload)
    return exports.nexa_anticheat:validateInventoryIntegrity(payload)
end

function validateInventoryOxAccess(payload)
    return exports.nexa_anticheat:validateOxInventoryAccess(payload)
end

function validateInventoryItemLedger(payload)
    return exports.nexa_anticheat:validateItemLedger(payload)
end

function getInventoryReconciliationReport(payload)
    return exports.nexa_anticheat:getInventoryReconciliationReport(payload)
end

function validateVehicleIntegrity(payload)
    return exports.nexa_anticheat:validateVehicleIntegrity(payload)
end

function validateVehicleOwnership(payload)
    return exports.nexa_anticheat:validateVehicleOwnership(payload)
end

function validateVehicleGarageState(payload)
    return exports.nexa_anticheat:validateVehicleGarageState(payload)
end

function validateVehicleHistory(payload)
    return exports.nexa_anticheat:validateVehicleHistory(payload)
end

function getVehicleReconciliationReport(payload)
    return exports.nexa_anticheat:getVehicleReconciliationReport(payload)
end

function validateTeleportPositionSnapshot(source, payload)
    return exports.nexa_anticheat:validatePositionSnapshot(source, payload)
end

function allowTeleport(source, context, metadata)
    return exports.nexa_anticheat:allowTeleport(source, context, metadata)
end

function getSuspiciousMovementReports(limit)
    return exports.nexa_anticheat:getSuspiciousMovementReports(limit)
end

function validateNoclipMovement(source, payload)
    return exports.nexa_anticheat:validateNoclipMovement(source, payload)
end

function allowNoclipException(source, context, metadata)
    return exports.nexa_anticheat:allowNoclipException(source, context, metadata)
end

function getSuspiciousNoclipReports(limit)
    return exports.nexa_anticheat:getSuspiciousNoclipReports(limit)
end

function validateGodmodeState(source, payload)
    return exports.nexa_anticheat:validateGodmodeState(source, payload)
end

function allowGodmodeException(source, context, metadata)
    return exports.nexa_anticheat:allowGodmodeException(source, context, metadata)
end

function recordGodmodeDamageEvent(source, payload)
    return exports.nexa_anticheat:recordGodmodeDamageEvent(source, payload)
end

function getSuspiciousGodmodeReports(limit)
    return exports.nexa_anticheat:getSuspiciousGodmodeReports(limit)
end

function validateExecutorSignal(source, payload)
    return exports.nexa_anticheat:validateExecutorSignal(source, payload)
end

function getSuspiciousExecutorReports(limit)
    return exports.nexa_anticheat:getSuspiciousExecutorReports(limit)
end

function requestEvidenceCapture(actorSource, targetSource, payload)
    return exports.nexa_anticheat:requestEvidenceCapture(actorSource, targetSource, payload)
end

function prepareAnticheatEvidenceCapture(targetSource, payload)
    return exports.nexa_anticheat:prepareAnticheatEvidenceCapture(targetSource, payload)
end

function getEvidenceCaptureRequests(limit)
    return exports.nexa_anticheat:getEvidenceCaptureRequests(limit)
end

function createManualBan(actorSource, payload)
    return exports.nexa_anticheat:createManualBan(actorSource, payload)
end

function checkBanForSource(source)
    return exports.nexa_anticheat:checkBanForSource(source)
end

function getBanHistory(payload)
    return exports.nexa_anticheat:getBanHistory(payload)
end

exports('anticheat.registerSecureEvent', registerAnticheatSecureEvent)
exports('anticheat.listSecureEvents', listAnticheatSecureEvents)
exports('anticheat.validateEvent', validateAnticheatEvent)
exports('anticheat.issueToken', issueAnticheatToken)
exports('anticheat.verifyToken', verifyAnticheatEventToken)
exports('anticheat.validateSession', validateAnticheatSession)
exports('anticheat.validateResourceIntegrity', validateAnticheatResourceIntegrity)
exports('money.validateIntegrity', validateMoneyIntegrity)
exports('money.validateAccountBalance', validateMoneyAccountBalance)
exports('money.validateEconomyLedger', validateMoneyEconomyLedger)
exports('money.getReconciliationReport', getMoneyReconciliationReport)
exports('inventory.validateIntegrity', validateInventoryIntegrity)
exports('inventory.validateOxAccess', validateInventoryOxAccess)
exports('inventory.validateItemLedger', validateInventoryItemLedger)
exports('inventory.getReconciliationReport', getInventoryReconciliationReport)
exports('vehicle.validateIntegrity', validateVehicleIntegrity)
exports('vehicle.validateOwnership', validateVehicleOwnership)
exports('vehicle.validateGarageState', validateVehicleGarageState)
exports('vehicle.validateHistory', validateVehicleHistory)
exports('vehicle.getReconciliationReport', getVehicleReconciliationReport)
exports('teleport.validatePositionSnapshot', validateTeleportPositionSnapshot)
exports('teleport.allow', allowTeleport)
exports('teleport.getSuspiciousReports', getSuspiciousMovementReports)
exports('noclip.validateMovement', validateNoclipMovement)
exports('noclip.allowException', allowNoclipException)
exports('noclip.getSuspiciousReports', getSuspiciousNoclipReports)
exports('godmode.validateState', validateGodmodeState)
exports('godmode.allowException', allowGodmodeException)
exports('godmode.recordDamageEvent', recordGodmodeDamageEvent)
exports('godmode.getSuspiciousReports', getSuspiciousGodmodeReports)
exports('executor.validateSignal', validateExecutorSignal)
exports('executor.getSuspiciousReports', getSuspiciousExecutorReports)
exports('evidence.requestCapture', requestEvidenceCapture)
exports('evidence.prepareAnticheatCapture', prepareAnticheatEvidenceCapture)
exports('evidence.getCaptureRequests', getEvidenceCaptureRequests)
exports('ban.createManual', createManualBan)
exports('ban.checkSource', checkBanForSource)
exports('ban.getHistory', getBanHistory)
