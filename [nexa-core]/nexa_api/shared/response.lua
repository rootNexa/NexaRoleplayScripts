function NexaApiResponse(success, code, message, data, meta, auditId)
    return {
        success = success == true,
        code = code or NexaApiErrors.INTERNAL_ERROR,
        message = message or 'Der Vorgang konnte nicht abgeschlossen werden.',
        data = data,
        meta = meta,
        audit_id = auditId
    }
end
