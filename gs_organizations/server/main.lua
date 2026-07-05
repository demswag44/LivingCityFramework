---------------------------------------------------------------------
-- GS Organizations
--
-- File: main.lua
-- Purpose:
--     Organization Module Startup
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

---------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------

GSOrganizations.Database.Initialize()

GSOrganizations.Manager.Initialize()

GSOrganizations.Security.Initialize()

GSOrganizations.Ranks.Initialize()

GSOrganizations.Territories.Initialize()

if GSOrganizations.TerritoryZones
and GSOrganizations.TerritoryZones.Initialize then
    GSOrganizations.TerritoryZones.Initialize()
else
    Logger.Warning(
        "TERRITORY ZONES",
        "Territory zone module was not available during startup."
    )
end

if GSOrganizations.TerritoryEditor
and GSOrganizations.TerritoryEditor.Initialize then
    GSOrganizations.TerritoryEditor.Initialize()
end

---------------------------------------------------------------------
-- Load Organizations
---------------------------------------------------------------------

CreateThread(function()

    local result = GSOrganizations.Repository.Organizations.GetAll()

    GSOrganizations.Manager.LoadAll(result)

    Logger.Success(
        "ORGANIZATIONS",
        ("Database Load Complete (%d organizations)")
            :format(#result)
    )

    Logger.Success(
        "ORGANIZATIONS",
        "Organizations Module Started"
    )

end)
