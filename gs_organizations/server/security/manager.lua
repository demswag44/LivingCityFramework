---------------------------------------------------------------------
-- GS Organizations
--
-- File: manager.lua
-- Purpose:
--     Security Subsystem Bootstrap
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Module
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}

GSOrganizations.Security = GSOrganizations.Security or {}

local Security = GSOrganizations.Security

---------------------------------------------------------------------
-- Logger
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------

Security.State = {

    Ready = false,

    Loaded = false,

    Version = "1.0.0"

}

---------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------

function Security.Initialize()

    if Security.State.Ready then
        return
    end

    Logger.Info(

        "SECURITY",

        "Initializing Security System..."

    )

    Security.State.Ready = true
    Security.State.Loaded = true

    Logger.Success(

        "SECURITY",

        "Security Manager Initialized"

    )

end

---------------------------------------------------------------------
-- Is Ready
---------------------------------------------------------------------

function Security.IsReady()

    return Security.State.Ready

end

---------------------------------------------------------------------
-- Version
---------------------------------------------------------------------

function Security.GetVersion()

    return Security.State.Version

end

---------------------------------------------------------------------
-- Shutdown
---------------------------------------------------------------------

function Security.Shutdown()

    Security.State.Ready = false

    Logger.Warning(

        "SECURITY",

        "Security Manager Shutdown"

    )

end

---------------------------------------------------------------------
-- Export
---------------------------------------------------------------------

return Security