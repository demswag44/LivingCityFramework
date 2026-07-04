---------------------------------------------------------------------
-- GS Framework
--
-- File: database.lua
-- Purpose:
--     Central Database Manager
--
-- Dependencies:
--     oxmysql
---------------------------------------------------------------------

GS = GS or {}

GS.Database = GS.Database or {}

local Database = GS.Database

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------

Database.State = {

    Connected = false,

    Ready = false,

    LastSave = 0

}

---------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------

function Database.Initialize()

    GS.Logger.Info(
        "DATABASE",
        "Initializing Database Manager..."
    )

    Database.State.Connected = true
    Database.State.Ready = true

    GS.Events.Emit("database:connected")

    GS.Logger.Success(
        "DATABASE",
        "Database Connected"
    )

end

---------------------------------------------------------------------
-- Shutdown
---------------------------------------------------------------------

function Database.Shutdown()

    GS.Logger.Warning(
        "DATABASE",
        "Database Manager Shutdown"
    )

end

---------------------------------------------------------------------
-- Ready
---------------------------------------------------------------------

function Database.IsReady()

    return Database.State.Ready

end

---------------------------------------------------------------------
-- Query
---------------------------------------------------------------------

function Database.Query(query, parameters, callback)

    MySQL.query(query, parameters or {}, function(result)

        if callback then
            callback(result)
        end

    end)

end

---------------------------------------------------------------------
-- Insert
---------------------------------------------------------------------

function Database.Insert(query, parameters, callback)

    MySQL.insert(query, parameters or {}, function(insertId)

        if callback then
            callback(insertId)
        end

    end)

end

---------------------------------------------------------------------
-- Update
---------------------------------------------------------------------

function Database.Update(query, parameters, callback)

    MySQL.update(query, parameters or {}, function(affectedRows)

        if callback then
            callback(affectedRows)
        end

    end)

end

---------------------------------------------------------------------
-- Execute
---------------------------------------------------------------------

function Database.Execute(query, parameters, callback)

    MySQL.execute(query, parameters or {}, function(result)

        if callback then
            callback(result)
        end

    end)

end

---------------------------------------------------------------------
-- Scalar
---------------------------------------------------------------------

function Database.Scalar(query, parameters, callback)

    MySQL.scalar(query, parameters or {}, function(value)

        if callback then
            callback(value)
        end

    end)

end

---------------------------------------------------------------------
-- Transaction
---------------------------------------------------------------------

function Database.Transaction(queries, callback)

    MySQL.transaction(queries, function(success)

        if callback then
            callback(success)
        end

    end)

end

---------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------

Database.Initialize()