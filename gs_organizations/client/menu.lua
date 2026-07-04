---------------------------------------------------------------------
-- GS Organizations
--
-- File: menu.lua
-- Purpose:
--     Production Organization menu foundation
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Client = GSOrganizations.Client or {}

local Client = GSOrganizations.Client
local UI = GSOrganizations.UI

local function ShowUnderDevelopment()
    lib.notify({
        title = UI.Config.MenuTitle,
        description = "This feature is under development.",
        type = "inform",
    })
end

local function BuildOptions()
    local options = {}

    for _, item in ipairs(UI.MenuItems) do
        if item.id == "create" then
            options[#options + 1] = {
                title = item.title,
                onSelect = function()
                    Client.OpenCreateDialog()
                end,
            }
        elseif item.id == "invitations" then
            options[#options + 1] = {
                title = item.title,
                onSelect = function()
                    Client.OpenInvitationsMenu()
                end,
            }
        elseif item.id == "close" then
            options[#options + 1] = {
                title = item.title,
                onSelect = function()
                end,
            }
        else
            options[#options + 1] = {
                title = item.title,
                onSelect = ShowUnderDevelopment,
            }
        end
    end

    return options
end

function Client.RegisterMenu()
    lib.registerContext({
        id = UI.Contexts.Main,
        title = UI.Config.MenuTitle,
        options = BuildOptions(),
    })
end

function Client.OpenMenu()
    Client.RegisterMenu()
    lib.showContext(UI.Contexts.Main)
end
