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
