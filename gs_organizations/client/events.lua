---------------------------------------------------------------------
-- GS Organizations
--
-- File: events.lua
-- Purpose:
--     Client Organization UI events
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Client = GSOrganizations.Client or {}

local Client = GSOrganizations.Client
local UI = GSOrganizations.UI

RegisterNetEvent(UI.Events.OpenMenu, function()
    Client.OpenMenu()
end)

RegisterNetEvent(UI.Events.OrganizationCreated, function()
    lib.notify({
        title = UI.Config.MenuTitle,
        description = "Organization created.",
        type = "success",
    })
end)
