---------------------------------------------------------------------
-- GS Organizations
--
-- File: create.lua
-- Purpose:
--     Create Organization UI flow
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Client = GSOrganizations.Client or {}

local Client = GSOrganizations.Client
local UI = GSOrganizations.UI

local function Trim(value)
    if type(value) ~= "string" then
        return value
    end

    return value:match("^%s*(.-)%s*$")
end

local function NotifyError(message)
    lib.notify({
        title = UI.Config.MenuTitle,
        description = message,
        type = "error",
    })
end

function Client.OpenCreateDialog()
    local input = lib.inputDialog("Create Organization", {
        {
            type = "input",
            label = "Organization Name",
            required = true,
            max = UI.Config.MaxNameLength,
        },
        {
            type = "select",
            label = "Organization Type",
            required = true,
            options = UI.OrganizationTypes,
        },
        {
            type = "textarea",
            label = "Description",
            autosize = true,
        },
        UI.GetColorInput(
            "Primary Color",
            UI.Config.DefaultPrimaryColor
        ),
        UI.GetColorInput(
            "Secondary Color",
            UI.Config.DefaultSecondaryColor
        ),
        {
            type = "input",
            label = "Organization Icon (placeholder)",
        },
    })

    if not input then
        return
    end

    local payload = {
        Name = Trim(input[1]),
        Type = input[2],
        Description = Trim(input[3]) or "",
        PrimaryColor = input[4],
        SecondaryColor = input[5],
        Icon = Trim(input[6]) or "",
    }

    if not payload.Name or payload.Name == "" then
        NotifyError("Organization Name is required.")
        return
    end

    if payload.Name:len() > UI.Config.MaxNameLength then
        NotifyError(
            ("Organization Name must be %d characters or fewer.")
                :format(UI.Config.MaxNameLength)
        )
        return
    end

    if not payload.Type or payload.Type == "" then
        NotifyError("Organization Type is required.")
        return
    end

    if not UI.IsHexColor(payload.PrimaryColor) then
        NotifyError("Primary Color is required.")
        return
    end

    if not UI.IsHexColor(payload.SecondaryColor) then
        NotifyError("Secondary Color is required.")
        return
    end

    local result = lib.callback.await(
        UI.Callbacks.CreateOrganization,
        false,
        payload
    )

    if not result or not result.success then
        NotifyError(
            result and result.message
                or "Unable to create organization."
        )
        return
    end

    lib.notify({
        title = UI.Config.MenuTitle,
        description = "Organization created.",
        type = "success",
    })
end
