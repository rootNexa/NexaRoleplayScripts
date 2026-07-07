local stateBySource = {}

local function nowLabel()
    return os.date('!%Y-%m-%d %H:%M UTC')
end

local function getState(source)
    local key = tostring(source)

    if stateBySource[key] == nil then
        stateBySource[key] = {
            contacts = NexaPhoneCopyTable(NexaPhoneServerConfig.defaultContacts),
            messages = {},
            calls = NexaPhoneCopyTable(NexaPhoneServerConfig.defaultCalls),
            notes = {},
            mails = NexaPhoneCopyTable(NexaPhoneServerConfig.defaultMails)
        }
    end

    return stateBySource[key]
end

local function pushLimited(list, entry, maxEntries)
    table.insert(list, 1, entry)

    while #list > maxEntries do
        table.remove(list)
    end
end

function NexaPhoneGetSnapshot(source)
    local state = getState(source)

    return {
        contacts = NexaPhoneCopyTable(state.contacts),
        messages = NexaPhoneCopyTable(state.messages),
        calls = NexaPhoneCopyTable(state.calls),
        notes = NexaPhoneCopyTable(state.notes),
        mails = NexaPhoneCopyTable(state.mails)
    }
end

function NexaPhoneAddNote(source, title, body)
    local state = getState(source)
    local entry = {
        id = ('note-%s-%s'):format(tostring(source), tostring(os.time())),
        title = title,
        body = body,
        createdAt = nowLabel()
    }

    pushLimited(state.notes, entry, NexaPhoneServerConfig.limits.maxNotes)

    return NexaPhoneCopyTable(entry)
end

function NexaPhoneAddMessage(source, recipient, body)
    local state = getState(source)
    local entry = {
        id = ('msg-%s-%s'):format(tostring(source), tostring(os.time())),
        recipient = recipient,
        body = body,
        direction = 'ausgehend',
        createdAt = nowLabel(),
        status = 'vorgemerkt'
    }

    pushLimited(state.messages, entry, NexaPhoneServerConfig.limits.maxMessages)

    return NexaPhoneCopyTable(entry)
end
