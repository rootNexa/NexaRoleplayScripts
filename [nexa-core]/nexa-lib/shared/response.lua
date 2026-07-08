NexaLib.Response = NexaLib.Response or {}

function NexaLib.Response.ok(data)
    return {
        ok = true,
        data = data,
        error = nil
    }
end

function NexaLib.Response.fail(code, message, details)
    return {
        ok = false,
        data = nil,
        error = {
            code = code or 'INTERNAL_ERROR',
            message = message or 'Operation failed.',
            details = details
        }
    }
end
