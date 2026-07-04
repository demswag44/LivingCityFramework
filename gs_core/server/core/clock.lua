---------------------------------------------------------------------
-- GS Framework
--
-- File: clock.lua
-- Purpose:
--     Central World Clock and Task Scheduler.
--
-- Dependencies:
--     logger.lua
---------------------------------------------------------------------

GS = GS or {}

GS.Clock = {}

local Clock = GS.Clock

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------

Clock.Tasks = {}
Clock.NextId = 1
Clock.Running = false

---------------------------------------------------------------------
-- Register Recurring Task
---------------------------------------------------------------------

function Clock.Every(interval, callback)

    local id = Clock.NextId

    Clock.NextId = Clock.NextId + 1

    Clock.Tasks[id] = {
        Id = id,
        Type = "Recurring",
        Interval = interval,
        Callback = callback,
        LastRun = GetGameTimer(),
        Enabled = true
    }

    GS.Logger.Debug(
        "CLOCK",
        ("Recurring Task Registered #%d (%dms)"):format(id, interval)
    )

    return id

end

---------------------------------------------------------------------
-- Register Delayed Task
---------------------------------------------------------------------

function Clock.After(delay, callback)

    local id = Clock.NextId

    Clock.NextId = Clock.NextId + 1

    Clock.Tasks[id] = {
        Id = id,
        Type = "Delayed",
        Interval = delay,
        Callback = callback,
        LastRun = GetGameTimer(),
        Enabled = true
    }

    GS.Logger.Debug(
        "CLOCK",
        ("Delayed Task Registered #%d (%dms)"):format(id, delay)
    )

    return id

end

---------------------------------------------------------------------
-- Remove Task
---------------------------------------------------------------------

function Clock.Remove(id)

    Clock.Tasks[id] = nil

end

---------------------------------------------------------------------
-- Pause Task
---------------------------------------------------------------------

function Clock.Pause(id)

    if Clock.Tasks[id] then
        Clock.Tasks[id].Enabled = false
    end

end

---------------------------------------------------------------------
-- Resume Task
---------------------------------------------------------------------

function Clock.Resume(id)

    if Clock.Tasks[id] then
        Clock.Tasks[id].Enabled = true
        Clock.Tasks[id].LastRun = GetGameTimer()
    end

end

---------------------------------------------------------------------
-- Task Exists
---------------------------------------------------------------------

function Clock.Exists(id)

    return Clock.Tasks[id] ~= nil

end

---------------------------------------------------------------------
-- Main Clock Loop
---------------------------------------------------------------------

CreateThread(function()

    Clock.Running = true

    GS.Logger.Info("CLOCK", "World Clock Started")

    while true do

        local now = GetGameTimer()

        for id, task in pairs(Clock.Tasks) do

            if task.Enabled then

                if now - task.LastRun >= task.Interval then

                    task.LastRun = now

                    local success, err = pcall(task.Callback)

                    if not success then

                        GS.Logger.Error(
                            "CLOCK",
                            ("Task #%d Failed: %s"):format(id, err)
                        )

                    end

                    if task.Type == "Delayed" then
                        Clock.Tasks[id] = nil
                    end

                end

            end

        end

        Wait(100)

    end

end)

---------------------------------------------------------------------
-- Statistics
---------------------------------------------------------------------

function Clock.Count()

    local count = 0

    for _ in pairs(Clock.Tasks) do
        count = count + 1
    end

    return count

end

---------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------

GS.Logger.Info("CLOCK", "Clock System Initialized")