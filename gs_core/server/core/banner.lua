---------------------------------------------------------------------
-- GS Framework
--
-- File: banner.lua
-- Purpose:
--     Displays the GS Framework startup banner.
--
-- Dependencies:
--     None
---------------------------------------------------------------------

GS = GS or {}

GS.Banner = {}

local Banner = GS.Banner

---------------------------------------------------------------------
-- Display Startup Banner
---------------------------------------------------------------------

function Banner.Show()

    local version = "0.1.0-alpha"

    print("^5============================================================^7")
    print("^5                     GS FRAMEWORK^7")
    print("^5------------------------------------------------------------^7")
    print("^3 Version : ^7" .. version)
    print("^3 Author  : ^7GOAT3DG7")
    print("^3 Status  : ^7Initializing...")
    print("^5============================================================^7")

end

---------------------------------------------------------------------
-- Display Ready Banner
---------------------------------------------------------------------

function Banner.Ready(startupTime, modules)

    print("^2============================================================^7")
    print("^2                 GS FRAMEWORK READY^7")
    print("^2------------------------------------------------------------^7")
    print("^3 Modules Loaded : ^7" .. tostring(modules))
    print("^3 Startup Time   : ^7" .. tostring(startupTime) .. " ms")
    print("^2============================================================^7")

end