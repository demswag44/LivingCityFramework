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
    Invitations = "gs_organizations:invitations",
}

UI.Callbacks = {
    CreateOrganization = "gs_organizations:createOrganization",
    InvitePlayer = "gs_organizations:invitePlayer",
    AcceptInvite = "gs_organizations:acceptInvite",
    DeclineInvite = "gs_organizations:declineInvite",
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

UI.MenuItems = {
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
