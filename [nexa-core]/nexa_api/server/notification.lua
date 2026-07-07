function prepareServerNotification(source, message, notificationType)
    if tonumber(source) == nil then
        return NexaApiResponse(false, 'INVALID_INPUT', 'Ungueltige Source.', nil, nil, nil)
    end

    if type(message) ~= 'string' or message == '' then
        return NexaApiResponse(false, 'INVALID_INPUT', 'Ungueltige Nachricht.', nil, nil, nil)
    end

    return NexaApiResponse(true, 'OK', 'Benachrichtigung vorbereitet.', {
        source = source,
        message = message,
        type = notificationType or 'info'
    }, nil, nil)
end

exports('prepareServerNotification', prepareServerNotification)
exports('notification.send', prepareServerNotification)
