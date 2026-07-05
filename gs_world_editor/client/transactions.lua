---------------------------------------------------------------------
-- GS World Editor
--
-- File: transactions.lua
-- Purpose:
--     Client-side reversible editor transaction history
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.Transactions = GSWorldEditor.Transactions or {}

local History = {}
local RedoStack = {}
local Sequence = 0
local ApplyHandlers = {}

local function Log(message)
    print(("[WORLD EDITOR] %s"):format(message))
end

local function Notify(message)
    TriggerEvent("chat:addMessage", {
        args = {
            "World Editor",
            message,
        },
    })
end

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

local function TrimHistory()
    while #History > GSWorldEditor.TransactionConfig.MaxHistory do
        table.remove(History, 1)
    end
end

local function BuildTransaction(action, label, before, after)
    Sequence = Sequence + 1

    return {
        id = GSWorldEditor.BuildTransactionId(Sequence),
        source = GetPlayerServerId(PlayerId()),
        toolId = GSWorldEditor.VisualMode and GSWorldEditor.VisualMode.toolId or nil,
        action = action,
        label = label or action,
        before = Copy(before) or {},
        after = Copy(after) or {},
        timestamp = GetCloudTimeAsInt and GetCloudTimeAsInt() or 0,
        dirty = true,
    }
end

local function ApplyTransaction(transaction, state)
    local handler = ApplyHandlers[transaction.action]

    if not handler then
        return false
    end

    return handler(state or {})
end

function GSWorldEditor.Transactions.RegisterApplyHandler(action, handler)
    if type(action) ~= "string" or type(handler) ~= "function" then
        return false
    end

    ApplyHandlers[action] = handler

    return true
end

function GSWorldEditor.Transactions.Record(action, label, before, after)
    local transaction = BuildTransaction(action, label, before, after)

    History[#History + 1] = transaction
    RedoStack = {}
    TrimHistory()

    TriggerServerEvent("gs_world_editor:transactionRecorded", transaction)
    Log("Transaction Recorded")

    return Copy(transaction)
end

function GSWorldEditor.Transactions.Undo()
    local transaction = table.remove(History)

    if not transaction then
        Notify("Nothing to undo.")
        return false
    end

    if not ApplyTransaction(transaction, transaction.before) then
        History[#History + 1] = transaction
        Notify("Unable to undo transaction.")
        return false
    end

    RedoStack[#RedoStack + 1] = transaction

    if GSWorldEditor.VisualMode then
        GSWorldEditor.VisualMode.dirty = #History > 0
    end

    TriggerServerEvent("gs_world_editor:transactionUndone", transaction.id)
    Notify(("Undid: %s"):format(transaction.label))

    return true
end

function GSWorldEditor.Transactions.Redo()
    local transaction = table.remove(RedoStack)

    if not transaction then
        Notify("Nothing to redo.")
        return false
    end

    if not ApplyTransaction(transaction, transaction.after) then
        RedoStack[#RedoStack + 1] = transaction
        Notify("Unable to redo transaction.")
        return false
    end

    History[#History + 1] = transaction

    if GSWorldEditor.VisualMode then
        GSWorldEditor.VisualMode.dirty = true
    end

    TriggerServerEvent("gs_world_editor:transactionRedone", transaction.id)
    Notify(("Redid: %s"):format(transaction.label))

    return true
end

function GSWorldEditor.Transactions.Clear()
    History = {}
    RedoStack = {}

    if GSWorldEditor.VisualMode then
        GSWorldEditor.VisualMode.dirty = false
    end

    TriggerServerEvent("gs_world_editor:transactionsCleared")

    return true
end

function GSWorldEditor.Transactions.ClearLocal()
    History = {}
    RedoStack = {}

    if GSWorldEditor.VisualMode then
        GSWorldEditor.VisualMode.dirty = false
    end

    return true
end

function GSWorldEditor.Transactions.GetHistory()
    return Copy(History)
end

function GSWorldEditor.Transactions.GetRedoStack()
    return Copy(RedoStack)
end

function GSWorldEditor.Transactions.Count()
    return #History
end

function GSWorldEditor.Transactions.RedoCount()
    return #RedoStack
end

GSWorldEditor.Transactions.RegisterApplyHandler(
    GSWorldEditor.TransactionConfig.Actions.RadiusChange,
    function(state)
        local draft = GSWorldEditor.VisualMode.draft or {}
        draft.radius = tonumber(state.radius) or draft.radius or 50.0
        GSWorldEditor.Client.SetVisualDraft(draft)
        return true
    end
)

exports("RecordTransaction", GSWorldEditor.Transactions.Record)
exports("UndoTransaction", GSWorldEditor.Transactions.Undo)
exports("RedoTransaction", GSWorldEditor.Transactions.Redo)
exports("ClearTransactions", GSWorldEditor.Transactions.Clear)
exports("GetTransactionHistory", GSWorldEditor.Transactions.GetHistory)

RegisterNetEvent("gs_world_editor:client:undoTransaction", function()
    GSWorldEditor.Transactions.Undo()
end)

RegisterNetEvent("gs_world_editor:client:redoTransaction", function()
    GSWorldEditor.Transactions.Redo()
end)

RegisterNetEvent("gs_world_editor:client:clearTransactions", function()
    GSWorldEditor.Transactions.ClearLocal()
end)
