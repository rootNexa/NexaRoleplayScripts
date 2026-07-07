function prepareNotification(message, notificationType)
    if type(message) ~= 'string' or message == '' then
        return NexaApiResponse(false, 'INVALID_INPUT', 'Ungueltige Nachricht.', nil, nil, nil)
    end

    return NexaApiResponse(true, 'OK', message, {
        type = notificationType or 'info'
    }, nil, nil)
end

exports('prepareNotification', prepareNotification)
