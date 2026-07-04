---------------------------------------------------------------------
-- GS Organizations
--
-- File: manager.lua
-- Purpose:
--     Organization Runtime Manager
---------------------------------------------------------------------

---------------------------------------------------------------------
-- GS Core
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

local Config = GS.OrganizationConfig

---------------------------------------------------------------------
-- Module
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Manager = GSOrganizations.Manager or {}

local Organization = GSOrganizations.Manager

---------------------------------------------------------------------
-- Runtime State
---------------------------------------------------------------------

Organization.List = Organization.List or {}

-- Temporary until MySQL becomes the sole source of IDs.
Organization.NextId = Organization.NextId or 1

---------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------

function Organization.Initialize()

    Logger.Info(
        "ORGANIZATIONS",
        "Organization Manager Initialized"
    )

end

---------------------------------------------------------------------
-- Count
---------------------------------------------------------------------

function Organization.Count()

    local count = 0

    for _ in pairs(Organization.List) do
        count = count + 1
    end

    return count

end

---------------------------------------------------------------------
-- Exists
---------------------------------------------------------------------

function Organization.Exists(id)

    return Organization.List[id] ~= nil

end

---------------------------------------------------------------------
-- Get
---------------------------------------------------------------------

function Organization.Get(id)

    return Organization.List[id]

end

---------------------------------------------------------------------
-- Get All
---------------------------------------------------------------------

function Organization.GetAll()

    return Organization.List

end

---------------------------------------------------------------------
-- Name Exists
---------------------------------------------------------------------

function Organization.NameExists(name)

    if not name then
        return false
    end

    for _, organization in pairs(Organization.List) do

        if organization.Name
        and organization.Name:lower() == name:lower() then
            return true
        end

    end

    return false

end

---------------------------------------------------------------------
-- Validate
---------------------------------------------------------------------

function Organization.Validate(data)

    if type(data) ~= "table" then
        return false, "Invalid organization data."
    end

    if not data.Name or data.Name == "" then
        return false, "Organization name is required."
    end

    if Organization.NameExists(data.Name) then
        return false, "Organization name already exists."
    end

    data.Type = data.Type or Config.DefaultType

    if not Config.Types[data.Type] then
        return false,
            ("Invalid organization type: %s")
                :format(tostring(data.Type))
    end

    return true

end

---------------------------------------------------------------------
-- Register
--
-- Adds an organization to runtime.
---------------------------------------------------------------------

function Organization.Register(organization)

    Organization.List[organization.Id] = organization

    return organization

end

---------------------------------------------------------------------
-- Unregister
---------------------------------------------------------------------

function Organization.Unregister(id)

    Organization.List[id] = nil

end

---------------------------------------------------------------------
-- Export
---------------------------------------------------------------------

return Organization