local QBCore =
    exports['qb-core']:GetCoreObject()

local mdtOpen = false

local function SetMdtOpen(open)
    mdtOpen =
        open == true

    SetNuiFocus(mdtOpen, mdtOpen)
    SendNUIMessage({
        action = mdtOpen and "open" or "close"
    })
end

local function SendMdtData(result)
    SendNUIMessage({
        action = "setData",
        ok = result and result.ok == true,
        message = result and result.message or nil,
        records = result and result.records or {}
    })
end

local function RefreshMdt()
    QBCore.Functions.TriggerCallback("gs_police:server:getMdtData", function(result)
        SendMdtData(result)
    end)
end

local function OpenMdt()
    QBCore.Functions.TriggerCallback("gs_police:server:getMdtData", function(result)
        if not result or result.ok ~= true then
            local message =
                result and result.message or "Unable to open police MDT."

            QBCore.Functions.Notify(message, "error")
            return
        end

        SetMdtOpen(true)
        SendMdtData(result)
    end)
end

RegisterCommand("police_mdt", function()
    OpenMdt()
end, false)

RegisterNetEvent("gs_police:client:openMdt", function()
    OpenMdt()
end)

RegisterNUICallback("close", function(_, cb)
    SetMdtOpen(false)
    cb({ ok = true })
end)

RegisterNUICallback("refresh", function(_, cb)
    QBCore.Functions.TriggerCallback("gs_police:server:getMdtData", function(result)
        SendMdtData(result)
        cb(result or { ok = false })
    end)
end)

RegisterNUICallback("incidentAction", function(data, cb)
    QBCore.Functions.TriggerCallback("gs_police:server:updateMdtIncident", function(result)
        if result and result.ok then
            SendMdtData(result)
        elseif result and result.message then
            QBCore.Functions.Notify(result.message, "error")
        end

        cb(result or { ok = false })
    end, data or {})
end)

CreateThread(function()
    print("[gs_police] client/main.lua loaded")

    while true do
        if mdtOpen
        and IsControlJustReleased(0, 322) then
            SetMdtOpen(false)
        end

        Wait(mdtOpen and 0 or 500)
    end
end)
