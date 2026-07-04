---------------------------------------------------------------------
-- GS Organizations
--
-- File: ui.lua
-- Purpose:
--     Production Organization UI shared configuration
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.UI = GSOrganizations.UI or {}

local UI = GSOrganizations.UI

UI.Contexts = {
    Main = "gs_organizations:main",
    Dashboard = "gs_organizations:dashboard",
    ActivityFeed = "gs_organizations:activityFeed",
    Treasury = "gs_organizations:treasury",
    TreasuryTransactions = "gs_organizations:treasuryTransactions",
    Invitations = "gs_organizations:invitations",
    Ranks = "gs_organizations:ranks",
    RankActions = "gs_organizations:rankActions",
    RankPermissions = "gs_organizations:rankPermissions",
}

UI.Callbacks = {
    CreateOrganization = "gs_organizations:createOrganization",
    GetOrganizationDashboard = "gs_organizations:getOrganizationDashboard",
    GetActivityFeed = "gs_organizations:getActivityFeed",
    GetTerritories = "gs_organizations:getTerritories",
    GetTerritory = "gs_organizations:getTerritory",
    ReloadTerritories = "gs_organizations:reloadTerritories",
    GetTreasury = "gs_organizations:getTreasury",
    DepositTreasury = "gs_organizations:depositTreasury",
    WithdrawTreasury = "gs_organizations:withdrawTreasury",
    TransferTreasury = "gs_organizations:transferTreasury",
    GetTreasuryTransactions = "gs_organizations:getTreasuryTransactions",
    InvitePlayer = "gs_organizations:invitePlayer",
    AcceptInvite = "gs_organizations:acceptInvite",
    DeclineInvite = "gs_organizations:declineInvite",
    GetRanks = "gs_organizations:getRanks",
    CreateRank = "gs_organizations:createRank",
    UpdateRank = "gs_organizations:updateRank",
    DeleteRank = "gs_organizations:deleteRank",
    CloneRank = "gs_organizations:cloneRank",
    ResetRanks = "gs_organizations:resetRanks",
}

UI.Events = {
    OpenMenu = "gs_organizations:client:openMenu",
    OpenPhoneApp = "gs_organizations:client:openPhoneApp",
    OrganizationCreated = "gs_organizations:client:organizationCreated",
}

UI.Config = {
    MenuTitle = "Organizations",
    MaxNameLength = 64,
    DefaultPrimaryColor = "#D4AF37",
    DefaultSecondaryColor = "#111111",
    EnableQbPhoneApp = true,
    PhoneAppName = "organizations",
    PhoneAppLabel = "Organizations",
    PhoneAppIcon = "fas fa-users",
}

UI.OrganizationTypes = {
    { label = "Gang", value = "Gang" },
    { label = "Cartel", value = "Cartel" },
    { label = "Motorcycle Club", value = "MotorcycleClub" },
    { label = "Mafia", value = "Mafia" },
    { label = "Business", value = "Business" },
    { label = "Security", value = "Security" },
    { label = "Government", value = "Government" },
    { label = "Police", value = "Police" },
    { label = "EMS", value = "EMS" },
    { label = "Custom", value = "Custom" },
}

function UI.GetRankTemplateOptions()
    local options = {}

    for name, template in pairs(GS.OrganizationRankTemplates or {}) do
        options[#options + 1] = {
            label = template.Label or name,
            value = name,
        }
    end

    table.sort(options, function(left, right)
        return left.label < right.label
    end)

    return options
end

function UI.GetDefaultRankTemplateForType(organizationType)
    local templates =
        GS.OrganizationRankTemplates or {}

    if templates[organizationType] then
        return organizationType
    end

    return "Custom"
end

UI.MenuItems = {
    { id = "dashboard", title = "Dashboard" },
    { id = "create", title = "Create Organization" },
    { id = "my_organization", title = "My Organization" },
    { id = "members", title = "Members" },
    { id = "leadership", title = "Leadership" },
    { id = "ranks", title = "Ranks" },
    { id = "invitations", title = "Invitations" },
    { id = "treasury", title = "Treasury" },
    { id = "relationships", title = "Relationships" },
    { id = "settings", title = "Settings" },
    { id = "close", title = "Close" },
}

UI.FutureTabs = {
    "Members",
    "Leadership",
    "Ranks",
    "Treasury",
    "Businesses",
    "Properties",
    "Territories",
    "War Room",
    "Diplomacy",
    "AI Members",
}

function UI.GetColorInput(label, defaultValue)
    return {
        type = "color",
        label = label,
        required = true,
        default = defaultValue,
    }
end

function UI.IsHexColor(value)
    return type(value) == "string"
        and value:match("^#%x%x%x%x%x%x$") ~= nil
end
