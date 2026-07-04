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
local DashboardTerritoriesContext =
    "gs_organizations:dashboardTerritories"

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
        ("Territories: %d"):format(dashboard.TerritoryCount or 0),
        ("Pending Invites: %d"):format(dashboard.PendingInviteCount or 0),
        ("Treasury: %s"):format(Money(dashboard.Treasury)),
        ("Reputation: %s"):format(tostring(dashboard.Reputation or 0)),
        ("Influence: %s"):format(tostring(dashboard.Influence or 0)),
        ("Heat: %s"):format(tostring(dashboard.Heat or 0)),
    }, "\n")
end

local function TerritoryDescription(territory)
    return table.concat({
        ("Owner: %s"):format(
            tostring(territory.OwnerOrganizationId or "Unowned")
        ),
        ("Influence: %s"):format(tostring(territory.Influence or 0)),
        ("Heat: %s"):format(tostring(territory.Heat or 0)),
        ("Income: %s"):format(Money(territory.Income)),
        ("Population: %s"):format(tostring(territory.Population or 0)),
    }, "\n")
end

local function ActivityDescription(activity)
    return table.concat({
        ("Actor: %s"):format(activity.actor_name or ""),
        ("Type: %s"):format(activity.type or ""),
        ("Date: %s"):format(tostring(activity.created_at or "")),
        activity.description or "",
    }, "\n")
end

function Client.OpenDashboardTerritoriesMenu(territories)
    local options = {}

    for _, territory in ipairs(territories or {}) do
        options[#options + 1] = {
            title = territory.Name or "Territory",
            description = TerritoryDescription(territory),
            disabled = true,
        }
    end

    if #options == 0 then
        options[#options + 1] = {
            title = "No territories owned",
            disabled = true,
        }
    end

    options[#options + 1] = {
        title = "Back",
        onSelect = function()
            Client.OpenDashboardMenu()
        end,
    }

    lib.registerContext({
        id = DashboardTerritoriesContext,
        title = "Territories",
        menu = UI.Contexts.Dashboard,
        options = options,
    })

    lib.showContext(DashboardTerritoriesContext)
end

function Client.OpenActivityFeedMenu()
    local result =
        lib.callback.await(
            UI.Callbacks.GetActivityFeed,
            false,
            {
                Limit = 10,
            }
        )

    if not result or not result.success then
        NotifyError(
            result and result.message
                or "Unable to load activity feed."
        )
        return
    end

    local options = {}

    for _, activity in ipairs(result.activities or {}) do
        options[#options + 1] = {
            title = activity.title or "Activity",
            description = ActivityDescription(activity),
            disabled = true,
        }
    end

    if #options == 0 then
        options[#options + 1] = {
            title = "No activity yet",
            disabled = true,
        }
    end

    options[#options + 1] = {
        title = "Back",
        onSelect = function()
            Client.OpenDashboardMenu()
        end,
    }

    lib.registerContext({
        id = UI.Contexts.ActivityFeed,
        title = "Activity Feed",
        menu = UI.Contexts.Dashboard,
        options = options,
    })

    lib.showContext(UI.Contexts.ActivityFeed)
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
                title = "Territories",
                onSelect = function()
                    Client.OpenDashboardTerritoriesMenu(
                        dashboard.Territories or {}
                    )
                end,
            },
            {
                title = "Activity Feed",
                onSelect = function()
                    Client.OpenActivityFeedMenu()
                end,
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
