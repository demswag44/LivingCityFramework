---------------------------------------------------------------------
-- GS Organizations
--
-- File: audit.lua
-- Purpose:
--     Security Audit System
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------

local Security = GSOrganizations.Security

local Logger = exports["gs_core"]:Logger()

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------

Security.Audit = Security.Audit or {}

local Audit = Security.Audit

Audit.Logs = {}

---------------------------------------------------------------------
-- Write
---------------------------------------------------------------------

function Audit.Write(action, data)

    local entry = {

        Timestamp = os.time(),

        Action = action,

        Data = data or {}

    }

    table.insert(Audit.Logs, entry)

    Logger.Info(

        "AUDIT",

        ("[%s] %s")
            :format(
                os.date("%H:%M:%S"),
                action
            )

    )

    TriggerEvent(
        "gs:security:audit",
        entry
    )

    return entry

end

---------------------------------------------------------------------
-- Get All
---------------------------------------------------------------------

function Audit.GetLogs()

    return Audit.Logs

end

---------------------------------------------------------------------
-- Count
---------------------------------------------------------------------

function Audit.Count()

    return #Audit.Logs

end

---------------------------------------------------------------------
-- Clear
---------------------------------------------------------------------

function Audit.Clear()

    Audit.Logs = {}

    Logger.Warning(
        "AUDIT",
        "Audit Log Cleared"
    )

end

---------------------------------------------------------------------
-- Print
---------------------------------------------------------------------

function Audit.Print()

    Logger.Info(

        "AUDIT",

        ("Audit Entries: %d")
            :format(#Audit.Logs)

    )

    for _, log in ipairs(Audit.Logs) do

        Logger.Info(

            "AUDIT",

            ("%s | %s")
                :format(

                    os.date(
                        "%H:%M:%S",
                        log.Timestamp
                    ),

                    log.Action

                )

        )

    end

end