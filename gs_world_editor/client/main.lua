---------------------------------------------------------------------
-- GS World Editor
--
-- File: main.lua
-- Purpose:
--     Client entry point for future UI integrations
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.Client = GSWorldEditor.Client or {}

RegisterNetEvent("gs_world_editor:notify", function(message)
    TriggerEvent("chat:addMessage", {
        args = {
            "World Editor",
            message,
        },
    })
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if GSWorldEditor.SavePipeline then
        print("[WORLD EDITOR] Save Pipeline Initialized.")
    else
        print("[WORLD EDITOR] Save Pipeline unavailable.")
    end

    TriggerEvent("chat:addSuggestion", "/gswe", "GS World Editor", {
        {
            name = "command",
            help = "tools | start territories | status | undo | redo | save | cancel | stop",
        },
    })
    TriggerEvent("chat:addSuggestion", "/gswe tools", "List World Editor tools")
    TriggerEvent("chat:addSuggestion", "/gswe start territories", "Start Territory Editor")
    TriggerEvent("chat:addSuggestion", "/gswe status", "Show editor status")
    TriggerEvent("chat:addSuggestion", "/gswe undo", "Undo the last editor change")
    TriggerEvent("chat:addSuggestion", "/gswe redo", "Redo the last undone editor change")
    TriggerEvent("chat:addSuggestion", "/gswe save", "Save editor changes placeholder")
    TriggerEvent("chat:addSuggestion", "/gswe cancel", "Cancel editor session")
    TriggerEvent("chat:addSuggestion", "/gswe stop", "Stop editor session")
    TriggerServerEvent("gs_world_editor:getSession")
end)

AddEventHandler("onClientResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    TriggerEvent("chat:removeSuggestion", "/gswe")
    TriggerEvent("chat:removeSuggestion", "/gswe tools")
    TriggerEvent("chat:removeSuggestion", "/gswe status")
    TriggerEvent("chat:removeSuggestion", "/gswe start territories")
    TriggerEvent("chat:removeSuggestion", "/gswe undo")
    TriggerEvent("chat:removeSuggestion", "/gswe redo")
    TriggerEvent("chat:removeSuggestion", "/gswe save")
    TriggerEvent("chat:removeSuggestion", "/gswe cancel")
    TriggerEvent("chat:removeSuggestion", "/gswe stop")
end)
