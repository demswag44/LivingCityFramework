---------------------------------------------------------------------
-- GS Organizations
--
-- File: manager.lua
-- Purpose:
--     Rank Runtime Manager
---------------------------------------------------------------------

---------------------------------------------------------------------
-- GS Core
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

---------------------------------------------------------------------
-- Module
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}

GSOrganizations.Ranks = GSOrganizations.Ranks or {}

local Ranks = GSOrganizations.Ranks

---------------------------------------------------------------------
-- Runtime State
---------------------------------------------------------------------

Ranks.List = Ranks.List or {}

Ranks.Ready = false

Ranks.Version = "1.0.0"

---------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------

function Ranks.Initialize()

    if Ranks.Ready then
        return
    end

    Logger.Info(

        "RANKS",

        "Initializing Rank Manager..."

    )

    Ranks.Ready = true

    Logger.Success(

        "RANKS",

        "Rank Manager Initialized"

    )

end

---------------------------------------------------------------------
-- Shutdown
---------------------------------------------------------------------

function Ranks.Shutdown()

    Ranks.Ready = false

    Logger.Warning(

        "RANKS",

        "Rank Manager Shutdown"

    )

end

---------------------------------------------------------------------
-- Ready
---------------------------------------------------------------------

function Ranks.IsReady()

    return Ranks.Ready

end

---------------------------------------------------------------------
-- Version
---------------------------------------------------------------------

function Ranks.GetVersion()

    return Ranks.Version

end

---------------------------------------------------------------------
-- Runtime Count
---------------------------------------------------------------------

function Ranks.Count()

    local count = 0

    for _ in pairs(Ranks.List) do

        count = count + 1

    end

    return count

end

---------------------------------------------------------------------
-- Export
---------------------------------------------------------------------

return Ranks