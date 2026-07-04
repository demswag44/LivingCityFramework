---------------------------------------------------------------------
-- GS Organizations
--
-- File: main.lua
-- Purpose:
--     Client entry point for Organization UI
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Client = GSOrganizations.Client or {}

local Client = GSOrganizations.Client
local UI = GSOrganizations.UI

local function Notify(message, notifyType)
    lib.notify({
        title = UI.Config.MenuTitle,
        description = message,
        type = notifyType or "inform",
    })
end

local function Chat(message)
    TriggerEvent(
        "chat:addMessage",
        {
            args = {
                "Organizations",
                message,
            },
        }
    )
end

local function ShowTerritory(territory)
    Chat(
        ("#%s %s | Owner: %s | Influence: %s | Heat: %s")
            :format(
                tostring(territory.Id),
                territory.Name or "Territory",
                tostring(territory.OwnerOrganizationId or "Unowned"),
                tostring(territory.Influence or 0),
                tostring(territory.Heat or 0)
            )
    )
end

local function ShowOrgHelp()
    Chat("Usage: /org menu")
    Chat("Territories: /org territory, /org territories, /org territory list")
    Chat("Details: /org territory info <territoryId>")
    Chat("Admin: /org territory reload")
end

local function HandleTerritoryCommand(args)
    local action =
        args[2]

    if type(action) == "string" then
        action = action:lower()
    end

    if not action
    or action == "" then
        action = "list"
    end

    if action == "list" then
        local result =
            lib.callback.await(
                UI.Callbacks.GetTerritories,
                false
            )

        if not result or not result.success then
            Notify(
                result and result.message
                    or "Unable to load territories.",
                "error"
            )
            return
        end

        local territories =
            result.territories or {}

        if #territories == 0 then
            Chat("No territories are loaded.")
            return
        end

        for _, territory in ipairs(territories) do
            ShowTerritory(territory)
        end

        return
    end

    if action == "info" then
        local territoryId =
            args[3]

        if not territoryId then
            Chat("Usage: /org territory info <territoryId>")
            return
        end

        local result =
            lib.callback.await(
                UI.Callbacks.GetTerritory,
                false,
                {
                    Id = territoryId,
                }
            )

        if not result or not result.success then
            Notify(
                result and result.message
                    or "Unable to load territory.",
                "error"
            )
            return
        end

        ShowTerritory(result.territory)
        return
    end

    if action == "reload" then
        local result =
            lib.callback.await(
                UI.Callbacks.ReloadTerritories,
                false
            )

        if not result or not result.success then
            Notify(
                result and result.message
                    or "Unable to reload territories.",
                "error"
            )
            return
        end

        Chat(
            ("Territories reloaded (%d loaded).")
                :format(result.count or 0)
        )
        return
    end

    ShowOrgHelp()
end

local function HandleOrgCommand(_, args)
    local action =
        args[1]

    if type(action) == "string" then
        action = action:lower()
    end

    if not action
    or action == ""
    or action == "menu" then
        Client.OpenMenu()
        return
    end

    if action == "territory"
    or action == "territories" then
        HandleTerritoryCommand(args)
        return
    end

    ShowOrgHelp()
end

CreateThread(function()
    while not Client.RegisterMenu do
        Wait(0)
    end

    Client.RegisterMenu()
end)

RegisterCommand("organizations", function()
    Client.OpenMenu()
end, false)

RegisterCommand("orgmenu", function()
    Client.OpenMenu()
end, false)

RegisterCommand("org", HandleOrgCommand, false)

CreateThread(function()
    TriggerEvent(
        "chat:addSuggestion",
        "/org",
        "Open Organizations or use territory tools.",
        {
            {
                name = "command",
                help = "menu | territory | territories | territory list | territory info <id> | territory reload",
            },
        }
    )

    TriggerEvent(
        "chat:addSuggestion",
        "/organizations",
        "Open the Organizations menu."
    )
end)
