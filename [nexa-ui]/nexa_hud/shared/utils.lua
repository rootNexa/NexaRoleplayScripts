local function copyTable(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}

    for key, item in pairs(value) do
        copy[key] = copyTable(item)
    end

    return copy
end

local function clampPercent(value)
    local number = tonumber(value)

    if number == nil then
        return 0
    end

    if number < 0 then
        return 0
    end

    if number > 100 then
        return 100
    end

    return math.floor(number)
end

function NexaHudCopyTable(value)
    return copyTable(value)
end

function NexaHudPercent(value)
    return clampPercent(value)
end

function NexaHudFormatAccount(account)
    if type(account) ~= 'table' then
        return nil
    end

    return {
        label = account.account_type == 'business' and NexaHudLocale.businessAccount or NexaHudLocale.privateAccount,
        balance = tonumber(account.balance) or 0,
        currency = account.currency or 'USD'
    }
end

function NexaHudFormatJob(job)
    if type(job) ~= 'table' then
        return nil
    end

    return {
        label = job.job_label or NexaHudLocale.noJob,
        grade = job.grade_label or NexaHudLocale.noGrade,
        duty = job.duty == true
    }
end

function NexaHudFormatBusiness(business)
    if type(business) ~= 'table' then
        return nil
    end

    return {
        label = business.label or business.name or NexaHudLocale.noBusiness,
        role = business.role_name or NexaHudLocale.noGrade
    }
end
