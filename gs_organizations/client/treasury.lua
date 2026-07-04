---------------------------------------------------------------------
-- GS Organizations
--
-- File: treasury.lua
-- Purpose:
--     Organization treasury UI
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Client = GSOrganizations.Client or {}

local Client = GSOrganizations.Client
local UI = GSOrganizations.UI

local function Notify(type, message)
    lib.notify({
        title = UI.Config.MenuTitle,
        description = message,
        type = type,
    })
end

local function NotifyError(message)
    Notify("error", message)
end

local function Money(value)
    return ("$%s"):format(tostring(value or 0))
end

local function Trim(value)
    if type(value) ~= "string" then
        return value
    end

    return value:match("^%s*(.-)%s*$")
end

local function TreasuryInput(title, includeTarget)
    local fields = {}

    if includeTarget then
        fields[#fields + 1] = {
            type = "number",
            label = "Target Organization ID",
            required = true,
            min = 1,
        }
    end

    fields[#fields + 1] = {
        type = "number",
        label = "Amount",
        required = true,
        min = 1,
    }

    fields[#fields + 1] = {
        type = "input",
        label = "Note",
    }

    return lib.inputDialog(title, fields)
end

local function RunTreasuryAction(callbackName, payload, successMessage)
    local result =
        lib.callback.await(
            callbackName,
            false,
            payload
        )

    if not result or not result.success then
        NotifyError(
            result and result.message
                or "Treasury action failed."
        )
        return
    end

    Notify("success", successMessage)
    Client.OpenTreasuryMenu()
end

function Client.OpenTreasuryTransactionsMenu()
    local result =
        lib.callback.await(
            UI.Callbacks.GetTreasuryTransactions,
            false,
            {
                Limit = 10,
            }
        )

    if not result or not result.success then
        NotifyError(
            result and result.message
                or "Unable to load transactions."
        )
        return
    end

    local options = {}

    for _, transaction in ipairs(result.transactions or {}) do
        options[#options + 1] = {
            title = ("%s %s"):format(
                tostring(transaction.type or "transaction"),
                Money(transaction.amount)
            ),
            description = table.concat({
                ("Actor: %s"):format(transaction.actor_id or ""),
                ("Target: %s"):format(transaction.target_id or ""),
                ("Before: %s"):format(Money(transaction.balance_before)),
                ("After: %s"):format(Money(transaction.balance_after)),
                ("Note: %s"):format(transaction.note or ""),
                ("Created: %s"):format(tostring(transaction.created_at or "")),
            }, "\n"),
            disabled = true,
        }
    end

    if #options == 0 then
        options[#options + 1] = {
            title = "No transactions",
            disabled = true,
        }
    end

    options[#options + 1] = {
        title = "Back",
        onSelect = function()
            Client.OpenTreasuryMenu()
        end,
    }

    lib.registerContext({
        id = UI.Contexts.TreasuryTransactions,
        title = "Recent Transactions",
        menu = UI.Contexts.Treasury,
        options = options,
    })

    lib.showContext(UI.Contexts.TreasuryTransactions)
end

function Client.OpenTreasuryMenu()
    local result =
        lib.callback.await(
            UI.Callbacks.GetTreasury,
            false
        )

    if not result or not result.success then
        NotifyError(
            result and result.message
                or "Unable to load treasury."
        )
        return
    end

    lib.registerContext({
        id = UI.Contexts.Treasury,
        title = "Treasury",
        menu = UI.Contexts.Main,
        options = {
            {
                title = "Current Balance",
                description = Money(result.balance),
                disabled = true,
            },
            {
                title = "Deposit",
                onSelect = function()
                    local input =
                        TreasuryInput(
                            "Deposit",
                            false
                        )

                    if not input then
                        Client.OpenTreasuryMenu()
                        return
                    end

                    RunTreasuryAction(
                        UI.Callbacks.DepositTreasury,
                        {
                            Amount = input[1],
                            Note = Trim(input[2]) or "",
                        },
                        "Treasury deposit saved."
                    )
                end,
            },
            {
                title = "Withdraw",
                onSelect = function()
                    local input =
                        TreasuryInput(
                            "Withdraw",
                            false
                        )

                    if not input then
                        Client.OpenTreasuryMenu()
                        return
                    end

                    RunTreasuryAction(
                        UI.Callbacks.WithdrawTreasury,
                        {
                            Amount = input[1],
                            Note = Trim(input[2]) or "",
                        },
                        "Treasury withdrawal saved."
                    )
                end,
            },
            {
                title = "Transfer",
                onSelect = function()
                    local input =
                        TreasuryInput(
                            "Transfer",
                            true
                        )

                    if not input then
                        Client.OpenTreasuryMenu()
                        return
                    end

                    RunTreasuryAction(
                        UI.Callbacks.TransferTreasury,
                        {
                            TargetOrganizationId = input[1],
                            Amount = input[2],
                            Note = Trim(input[3]) or "",
                        },
                        "Treasury transfer saved."
                    )
                end,
            },
            {
                title = "Recent Transactions",
                onSelect = function()
                    Client.OpenTreasuryTransactionsMenu()
                end,
            },
            {
                title = "Back",
                onSelect = function()
                    Client.OpenMenu()
                end,
            },
        },
    })

    lib.showContext(UI.Contexts.Treasury)
end
