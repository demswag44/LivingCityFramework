---------------------------------------------------------------------
-- GS World Editor
--
-- File: transactions.lua
-- Purpose:
--     Server-side editor transaction session history
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.TransactionServer = GSWorldEditor.TransactionServer or {}

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end

    local copied = {}

    for key, item in pairs(value) do
        copied[key] = Copy(item)
    end

    return copied
end

local function Log(message)
    print(("[%s] %s"):format(GSWorldEditor.Config.LogPrefix, message))
end

local function GetSessionForSource(source)
    if not GSWorldEditor.GetMutableSession then
        return nil
    end

    return GSWorldEditor.GetMutableSession(source)
end

local function TrimHistory(session)
    while #session.transactions > GSWorldEditor.TransactionConfig.MaxHistory do
        table.remove(session.transactions, 1)
    end
end

function GSWorldEditor.TransactionServer.Record(source, transaction)
    local session = GetSessionForSource(source)

    if not session or type(transaction) ~= "table" then
        return false, "No active editor session."
    end

    transaction.source = tonumber(source)
    transaction.toolId = session.toolId
    transaction.timestamp = transaction.timestamp or os.time()
    transaction.dirty = true

    session.transactions[#session.transactions + 1] = Copy(transaction)
    session.redoTransactions = {}
    session.dirty = true
    TrimHistory(session)

    Log("Transaction Recorded")

    return true, Copy(transaction)
end

function GSWorldEditor.TransactionServer.Undo(source, transactionId)
    local session = GetSessionForSource(source)

    if not session or #session.transactions == 0 then
        return false, "Nothing to undo."
    end

    local transaction = table.remove(session.transactions)

    session.redoTransactions[#session.redoTransactions + 1] = transaction
    session.dirty = #session.transactions > 0

    Log("Transaction Undone")

    return true, Copy(transaction)
end

function GSWorldEditor.TransactionServer.Redo(source, transactionId)
    local session = GetSessionForSource(source)

    if not session or #session.redoTransactions == 0 then
        return false, "Nothing to redo."
    end

    local transaction = table.remove(session.redoTransactions)

    session.transactions[#session.transactions + 1] = transaction
    session.dirty = true

    Log("Transaction Redone")

    return true, Copy(transaction)
end

function GSWorldEditor.TransactionServer.Clear(source)
    local session = GetSessionForSource(source)

    if not session then
        return false, "No active editor session."
    end

    session.transactions = {}
    session.redoTransactions = {}
    session.dirty = false

    return true
end

function GSWorldEditor.TransactionServer.GetHistory(source)
    local session = GSWorldEditor.GetSession(source)

    if not session then
        return {}
    end

    return session.transactions or {}
end

RegisterNetEvent("gs_world_editor:transactionRecorded", function(transaction)
    GSWorldEditor.TransactionServer.Record(source, transaction)
end)

RegisterNetEvent("gs_world_editor:transactionUndone", function(transactionId)
    GSWorldEditor.TransactionServer.Undo(source, transactionId)
end)

RegisterNetEvent("gs_world_editor:transactionRedone", function(transactionId)
    GSWorldEditor.TransactionServer.Redo(source, transactionId)
end)

RegisterNetEvent("gs_world_editor:transactionsCleared", function()
    GSWorldEditor.TransactionServer.Clear(source)
end)

exports("GetTransactionHistory", function(source)
    return GSWorldEditor.TransactionServer.GetHistory(source)
end)
