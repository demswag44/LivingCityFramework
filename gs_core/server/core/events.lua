---------------------------------------------------------------------
-- GS Framework
--
-- File: events.lua
-- Purpose:
--     Internal Event Bus
--
-- Dependencies:
--     logger.lua
---------------------------------------------------------------------

GS = GS or {}

GS.Events = {}

local Events = GS.Events

---------------------------------------------------------------------
-- Registered Events
---------------------------------------------------------------------

Events.Listeners = {}

---------------------------------------------------------------------
-- Register Listener
---------------------------------------------------------------------

function Events.On(eventName, callback)

    if type(callback) ~= "function" then
        GS.Logger.Error("EVENTS", ("Invalid callback for '%s'"):format(eventName))
        return false
    end

    Events.Listeners[eventName] = Events.Listeners[eventName] or {}

    table.insert(Events.Listeners[eventName], callback)

    GS.Logger.Debug("EVENTS", ("Listener registered: %s"):format(eventName))

    return true

end

---------------------------------------------------------------------
-- Remove Listener
---------------------------------------------------------------------

function Events.Off(eventName)

    Events.Listeners[eventName] = nil

    GS.Logger.Debug("EVENTS", ("Listener removed: %s"):format(eventName))

end

---------------------------------------------------------------------
-- Emit Event
---------------------------------------------------------------------

function Events.Emit(eventName, data)

    local listeners = Events.Listeners[eventName]

    if not listeners then
        return
    end

    for _, callback in ipairs(listeners) do

        local success, err = pcall(callback, data)

        if not success then
            GS.Logger.Error(
                "EVENTS",
                ("Event '%s' failed: %s"):format(eventName, err)
            )
        end

    end

end

---------------------------------------------------------------------
-- Count Listeners
---------------------------------------------------------------------

function Events.Count(eventName)

    local listeners = Events.Listeners[eventName]

    if not listeners then
        return 0
    end

    return #listeners

end

---------------------------------------------------------------------
-- Clear All Events
---------------------------------------------------------------------

function Events.Clear()

    Events.Listeners = {}

end

---------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------

GS.Logger.Info("EVENTS", "Event Bus Initialized")