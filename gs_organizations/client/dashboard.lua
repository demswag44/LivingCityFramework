---------------------------------------------------------------------
-- GS Organizations
--
-- File: dashboard.lua
-- Purpose:
--     Organization dashboard UI
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Client = GSOrganizations.Client or {}

local Client = GSOrganizations.Client
local UI = GSOrganizations.UI

local function NotifyError(message)
    lib.notify({
        title = UI.Config.MenuTitle,
        description = message,
        type = "error",
    })
end

local function Money(value)
    return ("$%s"):format(tostring(value or 0))
end

local function DescriptionLines(dashboard)
    return table.concat({
        ("Type: %s"):format(dashboard.Type or "Unknown"),
        ("Description: %s"):format(dashboard.Description or ""),
        ("Primary Color: %s"):format(dashboard.PrimaryColor or ""),
        ("Secondary Color: %s"):format(dashboard.SecondaryColor or ""),
        ("Icon: %s"):format(dashboard.Icon or ""),
        ("Founder: %s"):format(dashboard.Founder or ""),
        ("Leader: %s"):format(dashboard.Leader or ""),
        ("Members: %d"):format(dashboard.MemberCount or 0),
        ("Ranks: %d"):format(dashboard.RankCount or 0),
        ("Pending Invites: %d"):format(dashboard.PendingInviteCount or 0),
        ("Treasury: %s"):format(Money(dashboard.Treasury)),
        ("Reputation: %s"):format(tostring(dashboard.Reputation or 0)),
        ("Influence: %s"):format(tostring(dashboard.Influence or 0)),
        ("Heat: %s"):format(tostring(dashboard.Heat or 0)),
    }, "\n")
end

function Client.OpenDashboardMenu()
    local result =
        lib.callback.await(
            UI.Callbacks.GetOrganizationDashboard,
            false
        )

    if not result or not result.success then
        NotifyError(
            result and result.message
                or "Unable to load dashboard."
        )
        return
    end

    local dashboard =
        result.dashboard or {}

    lib.registerContext({
        id = UI.Contexts.Dashboard,
        title = "Organizations Dashboard",
        menu = UI.Contexts.Main,
        options = {
            {
                title = dashboard.Name or "Organization",
                description = DescriptionLines(dashboard),
                disabled = true,
            },
            {
                title = "Members",
                onSelect = function()
                    lib.notify({
                        title = UI.Config.MenuTitle,
                        description = "This feature is under development.",
                        type = "inform",
                    })
                end,
            },
            {
                title = "Ranks",
                onSelect = function()
                    Client.OpenRanksMenu()
                end,
            },
            {
                title = "Invitations",
                onSelect = function()
                    Client.OpenInvitationsMenu()
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

    lib.showContext(UI.Contexts.Dashboard)
end
