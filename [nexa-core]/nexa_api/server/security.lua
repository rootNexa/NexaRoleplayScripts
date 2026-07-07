function checkSecurityRateLimit(source, eventName)
    return exports.nexa_security:checkRateLimit(source, eventName)
end

exports('checkSecurityRateLimit', checkSecurityRateLimit)
exports('security.checkRateLimit', checkSecurityRateLimit)
