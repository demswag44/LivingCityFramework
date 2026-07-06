local QBCore =
    exports["qb-core"]:GetCoreObject()

print("[gs_police] client/moving_target.lua loaded")

local ActiveTrackedTargets = {}

local function DebugPrint(...)
    if Config
    and Config.MovingTargets
    and Config.MovingTargets.debug then
        print("[gs_police:moving_target]", ...)
    end
end

local function Notify(message, notifyType)
    if QBCore
    and QBCore.Functions
    and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, notifyType or "primary")
    end
end

local function ToCoordsTable(coords)
    if not coords then
        return nil
    end

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z
    }
end

local function GetVehiclePlate(vehicle)
    if not vehicle
    or vehicle == 0
    or not DoesEntityExist(vehicle) then
        return nil
    end

    return string.gsub(GetVehicleNumberPlateText(vehicle) or "", "^%s*(.-)%s*$", "%1")
end

local function FindVehicleForTarget(target)
    if target.netId then
        local netId =
            tonumber(target.netId)

        if netId
        and NetworkDoesNetworkIdExist(netId) then
            local entity =
                NetworkGetEntityFromNetworkId(netId)

            if entity
            and entity ~= 0
            and DoesEntityExist(entity)
            and GetEntityType(entity) == 2 then
                return entity
            end
        end
    end

    if not target.plate
    or target.plate == "" then
        return nil
    end

    local playerPed =
        PlayerPedId()
    local playerCoords =
        GetEntityCoords(playerPed)
    local vehicles =
        GetGamePool("CVehicle")
    local normalizedPlate =
        string.upper(target.plate)

    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local plate =
                GetVehiclePlate(vehicle)

            if plate
            and string.upper(plate) == normalizedPlate then
                local coords =
                    GetEntityCoords(vehicle)

                if #(playerCoords - coords) <= 800.0 then
                    return vehicle
                end
            end
        end
    end

    return nil
end

RegisterNetEvent("gs_police:client:trackVehicleTarget", function(target)
    if not Config
    or not Config.MovingTargets
    or Config.MovingTargets.enabled == false then
        return
    end

    if not target
    or not target.targetId then
        return
    end

    ActiveTrackedTargets[tonumber(target.targetId)] =
        target

    DebugPrint("tracking vehicle target", target.targetId, target.plate or "unknown")
end)

CreateThread(function()
    while true do
        local interval =
            (
                Config
                and Config.MovingTargets
                and Config.MovingTargets.updateIntervalMs
            )
            or 2000

        Wait(interval)

        if not Config
        or not Config.MovingTargets
        or Config.MovingTargets.enabled == false then
            goto continue
        end

        for targetId, target in pairs(ActiveTrackedTargets) do
            local vehicle =
                FindVehicleForTarget(target)

            if vehicle then
                local coords =
                    ToCoordsTable(GetEntityCoords(vehicle))
                local speed =
                    GetEntitySpeed(vehicle) * 2.236936
                local netId =
                    NetworkGetNetworkIdFromEntity(vehicle)

                target.netId =
                    netId
                target.plate =
                    GetVehiclePlate(vehicle) or target.plate
                target.lost =
                    false

                TriggerServerEvent("gs_police:server:updateMovingTarget", targetId, {
                    coords = coords,
                    heading = GetEntityHeading(vehicle),
                    speed = speed,
                    netId = netId,
                    plate = target.plate,
                    model = tostring(GetEntityModel(vehicle)),
                    vehicleClass = GetVehicleClass(vehicle)
                })
            elseif not target.lost then
                target.lost =
                    true

                TriggerServerEvent("gs_police:server:movingTargetLost", targetId)
            end
        end

        ::continue::
    end
end)

RegisterCommand("police_testmovingvehicle", function()
    print("[gs_police:moving_target] /police_testmovingvehicle ran")

    local ped =
        PlayerPedId()

    if not IsPedInAnyVehicle(ped, false) then
        Notify("Enter a vehicle first.", "error")
        return
    end

    local vehicle =
        GetVehiclePedIsIn(ped, false)

    print("[gs_police:moving_target] vehicle entity:", vehicle)

    if vehicle == 0
    or not DoesEntityExist(vehicle) then
        Notify("No vehicle found.", "error")
        return
    end

    local modelHash =
        GetEntityModel(vehicle)
    local netId =
        NetworkGetNetworkIdFromEntity(vehicle)
    local coords =
        ToCoordsTable(GetEntityCoords(vehicle))
    local plate =
        GetVehiclePlate(vehicle)

    print("[gs_police:moving_target] sending createMovingVehicleIncident", plate, netId)

    TriggerServerEvent("gs_police:server:createMovingVehicleIncident", {
        coords = coords,
        heading = GetEntityHeading(vehicle),
        speed = GetEntitySpeed(vehicle) * 2.236936,
        netId = netId,
        plate = plate,
        model = tostring(modelHash),
        vehicleClass = GetVehicleClass(vehicle),
        title = "Moving stolen vehicle",
        message = "Moving vehicle tracking test incident.",
        incidentType = "stolen_vehicle_delivery",
        signalType = "stolen_vehicle_activity",
        sourceResource = "test_command",
        metadata = {
            plate = plate,
            model = tostring(modelHash),
            vehicleClass = GetVehicleClass(vehicle),
            testCommand = true
        }
    })
end, false)
