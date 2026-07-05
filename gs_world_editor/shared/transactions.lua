---------------------------------------------------------------------
-- GS World Editor
--
-- File: transactions.lua
-- Purpose:
--     Shared transaction constants and helpers
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.TransactionConfig = GSWorldEditor.TransactionConfig or {}

GSWorldEditor.TransactionConfig.MaxHistory = 100

GSWorldEditor.TransactionConfig.Actions = {
    RadiusChange = "radius_change",
    SelectionChange = "selection_change",
    ModeChange = "mode_change",
    DraftChange = "draft_change",
}

function GSWorldEditor.BuildTransactionId(sequence)
    return ("txn_%04d"):format(tonumber(sequence) or 0)
end
