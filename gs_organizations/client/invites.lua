---------------------------------------------------------------------
-- GS Organizations
--
-- File: invites.lua
-- Purpose:
--     Organization invitation UI flow
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Client = GSOrganizations.Client or {}

local Client = GSOrganizations.Client
local UI = GSOrganizations.UI

local function Notify(result, fallbackSuccess)
    if result and result.success then
        lib.notify({
            title = UI.Config.MenuTitle,
            description = result.message or fallbackSuccess,
            type = "success",
        })

        return
    end

    lib.notify({
        title = UI.Config.MenuTitle,
        description = result and result.message
            or "Unable to complete invitation action.",
        type = "error",
    })
end

function Client.OpenInvitePlayerDialog()
    local input = lib.inputDialog("Invite Player", {
        {
            type = "number",
            label = "Player Server ID",
            required = true,
            min = 1,
        },
    })

    if not input then
        return
    end

    local result = lib.callback.await(
        UI.Callbacks.InvitePlayer,
        false,
        {
            TargetId = tonumber(input[1]),
        }
    )

    Notify(result, "Invitation sent.")
end

function Client.AcceptOldestInvite()
    local result = lib.callback.await(
        UI.Callbacks.AcceptInvite,
        false
    )

    Notify(result, "Invitation accepted.")
end

function Client.DeclineOldestInvite()
    local result = lib.callback.await(
        UI.Callbacks.DeclineInvite,
        false
    )

    Notify(result, "Invitation declined.")
end

function Client.RegisterInvitationsMenu()
    lib.registerContext({
        id = UI.Contexts.Invitations,
        title = "Invitations",
        menu = UI.Contexts.Main,
        options = {
            {
                title = "Invite Player",
                onSelect = function()
                    Client.OpenInvitePlayerDialog()
                end,
            },
            {
                title = "Accept Invite",
                onSelect = function()
                    Client.AcceptOldestInvite()
                end,
            },
            {
                title = "Decline Invite",
                onSelect = function()
                    Client.DeclineOldestInvite()
                end,
            },
            {
                title = "Back",
                menu = UI.Contexts.Main,
            },
        },
    })
end

function Client.OpenInvitationsMenu()
    Client.RegisterInvitationsMenu()
    lib.showContext(UI.Contexts.Invitations)
end
