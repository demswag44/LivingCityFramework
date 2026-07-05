# WORLD-003.5 - Editor Transaction System

## Purpose

The editor transaction system records structured, reversible changes made while an editor session is active. It is the foundation for undo, redo, dirty state, save/cancel workflows, and future audit logging across every Living City editor tool.

## Transaction Shape

```lua
{
    id = "txn_0001",
    source = 1,
    toolId = "territories",
    action = "radius_change",
    label = "Changed territory radius",
    before = {
        radius = 50.0,
    },
    after = {
        radius = 75.0,
    },
    timestamp = 1783190000,
    dirty = true,
}
```

## Client API

```lua
GSWorldEditor.Transactions.Record(action, label, before, after)
GSWorldEditor.Transactions.Undo()
GSWorldEditor.Transactions.Redo()
GSWorldEditor.Transactions.Clear()
GSWorldEditor.Transactions.ClearLocal()
GSWorldEditor.Transactions.GetHistory()
GSWorldEditor.Transactions.GetRedoStack()
GSWorldEditor.Transactions.Count()
GSWorldEditor.Transactions.RedoCount()
GSWorldEditor.Transactions.RegisterApplyHandler(action, handler)
```

The client applies reversible changes immediately. The first implemented apply handler is `radius_change`, which restores territory preview radius during undo/redo.

## Server API

```lua
GSWorldEditor.TransactionServer.Record(source, transaction)
GSWorldEditor.TransactionServer.Undo(source, transactionId)
GSWorldEditor.TransactionServer.Redo(source, transactionId)
GSWorldEditor.TransactionServer.Clear(source)
GSWorldEditor.TransactionServer.GetHistory(source)
```

Server sessions now store:

- `transactions`
- `redoTransactions`
- `dirty`

The server mirrors client transaction history into the active session. No persistence or audit database writes are performed in WORLD-003.5.

## Commands

- `/gswe undo` asks the client to undo the latest transaction.
- `/gswe redo` asks the client to redo the latest undone transaction.
- `/gswe save` is a placeholder that clears transaction history and dirty state.
- `/gswe cancel` ends the active session.

## Current Transaction Producers

Radius changes from mouse wheel create `radius_change` transactions:

- `before.radius`
- `after.radius`

Future tools should register their own apply handlers through `GSWorldEditor.Transactions.RegisterApplyHandler` instead of implementing separate undo/redo systems.

## Design Rule

Every future editor tool should use `gs_world_editor` transactions for change history. Gameplay resources should provide domain-specific save actions later, but they should not create their own undo/redo stack.
