---------------------------------------------------------------------
-- GS Organizations
--
-- File: ranks.lua
-- Purpose:
--     Dynamic rank management UI
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Client = GSOrganizations.Client or {}

local Client = GSOrganizations.Client
local UI = GSOrganizations.UI

local RankState = {
    ranks = {},
    permissions = {},
    permissionSearch = "",
}

local function Trim(value)
    if type(value) ~= "string" then
        return value
    end

    return value:match("^%s*(.-)%s*$")
end

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

local function RankDescription(rank)
    return ("Weight %s | Salary $%s")
        :format(
            tostring(rank.Weight or 0),
            tostring(rank.Salary or 0)
        )
end

local function RefreshRanks()
    local result =
        lib.callback.await(
            UI.Callbacks.GetRanks,
            false
        )

    if not result or not result.success then
        NotifyError(
            result and result.message
                or "Unable to load ranks."
        )
        return false
    end

    RankState.ranks = result.ranks or {}
    RankState.permissions = result.permissions or {}

    return true
end

local function FindRank(name)
    for index, rank in ipairs(RankState.ranks) do
        if rank.Name == name then
            return rank, index
        end
    end

    return nil
end

local function SaveRank(oldName, payload, successMessage)
    payload.OldName = oldName

    local result =
        lib.callback.await(
            UI.Callbacks.UpdateRank,
            false,
            payload
        )

    if not result or not result.success then
        NotifyError(
            result and result.message
                or "Unable to save rank."
        )
        return false
    end

    Notify("success", successMessage or "Rank saved.")
    RefreshRanks()

    return true
end

local function BuildRankPayload(input, fallback)
    return {
        Name = Trim(input[1]) or fallback.Name,
        Label = Trim(input[2]) or fallback.Label,
        Weight = tonumber(input[3]),
        Salary = tonumber(input[4]) or 0,
        Color = input[5] or "",
        Icon = Trim(input[6]) or "",
        Permissions = fallback.Permissions or {},
    }
end

function Client.OpenRankEditDialog(rankName)
    local rank = FindRank(rankName)

    if not rank then
        NotifyError("Rank not found.")
        Client.OpenRanksMenu()
        return
    end

    local input = lib.inputDialog("Edit Rank", {
        {
            type = "input",
            label = "Rank Name",
            required = true,
            default = rank.Name,
            disabled = rank.Name == "Leader",
        },
        {
            type = "input",
            label = "Label",
            required = true,
            default = rank.Label,
        },
        {
            type = "number",
            label = "Weight",
            required = true,
            default = rank.Weight,
            min = 1,
        },
        {
            type = "number",
            label = "Salary",
            required = true,
            default = rank.Salary or 0,
            min = 0,
        },
        {
            type = "color",
            label = "Color",
            default = rank.Color ~= "" and rank.Color or "#D4AF37",
        },
        {
            type = "input",
            label = "Icon",
            default = rank.Icon or "",
        },
    })

    if not input then
        Client.OpenRankActionsMenu(rankName)
        return
    end

    local payload =
        BuildRankPayload(
            input,
            rank
        )

    if SaveRank(rankName, payload, "Rank updated.") then
        Client.OpenRanksMenu()
    end
end

function Client.OpenRankCreateDialog()
    local input = lib.inputDialog("Create Rank", {
        {
            type = "input",
            label = "Rank Name",
            required = true,
        },
        {
            type = "input",
            label = "Label",
            required = true,
        },
        {
            type = "number",
            label = "Weight",
            required = true,
            default = 50,
            min = 1,
        },
        {
            type = "number",
            label = "Salary",
            required = true,
            default = 0,
            min = 0,
        },
        {
            type = "color",
            label = "Color",
            default = "#D4AF37",
        },
        {
            type = "input",
            label = "Icon",
        },
    })

    if not input then
        Client.OpenRanksMenu()
        return
    end

    local payload =
        BuildRankPayload(
            input,
            {
                Permissions = {},
            }
        )

    local result =
        lib.callback.await(
            UI.Callbacks.CreateRank,
            false,
            payload
        )

    if not result or not result.success then
        NotifyError(
            result and result.message
                or "Unable to create rank."
        )
        return
    end

    Notify("success", "Rank created.")
    Client.OpenRanksMenu()
