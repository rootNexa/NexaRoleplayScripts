function info(resourceName, message, metadata)
    return writeLog('info', resourceName, message, metadata)
end

function warn(resourceName, message, metadata)
    return writeLog('warn', resourceName, message, metadata)
end

function errorLog(resourceName, message, metadata)
    return writeLog('error', resourceName, message, metadata)
end

function performance(resourceName, message, metadata)
    return writeLog('performance', resourceName, message, metadata)
end

function recent(limit)
    return getRecentLogs(limit)
end

exports('info', info)
exports('warn', warn)
exports('error', errorLog)
exports('performance', performance)
exports('recent', recent)
