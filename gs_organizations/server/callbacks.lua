---------------------------------------------------------------------
-- GS Organizations
--
-- File: callbacks.lua
-- Purpose:
--     Server callbacks for Organization UI
---------------------------------------------------------------------

local UI = GSOrganizations.UI
local Organization = GSOrganizations.Manager

local function Trim(value)
    if type(value) ~= "string" then
        return value
    end

    return value:match("^%s*(.-)%s*$")
end

local function Error(message)
    return {
        success = false,
        message = message,
    }
end

local function GetFounderId(source)
    return tostring(source)
end

lib.callback.register(UI.Callbacks.CreateOrganization, function(source, data)
    if type(data) ~= "table" then
        return Error("Invalid organization data.")
    end

    local name = Trim(data.Name)

    if not name or name == "" then
        return Error("Organization Name is required.")
    end

    if name:len() > UI.Config.MaxNameLength then
        return Error(
            ("Organization Name must be %d characters or fewer.")
                :format(UI.Config.MaxNameLength)
        )
    end

    if not data.Type or data.Type == "" then
        return Error("Organization Type is required.")
    end

    if not UI.IsHexColor(data.PrimaryColor) then
        return Error("Primary Color is required.")
    end

    if not UI.IsHexColor(data.SecondaryColor) then
        return Error("Secondary Color is required.")
    end

    if Organization.NameExists(name) then
        return Error("Organization name already exists.")
    end

    local organization, reason = Organization.Create({
        Name = name,
        Type = data.Type,
        Description = Trim(data.Description) or "",
        Founder = GetFounderId(source),
        Tag = "",
        PrimaryColor = data.PrimaryColor,
        SecondaryColor = data.SecondaryColor,
        Icon = Trim(data.Icon) or "",
    })

    if not organization then
        return Error(reason or "Unable to create organization.")
    end

    TriggerClientEvent(
        UI.Events.OrganizationCreated,
        source,
        organization.Id
    )

    return {
        success = true,
        organizationId = organization.Id,
    }
end)