end

function Client.OpenRankCloneDialog(rankName)
    local input = lib.inputDialog("Clone Rank", {
        {
            type = "input",
            label = "New Rank Name",
            required = true,
        },
    })

    if not input then
        Client.OpenRankActionsMenu(rankName)
        return
    end

    local result =
        lib.callback.await(
            UI.Callbacks.CloneRank,
            false,
            {
                SourceName = rankName,
                Name = Trim(input[1]),
            }
        )

    if not result or not result.success then
        NotifyError(
            result and result.message
                or "Unable to clone rank."
        )
        return
    end

    Notify("success", "Rank cloned.")
    Client.OpenRanksMenu()
end

local function SwapRankWeight(rankName, direction)
    local rank, index = FindRank(rankName)

    if not rank then
        NotifyError("Rank not found.")
        return
    end

    local targetIndex = direction == "up" and index - 1 or index + 1
    local target = RankState.ranks[targetIndex]

    if not target then
        NotifyError("Rank is already at that position.")
        return
    end

    local oldWeight = rank.Weight
    local temporaryWeight = oldWeight

    for _, existing in ipairs(RankState.ranks) do
        if existing.Weight >= temporaryWeight then
            temporaryWeight = existing.Weight + 1000
        end
    end

    if not SaveRank(
        rank.Name,
        {
            Name = rank.Name,
            Label = rank.Label,
            Weight = temporaryWeight,
            Salary = rank.Salary,
            Color = rank.Color,
            Icon = rank.Icon,
            Permissions = rank.Permissions,
        },
        "Rank moved."
    ) then
        return
    end

    SaveRank(
        target.Name,
        {
            Name = target.Name,
            Label = target.Label,
            Weight = oldWeight,
            Salary = target.Salary,
            Color = target.Color,
            Icon = target.Icon,
            Permissions = target.Permissions,
        },
        "Hierarchy updated."
    )

    SaveRank(
        rank.Name,
        {
            Name = rank.Name,
            Label = rank.Label,
            Weight = target.Weight,
            Salary = rank.Salary,
            Color = rank.Color,
            Icon = rank.Icon,
            Permissions = rank.Permissions,
        },
        "Hierarchy updated."
    )

    Client.OpenRanksMenu()
end

function Client.OpenRankPermissionsMenu(rankName)
    local rank = FindRank(rankName)

    if not rank then
        NotifyError("Rank not found.")
        Client.OpenRanksMenu()
        return
    end

    local selected = rank.Permissions or {}
    local options = {
        {
            title = "Search",
            description = RankState.permissionSearch ~= ""
                and RankState.permissionSearch
                or nil,
            onSelect = function()
                local input = lib.inputDialog("Search Permissions", {
                    {
                        type = "input",
                        label = "Search",
                        default = RankState.permissionSearch,
                    },
                })

                if input then
                    RankState.permissionSearch = Trim(input[1]) or ""
                end

                Client.OpenRankPermissionsMenu(rankName)
            end,
        },
        {
            title = "Select All",
            onSelect = function()
                for _, permission in ipairs(RankState.permissions) do
                    selected[permission] = true
                end

                SaveRank(
                    rankName,
                    {
                        Name = rank.Name,
                        Label = rank.Label,
                        Weight = rank.Weight,
                        Salary = rank.Salary,
                        Color = rank.Color,
                        Icon = rank.Icon,
                        Permissions = selected,
                    },
                    "Permissions updated."
                )

                Client.OpenRankPermissionsMenu(rankName)
            end,
        },
        {
            title = "Clear All",
            onSelect = function()
                selected = {}

                SaveRank(
                    rankName,
                    {
                        Name = rank.Name,
                        Label = rank.Label,
                        Weight = rank.Weight,
                        Salary = rank.Salary,
                        Color = rank.Color,
                        Icon = rank.Icon,
                        Permissions = selected,
                    },
                    "Permissions updated."
                )

                Client.OpenRankPermissionsMenu(rankName)
            end,
        },
    }

    local search = RankState.permissionSearch:lower()

    for _, permission in ipairs(RankState.permissions) do
        if search == ""
        or permission:lower():find(search, 1, true) then
            options[#options + 1] = {
                title = permission,
                checked = selected[permission] == true,
                onSelect = function()
                    if selected[permission] then
                        selected[permission] = nil
                    else
                        selected[permission] = true
                    end

                    SaveRank(
                        rankName,
                        {
                            Name = rank.Name,
                            Label = rank.Label,
                            Weight = rank.Weight,
                            Salary = rank.Salary,
                            Color = rank.Color,
                            Icon = rank.Icon,
                            Permissions = selected,
                        },
                        "Permissions updated."
                    )

                    Client.OpenRankPermissionsMenu(rankName)
                end,
            }
        end
    end

    options[#options + 1] = {
        title = "Back",
        onSelect = function()
            RankState.permissionSearch = ""
            Client.OpenRankActionsMenu(rankName)
        end,
    }

    lib.registerContext({
        id = UI.Contexts.RankPermissions,
        title = "Permissions",
        menu = UI.Contexts.RankActions,
        options = options,
    })

    lib.showContext(UI.Contexts.RankPermissions)
