---------------------------------------------------------------------
-- GS Framework
--
-- File: modules.lua
-- Purpose:
--     Module Registration & Lifecycle Manager
--
-- Dependencies:
--     logger.lua
---------------------------------------------------------------------

GS = GS or {}

GS.Modules = {}

local Modules = GS.Modules

---------------------------------------------------------------------
-- Registry
---------------------------------------------------------------------

Modules.Registry = {}

---------------------------------------------------------------------
-- Register Module
---------------------------------------------------------------------

function Modules.Register(module)

    if type(module) ~= "table" then

        GS.Logger.Error(
            "MODULES",
            "Module registration failed (invalid table)."
        )

        return false

    end

    if not module.Name then

        GS.Logger.Error(
            "MODULES",
            "Module missing Name."
        )

        return false

    end

    if Modules.Registry[module.Name] then

        GS.Logger.Warning(
            "MODULES",
            ("Module '%s' already registered."):format(module.Name)
        )

        return false

    end

    module.Version = module.Version or "1.0.0"
    module.Priority = module.Priority or 100
    module.Enabled = true
    module.Started = false

    Modules.Registry[module.Name] = module

    GS.Logger.Success(
        "MODULES",
        ("Registered Module: %s"):format(module.Name)
    )

    return true

end

---------------------------------------------------------------------
-- Get Module
---------------------------------------------------------------------

function Modules.Get(name)

    return Modules.Registry[name]

end

---------------------------------------------------------------------
-- Count
---------------------------------------------------------------------

function Modules.Count()

    local count = 0

    for _ in pairs(Modules.Registry) do
        count = count + 1
    end

    return count

end

---------------------------------------------------------------------
-- Start Modules
---------------------------------------------------------------------

function Modules.Start()

    local ordered = {}

    for _, module in pairs(Modules.Registry) do
        ordered[#ordered + 1] = module
    end

    table.sort(ordered, function(a, b)
        return a.Priority < b.Priority
    end)

    for _, module in ipairs(ordered) do

        if module.Enabled then

            if module.Initialize then
                module.Initialize()
            end

            if module.Start then
                module.Start()
            end

            module.Started = true

            GS.Logger.Info(
                "MODULES",
                ("%s Started"):format(module.Name)
            )

        end

    end

end

---------------------------------------------------------------------
-- Stop Modules
---------------------------------------------------------------------

function Modules.Stop()

    for _, module in pairs(Modules.Registry) do

        if module.Stop then
            module.Stop()
        end

        module.Started = false

    end

end

---------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------

GS.Logger.Info(
    "MODULES",
    "Module Manager Initialized"
)