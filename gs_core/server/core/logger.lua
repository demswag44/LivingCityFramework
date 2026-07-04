---------------------------------------------------------------------
-- GS Framework
--
-- File: logger.lua
-- Purpose:
--     Central logging system for the entire framework.
--
-- Dependencies:
--     shared/manifest.lua
---------------------------------------------------------------------

GS = GS or {}

GS.Logger = {}

local Logger = GS.Logger

---------------------------------------------------------------------
-- Log Levels
---------------------------------------------------------------------

Logger.Level = {

    DEBUG   = "^5DEBUG^7",
    INFO    = "^3INFO^7",
    SUCCESS = "^2SUCCESS^7",
    WARNING = "^3WARNING^7",
    ERROR   = "^1ERROR^7"

}

---------------------------------------------------------------------
-- Timestamp
---------------------------------------------------------------------

local function Timestamp()

    return os.date("%H:%M:%S")

end

---------------------------------------------------------------------
-- Internal Print
---------------------------------------------------------------------

local function Print(level, module, message)

    print(("[%-8s] [%s] [%s] %s"):format(

        level,

        Timestamp(),

        module,

        tostring(message)

    ))

end

---------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------

function Logger.Debug(module, message)

    if GS.Config and GS.Config.Debug == false then
        return
    end

    Print(Logger.Level.DEBUG, module, message)

end

---------------------------------------------------------------------
-- Info
---------------------------------------------------------------------

function Logger.Info(module, message)

    Print(Logger.Level.INFO, module, message)

end

---------------------------------------------------------------------
-- Success
---------------------------------------------------------------------

function Logger.Success(module, message)

    Print(Logger.Level.SUCCESS, module, message)

end

---------------------------------------------------------------------
-- Warning
---------------------------------------------------------------------

function Logger.Warning(module, message)

    Print(Logger.Level.WARNING, module, message)

end

---------------------------------------------------------------------
-- Error
---------------------------------------------------------------------

function Logger.Error(module, message)

    Print(Logger.Level.ERROR, module, message)

end

---------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------

Logger.Info("LOGGER", "Logger Initialized")