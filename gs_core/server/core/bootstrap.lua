---------------------------------------------------------------------
-- GS Framework
--
-- File: bootstrap.lua
-- Purpose:
--     Framework Bootstrap Manager
--
-- Dependencies:
--     logger.lua
--     cache.lua
--     events.lua
--     database.lua
--     clock.lua
--     modules.lua
---------------------------------------------------------------------

GS = GS or {}

GS.Bootstrap = {}

local Bootstrap = GS.Bootstrap

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------

Bootstrap.State = {
    Starting = false,
    Ready = false,
    StartTime = 0,
    EndTime = 0
}

---------------------------------------------------------------------
-- Start Framework
---------------------------------------------------------------------

function Bootstrap.Start()

    Bootstrap.State.Starting = true
    Bootstrap.State.StartTime = GetGameTimer()

    GS.Logger.Info("BOOT", "Starting GS Framework...")

    ---------------------------------------------------------
    -- Framework State
    ---------------------------------------------------------

    GS.Cache.Framework = GS.Cache.Framework or {}

    GS.Cache.Framework.State = "STARTING"

    ---------------------------------------------------------
    -- Start Registered Modules
    ---------------------------------------------------------

    if GS.Modules.Count() > 0 then
    GS.Modules.Start()
end

    ---------------------------------------------------------
    -- Finish
    ---------------------------------------------------------

    Bootstrap.State.EndTime = GetGameTimer()

    local elapsed = Bootstrap.State.EndTime - Bootstrap.State.StartTime

    Bootstrap.State.Starting = false
    Bootstrap.State.Ready = true

    GS.Cache.Framework.Ready = true
    GS.Cache.Framework.StartupTime = elapsed

    GS.Events.Emit("framework:ready")

    GS.Logger.Success(
        "BOOT",
        ("Framework Ready (%d ms)"):format(elapsed)
    )

    local moduleCount = GS.Modules.Count()

    GS.Logger.Info(
        "BOOT",
        ("Modules Loaded: %d"):format(moduleCount)
    )

    if moduleCount == 0 then
        GS.Logger.Warning(
            "BOOT",
            "No gameplay modules have registered yet."
        )
    end

end

---------------------------------------------------------------------
-- Ready?
---------------------------------------------------------------------

function Bootstrap.IsReady()

    return Bootstrap.State.Ready

end