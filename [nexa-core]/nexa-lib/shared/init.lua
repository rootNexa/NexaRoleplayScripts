NexaLib = NexaLib or {}
NexaLib.Name = 'nexa-lib'
NexaLib.Version = '0.1.0'

NexaLib.CallbackEvents = {
    clientRequest = 'nexa-lib:callbacks:clientRequest',
    clientResponse = 'nexa-lib:callbacks:clientResponse',
    serverRequest = 'nexa-lib:callbacks:serverRequest',
    serverResponse = 'nexa-lib:callbacks:serverResponse'
}

NexaLib.Defaults = {
    callbackTimeoutMs = 10000,
    eventCooldownMs = 500
}