end

function Client.OpenRankActionsMenu(rankName)
    local rank = FindRank(rankName)

    if not rank then
        NotifyError("Rank not found.")
        Client.OpenRanksMenu()
        return
    end

    lib.registerContext({
        id = UI.Contexts.RankActions,
        title = rank.Label or rank.Name,
        menu = UI.Contexts.Ranks,
        options = {
            {
                title = "Edit",
                description = RankDescription(rank),
                onSelect = function()
                    Client.OpenRankEditDialog(rankName)
                end,
            },
            {
                title = "Permissions",
                onSelect = function()
                    Client.OpenRankPermissionsMenu(rankName)
                end,
            },
            {
                title = "Move Up",
                onSelect = function()
                    SwapRankWeight(rankName, "up")
                end,
            },
            {
                title = "Move Down",
                onSelect = function()
                    SwapRankWeight(rankName, "down")
                end,
            },
            {
                title = "Clone Rank",
                onSelect = function()
                    Client.OpenRankCloneDialog(rankName)
                end,
            },
            {
                title = "Delete",
                disabled = rank.Name == "Leader",
                onSelect = function()
                    local result =
                        lib.callback.await(
                            UI.Callbacks.DeleteRank,
                            false,
                            {
                                Name = rank.Name,
                            }
                        )

                    if not result or not result.success then
                        NotifyError(
                            result and result.message
                                or "Unable to delete rank."
                        )
                        return
                    end

                    Notify("success", "Rank deleted.")
                    Client.OpenRanksMenu()
                end,
            },
        },
    })

    lib.showContext(UI.Contexts.RankActions)
end

function Client.OpenRanksMenu()
    if not RefreshRanks() then
        return
    end

    local options = {
        {
            title = "Create",
            onSelect = function()
                Client.OpenRankCreateDialog()
            end,
        },
        {
            title = "Reset to Defaults",
            onSelect = function()
                local result =
                    lib.callback.await(
                        UI.Callbacks.ResetRanks,
                        false
                    )

                if not result or not result.success then
                    NotifyError(
                        result and result.message
                            or "Unable to reset ranks."
                    )
                    return
                end

                Notify("success", "Ranks reset.")
                Client.OpenRanksMenu()
            end,
        },
    }

    for _, rank in ipairs(RankState.ranks) do
        options[#options + 1] = {
            title = rank.Label or rank.Name,
            description = RankDescription(rank),
            onSelect = function()
                Client.OpenRankActionsMenu(rank.Name)
            end,
        }
    end

    options[#options + 1] = {
        title = "Back",
        onSelect = function()
            Client.OpenMenu()
        end,
    }

    lib.registerContext({
        id = UI.Contexts.Ranks,
        title = "Ranks",
        menu = UI.Contexts.Main,
        options = options,
    })

    lib.showContext(UI.Contexts.Ranks)
end
