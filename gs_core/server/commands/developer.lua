---------------------------------------------------------------------
-- GS Framework
--
-- File: developer.lua
-- Purpose:
--     Developer Commands
---------------------------------------------------------------------

GS = GS or {}

---------------------------------------------------------------------
-- GS Status
---------------------------------------------------------------------

RegisterCommand("gs.status", function(source)

    if source ~= 0 then
        return
    end

    print("")
    print("==================================================")
    print("                GS FRAMEWORK")
    print("==================================================")

    print(("Version         : %s"):format(
    GS.Config.Version or "Unknown"
))

print(("Environment     : %s"):format(
    GS.Config.Environment or "Unknown"
))

print(("Framework Ready : %s"):format(
    tostring(GS.Bootstrap.IsReady())
))

    print(("Database Ready  : %s"):format(
        tostring(GS.Database.IsReady())
    ))

    print(("Modules Loaded  : %d"):format(
        GS.Modules.Count()
    ))

    print(("Clock Tasks     : %d"):format(
        GS.Clock.Count()
    ))

    print("==================================================")
    print("")

end, true)