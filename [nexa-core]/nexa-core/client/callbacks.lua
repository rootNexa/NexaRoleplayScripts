NexaClient = NexaClient or {}
NexaClient.Callbacks = {}

function NexaClient.Callbacks.GetSession()
    return lib.callback.await(NEXA_CONSTANTS.callbacks.getSession, false)
end

function NexaClient.Callbacks.GetCharacters()
    return lib.callback.await(NEXA_CONSTANTS.callbacks.getCharacters, false)
end
