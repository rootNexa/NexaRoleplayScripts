Nexa.Database = {
    ready = false
}

local function dbLog(level, message, context)
    if Nexa.Log then
        Nexa.Log(level, message, context)
    end
end

local function runQuery(kind, query, params)
    params = params or {}

    local ok, result = pcall(function()
        return MySQL[kind].await(query, params)
    end)

    if not ok then
        dbLog('error', 'Datenbankabfrage fehlgeschlagen.', {
            kind = kind,
            error = result
        })
        return nil, result
    end

    return result, nil
end

function Nexa.Database.FetchOne(query, params)
    local rows, err = runQuery('query', query, params)

    if err then
        return nil, err
    end

    return rows and rows[1] or nil, nil
end

function Nexa.Database.FetchAll(query, params)
    return runQuery('query', query, params)
end

function Nexa.Database.Insert(query, params)
    return runQuery('insert', query, params)
end

function Nexa.Database.Update(query, params)
    return runQuery('update', query, params)
end

function Nexa.Database.Execute(query, params)
    return runQuery('query', query, params)
end

function Nexa.Database.Transaction(queries)
    local ok, result = pcall(function()
        return MySQL.transaction.await(queries)
    end)

    if not ok then
        dbLog('error', 'Datenbanktransaktion fehlgeschlagen.', {
            error = result
        })
        return false, result
    end

    return result == true, nil
end

function Nexa.Database.CheckReady()
    local result = MySQL.scalar.await('SELECT 1')
    Nexa.Database.ready = result == 1
    return Nexa.Database.ready
end
