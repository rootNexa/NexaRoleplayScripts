NexaApiConstants = {
    resource = 'nexa_api',
    version = '1.0.0',
    defaultTimeoutMs = 5000,
    devPermission = 'nexa.admin',
    events = {
        clientRequest = 'nexa_api:callback:clientRequest',
        clientResponse = 'nexa_api:callback:clientResponse',
        serverRequest = 'nexa_api:callback:serverRequest',
        serverResponse = 'nexa_api:callback:serverResponse'
    },
    errors = {
        invalidInput = 'INVALID_INPUT',
        invalid_contract = 'INVALID_CONTRACT',
        invalid_payload = 'INVALID_PAYLOAD',
        notFound = 'NOT_FOUND',
        forbidden = 'FORBIDDEN',
        timeout = 'TIMEOUT',
        internal = 'INTERNAL_ERROR'
    }
}
