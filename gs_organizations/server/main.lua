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
