local QBCore =
    exports['qb-core']:GetCoreObject()

print('[gs_chopshop] client/main.lua loaded')

local spawnedPeds = {}
local isChopping = false
local isInteracting = false
local interactionAttempt = 0
local nearInteractionLogged = {}
local activeDebugVehicleInfo = nil
local VehicleClassNames = {
    [0] = "Compact",
    [1] = "Sedan",
    [2] = "SUV",
    [3] = "Coupe",
    [4] = "Muscle",
    [5] = "Sports Classic",
    [6] = "Sports",
    [7] = "Super",
    [8] = "Motorcycle",
    [9] = "Off-road",
    [10] = "Industrial",
    [11] = "Utility",
    [12] = "Van",
    [13] = "Cycle",
    [14] = "Boat",
    [15] = "Helicopter",
    [16] = "Plane",
    [17] = "Service",
    [18] = "Emergency",
    [19] = "Military",
    [20] = "Commercial",
    [21] = "Train",
}

local function DebugPrint(message)
    if Config.Debug then
        print('[gs_chopshop] ' .. message)
    end
end

local function ResetChopState(reason)
    interactionAttempt =
        interactionAttempt + 1
    isChopping =
        false
    isInteracting =
        false

    DebugPrint(('ResetChopState reason=%s'):format(reason or 'unknown'))
end

local function Notify(message, notificationType)
    if QBCore
    and QBCore.Functions
    and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, notificationType or 'primary')
        return
    end

    TriggerEvent('chat:addMessage', {
        args = {
            'Chop Shop',
            message,
        },
    })
end

local function FormatNumber(value)
    local formatted =
        tostring(math.floor(tonumber(value) or 0))

    while true do
        local nextValue, replacements =
            formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')

        formatted =
            nextValue

        if replacements == 0 then
            break
        end
    end

    return formatted
end

local function FormatMoney(value)
    return "$" .. FormatNumber(value)
end

CreateThread(function()
    Wait(3000)
    print('[gs_chopshop] client command registration check active')
end)

local function DrawText3D(coords, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

local function DrawDebugText3D(coords, lines)
    if type(lines) ~= 'table'
    or #lines < 1 then
        return
    end

    for index, line in ipairs(lines) do
        DrawText3D(coords + vector3(0.0, 0.0, (index - 1) * -0.18), line)
    end
end

local function GetShop(shopId)
    for _, shop in ipairs(Config.ChopShops or {}) do
        if shop.id == shopId then
            return shop
        end
    end

    return nil
end

local function LoadModel(model)
    local modelHash =
        type(model) == 'number' and model or joaat(model)

    if not IsModelInCdimage(modelHash)
    or not IsModelValid(modelHash) then
        return nil
    end

    RequestModel(modelHash)

    local timeout =
        GetGameTimer() + 5000

    while not HasModelLoaded(modelHash) do
        Wait(10)

        if GetGameTimer() > timeout then
            return nil
        end
    end

    return modelHash
end

local function SpawnShopPed(shop)
    if not shop
    or shop.enabled == false
    or spawnedPeds[shop.id] then
        return
    end

    local pedConfig =
        shop.ped or {}
    local coords =
        pedConfig.coords

    if not coords then
        return
    end

    local modelHash =
        LoadModel(pedConfig.model or 's_m_m_autoshop_01')

    if not modelHash then
        print(('[gs_chopshop] Failed to load ped model for %s.'):format(shop.id))
        return
    end

    local ped =
        CreatePed(0, modelHash, coords.x, coords.y, coords.z - 1.0, coords.w or 0.0, false, true)

    if not ped
    or ped == 0 then
        return
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)

    if pedConfig.scenario then
        TaskStartScenarioInPlace(ped, pedConfig.scenario, 0, true)
    end

    spawnedPeds[shop.id] =
        ped
    SetModelAsNoLongerNeeded(modelHash)
end

local function DeleteShopPeds()
    for shopId, ped in pairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end

        spawnedPeds[shopId] =
            nil
    end
end

local function IsVehicleOccupied(vehicle)
    if not vehicle
    or vehicle == 0
    or not DoesEntityExist(vehicle) then
        return false
    end

    if GetPedInVehicleSeat(vehicle, -1) ~= 0 then
        return true
    end

    local maxPassengers =
        GetVehicleMaxNumberOfPassengers(vehicle)

    for seat = 0, maxPassengers - 1 do
        if GetPedInVehicleSeat(vehicle, seat) ~= 0 then
            return true
        end
    end

    return false
end

local function GetVehicleInBay(shop)
    if not shop
    or not shop.vehicleZone
    or not shop.vehicleZone.coords then
        return nil
    end

    local zone =
        shop.vehicleZone
    local radius =
        tonumber(zone.radius) or 4.0
    local closestVehicle =
        nil
    local closestDistance =
        radius + 0.01

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local vehicleCoords =
                GetEntityCoords(vehicle)
            local distance =
                #(vehicleCoords - zone.coords)

            if distance <= radius
            and distance < closestDistance then
                closestVehicle =
                    vehicle
                closestDistance =
                    distance
            end
        end
    end

    return closestVehicle, closestDistance
end

local function GetNearbyVehicleForShop(shop)
    if not shop
    or not shop.vehicleZone
    or not shop.vehicleZone.coords then
        return nil
    end

    local zone =
        shop.vehicleZone
    local searchRadius =
        (tonumber(zone.radius) or 4.0) + 7.0
    local closestVehicle =
        nil
    local closestDistance =
        searchRadius + 0.01

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local distance =
                #(GetEntityCoords(vehicle) - zone.coords)

            if distance <= searchRadius
            and distance < closestDistance then
                closestVehicle =
                    vehicle
                closestDistance =
                    distance
            end
        end
    end

    return closestVehicle, closestDistance
end

local function BuildVehiclePayload(shop, vehicle)
    if not NetworkGetEntityIsNetworked(vehicle) then
        NetworkRegisterEntityAsNetworked(vehicle)
        Wait(50)
    end

    local model =
        GetEntityModel(vehicle)
    local displayName =
        GetDisplayNameFromVehicleModel(model)
    local plate =
        GetVehicleNumberPlateText(vehicle) or ''

    return {
        shopId = shop.id,
        vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle),
        vehicleModel = model,
        modelName = displayName and displayName:lower() or nil,
        vehicleClass = GetVehicleClass(vehicle),
        vehiclePlate = plate,
        bodyHealth = GetVehicleBodyHealth(vehicle),
        engineHealth = GetVehicleEngineHealth(vehicle),
    }
end

local function NormalizePlate(plate)
    return tostring(plate or ''):upper():gsub('%s+', '')
end

local function RequestControlOfEntity(entity, timeoutMs)
    if not entity
    or entity == 0
    or not DoesEntityExist(entity) then
        return false
    end

    local timeout =
        GetGameTimer() + (tonumber(timeoutMs) or 3000)
    local netId =
        NetworkGetNetworkIdFromEntity(entity)

    NetworkRequestControlOfEntity(entity)

    if netId
    and netId ~= 0 then
        NetworkRequestControlOfNetworkId(netId)
    end

    while DoesEntityExist(entity)
    and not NetworkHasControlOfEntity(entity)
    and GetGameTimer() <= timeout do
        Wait(25)
        NetworkRequestControlOfEntity(entity)

        if netId
        and netId ~= 0 then
            NetworkRequestControlOfNetworkId(netId)
        end
    end

    return DoesEntityExist(entity) and NetworkHasControlOfEntity(entity)
end

local function ForceDeleteVehicle(vehicle)
    if not vehicle
    or vehicle == 0
    or not DoesEntityExist(vehicle) then
        return true
    end

    local hasControl =
        RequestControlOfEntity(vehicle, 4000)

    DebugPrint(('Network control=%s'):format(tostring(hasControl)))
    SetEntityAsMissionEntity(vehicle, true, true)

    local attempts =
        0

    while DoesEntityExist(vehicle)
    and attempts < 10 do
        DeleteVehicle(vehicle)

        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end

        Wait(150)
        attempts =
            attempts + 1
    end

    local deleted =
        not DoesEntityExist(vehicle)

    DebugPrint(('Delete result=%s attempts=%s'):format(tostring(deleted), attempts))
    return deleted
end

local function GetVehicleByNetId(vehicleNetId)
    vehicleNetId =
        tonumber(vehicleNetId)

    if not vehicleNetId then
        return nil
    end

    local vehicle =
        NetworkGetEntityFromNetworkId(vehicleNetId)

    if vehicle
    and vehicle ~= 0
    and DoesEntityExist(vehicle) then
        return vehicle
    end

    local success, netVehicle =
        pcall(function()
            return NetToVeh(vehicleNetId)
        end)

    if success
    and netVehicle
    and netVehicle ~= 0
    and DoesEntityExist(netVehicle) then
        return netVehicle
    end

    return nil
end

local function FindDeleteTarget(data)
    local vehicle =
        GetVehicleByNetId(data.vehicleNetId)

    if vehicle
    and DoesEntityExist(vehicle) then
        return vehicle, 'net_id'
    end

    local shop =
        GetShop(data.shopId)

    if not shop then
        return nil, 'shop_not_found'
    end

    vehicle =
        GetVehicleInBay(shop)

    if vehicle
    and vehicle ~= 0
    and DoesEntityExist(vehicle) then
        return vehicle, 'bay_fallback'
    end

    return nil, 'vehicle_not_found'
end

local function CanAttemptChop(shop)
    local ped =
        PlayerPedId()

    if not ped
    or ped == 0 then
        return false
    end

    if IsPedInAnyVehicle(ped, false) then
        Notify(Config.Messages.getOut, 'error')
        return false
    end

    local vehicle =
        GetVehicleInBay(shop)

    if not vehicle
    or vehicle == 0
    or not DoesEntityExist(vehicle) then
        local nearbyVehicle =
            GetNearbyVehicleForShop(shop)

        if nearbyVehicle
        and DoesEntityExist(nearbyVehicle) then
            Notify(Config.Messages.pullIntoBay, 'error')
        else
            Notify(Config.Messages.noVehicle, 'error')
        end

        return false
    end

    if IsVehicleOccupied(vehicle) then
        Notify(Config.Messages.getOut, 'error')
        return false
    end

    return true, vehicle
end

local function StartChopProgress(token, shopId, vehicleNetId, duration, plate)
    if isChopping then
        DebugPrint('Chop approval ignored; already chopping')
        return
    end

    isChopping =
        true
    isInteracting =
        false
    DebugPrint(('Chop approved chopId=%s shopId=%s netId=%s plate=%s'):format(
        tostring(token),
        tostring(shopId),
        tostring(vehicleNetId),
        tostring(plate)
    ))
    DebugPrint('Starting chop progress')

    local function finish()
        DebugPrint('Chop progress complete, requesting vehicle delete')

        local shop =
            GetShop(shopId)
        local vehicle =
            NetworkGetEntityFromNetworkId(vehicleNetId)

        if not shop
        or not vehicle
        or vehicle == 0
        or not DoesEntityExist(vehicle) then
            TriggerServerEvent('gs_chopshop:server:cancelChop', token, 'vehicle_missing')
            Notify(Config.Messages.cannotProcess, 'error')
            ResetChopState('progress_vehicle_missing')
            return
        end

        local bayVehicle =
            GetVehicleInBay(shop)

        if bayVehicle ~= vehicle
        or IsVehicleOccupied(vehicle) then
            TriggerServerEvent('gs_chopshop:server:cancelChop', token, 'vehicle_moved')
            Notify(Config.Messages.cannotProcess, 'error')
            ResetChopState('progress_vehicle_moved')
            return
        end

        TriggerServerEvent('gs_chopshop:server:finishChop', token)
    end

    if QBCore
    and QBCore.Functions
    and QBCore.Functions.Progressbar then
        QBCore.Functions.Progressbar(
            'gs_chopshop_chop',
            'Stripping vehicle...',
            duration or Config.ChopDuration or 8000,
            false,
            true,
            {
                disableMovement = false,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            },
            {},
            {},
            {},
            finish,
            function()
                TriggerServerEvent('gs_chopshop:server:cancelChop', token, 'cancelled')
                ResetChopState('progress_cancelled')
            end
        )
        return
    end

    CreateThread(function()
        Wait(duration or Config.ChopDuration or 8000)
        finish()
    end)
end

local function StartChopInteraction(shop)
    if not shop
    or not shop.id then
        Notify('Shop error.', 'error')
        ResetChopState('invalid_shop')
        return
    end

    if isChopping
    or isInteracting then
        DebugPrint(('Interaction blocked. isChopping=%s isInteracting=%s'):format(
            tostring(isChopping),
            tostring(isInteracting)
        ))
        Notify(Config.Messages.busy, 'error')
        return
    end

    isInteracting =
        true
    interactionAttempt =
        interactionAttempt + 1
    local thisAttempt =
        interactionAttempt
    Notify(Config.Messages.greeting, 'primary')

    local canChop, vehicle =
        CanAttemptChop(shop)

    if not canChop then
        ResetChopState('validation_failed')
        return
    end

    local driver =
        GetPedInVehicleSeat(vehicle, -1)

    if driver
    and driver ~= 0 then
        Notify(Config.Messages.getOut, 'error')
        ResetChopState('vehicle_occupied_driver')
        return
    end

    Notify(Config.Messages.started, 'primary')
    DebugPrint(('Sending chop request shopId=%s'):format(shop.id))

    local payload =
        BuildVehiclePayload(shop, vehicle)

    DebugPrint(('Trigger server chop request shop=%s netId=%s plate=%s model=%s class=%s'):format(
        tostring(payload.shopId),
        tostring(payload.vehicleNetId),
        tostring(payload.vehiclePlate),
        tostring(payload.vehicleModel),
        tostring(payload.vehicleClass)
    ))

    TriggerServerEvent('gs_chopshop:server:requestChop', payload)

    CreateThread(function()
        Wait(10000)

        if interactionAttempt == thisAttempt
        and isInteracting
        and not isChopping then
            Notify('The mechanic ignores you.', 'error')
            ResetChopState('server_response_timeout')
        end
    end)
end

local function GetNearestShop()
    local playerPed =
        PlayerPedId()
    local playerCoords =
        playerPed and GetEntityCoords(playerPed) or nil

    if not playerCoords then
        return nil
    end

    local nearestShop =
        nil
    local nearestDistance =
        nil

    for _, shop in ipairs(Config.ChopShops or {}) do
        if shop.enabled ~= false
        and shop.ped
        and shop.ped.coords then
            local pedCoords =
                vector3(shop.ped.coords.x, shop.ped.coords.y, shop.ped.coords.z)
            local distance =
                #(playerCoords - pedCoords)

            if distance <= math.max((Config.InteractDistance or 2.0) + 4.0, 6.0)
            and (not nearestDistance or distance < nearestDistance) then
                nearestShop =
                    shop
                nearestDistance =
                    distance
            end
        end
    end

    return nearestShop, nearestDistance
end

RegisterNetEvent('gs_chopshop:client:startChop', function(data)
    if type(data) ~= 'table'
    or not data.token
    or not data.shopId
    or not data.vehicleNetId then
        ResetChopState('invalid_start_payload')
        return
    end

    StartChopProgress(data.token, data.shopId, data.vehicleNetId, data.duration, data.plate)
end)

RegisterNetEvent('gs_chopshop:client:chopRejected', function(message)
    if message then
        Notify(message, 'error')
    end

    ResetChopState('server_rejected')
end)

RegisterNetEvent('gs_chopshop:client:deleteVehicle', function(data)
    if type(data) ~= 'table'
    or not data.token
    or not data.vehicleNetId then
        ResetChopState('invalid_delete_payload')
        return
    end

    DebugPrint(('Delete event received chopId=%s netId=%s plate=%s'):format(
        data.token,
        tostring(data.vehicleNetId),
        tostring(data.plate)
    ))

    local vehicle, sourceType =
        FindDeleteTarget(data)

    DebugPrint(('Vehicle entity found=%s exists=%s source=%s'):format(
        tostring(vehicle),
        tostring(vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)),
        tostring(sourceType)
    ))

    if not vehicle
    or vehicle == 0
    or not DoesEntityExist(vehicle) then
        TriggerServerEvent('gs_chopshop:server:confirmDeleted', data.token, false, sourceType or 'vehicle_not_found')
        ResetChopState('delete_vehicle_not_found')
        return
    end

    local expectedPlate =
        NormalizePlate(data.plate)
    local actualPlate =
        NormalizePlate(GetVehicleNumberPlateText(vehicle))

    if expectedPlate ~= ''
    and actualPlate ~= ''
    and expectedPlate ~= actualPlate then
        DebugPrint(('Plate mismatch during delete. expected=%s actual=%s'):format(expectedPlate, actualPlate))
    end

    local deleted =
        ForceDeleteVehicle(vehicle)

    DebugPrint(('Vehicle delete confirmed to server success=%s reason=%s'):format(
        tostring(deleted),
        deleted and 'deleted' or 'delete_failed'
    ))

    TriggerServerEvent(
        'gs_chopshop:server:confirmDeleted',
        data.token,
        deleted,
        deleted and nil or 'delete_failed'
    )

    ResetChopState(deleted and 'delete_confirmation_sent' or 'delete_failed')
end)

RegisterNetEvent('gs_chopshop:client:chopFailed', function(message)
    ResetChopState('chop_failed')

    if message then
        Notify(message, 'error')
    end
end)

RegisterCommand('chop_ping', function()
    print('[gs_chopshop] /chop_ping executed')
    Notify('gs_chopshop client commands are working.', 'success')
end, false)

RegisterCommand('chop_serverping', function()
    print('[gs_chopshop] /chop_serverping executed')
    TriggerServerEvent('gs_chopshop:server:debugPing')
end, false)

RegisterCommand('chop_state', function()
    print(('[gs_chopshop] isChopping=%s isInteracting=%s'):format(
        tostring(isChopping),
        tostring(isInteracting)
    ))

    Notify(('Chop state | chopping: %s interacting: %s'):format(
        tostring(isChopping),
        tostring(isInteracting)
    ), 'primary')
end, false)

RegisterCommand('chop_state_reset', function()
    ResetChopState('manual_command')
    Notify('Chop shop state reset.', 'success')
end, false)

RegisterCommand('chop_start', function()
    print('[gs_chopshop] /chop_start command executed')
    Notify('/chop_start command received.', 'primary')

    local shop =
        GetNearestShop and GetNearestShop() or nil

    if not shop then
        print('[gs_chopshop] /chop_start failed: no nearest shop')
        Notify('No chop shop nearby.', 'error')
        ResetChopState('no_nearest_shop')
        return
    end

    print(('[gs_chopshop] /chop_start shop=%s'):format(shop.id or 'unknown'))

    if not StartChopInteraction then
        print('[gs_chopshop] /chop_start failed: StartChopInteraction is nil')
        Notify('Chop interaction function missing.', 'error')
        return
    end

    StartChopInteraction(shop)
end, false)

RegisterCommand('chop_debug', function()
    local ped =
        PlayerPedId()
    local playerCoords =
        GetEntityCoords(ped)

    for _, shop in ipairs(Config.ChopShops or {}) do
        local shopPed =
            spawnedPeds[shop.id]
        local pedCoords =
            shop.ped and shop.ped.coords
        local nearPed =
            false

        if pedCoords then
            nearPed =
                #(playerCoords - vector3(pedCoords.x, pedCoords.y, pedCoords.z)) <= (Config.InteractDistance or 2.0)
        end

        local vehicle, distance =
            GetVehicleInBay(shop)

        print(('[gs_chopshop] shop=%s enabled=%s pedSpawned=%s nearPed=%s'):format(
            shop.id,
            tostring(shop.enabled ~= false),
            tostring(shopPed and DoesEntityExist(shopPed)),
            tostring(nearPed)
        ))

        if vehicle
        and DoesEntityExist(vehicle) then
            local payload =
                BuildVehiclePayload(shop, vehicle)

            print(('[gs_chopshop] bayVehicle plate=%s model=%s class=%s distance=%.2f occupied=%s'):format(
                GetVehicleNumberPlateText(vehicle) or '',
                GetEntityModel(vehicle),
                GetVehicleClass(vehicle),
                distance or -1.0,
                tostring(IsVehicleOccupied(vehicle))
            ))
            QBCore.Functions.TriggerCallback('gs_chopshop:server:getPayoutPreview', function(result)
                if not result
                or not result.ok then
                    return
                end

                local vehicleLabel =
                    result.vehicleName
                    and (
                        result.vehicleBrand
                        and ('%s %s'):format(result.vehicleBrand, result.vehicleName)
                        or result.vehicleName
                    )
                    or result.modelName
                    or tostring(payload.vehicleModel)

                local classId =
                    tonumber(result.vehicleClass or payload.vehicleClass) or 0
                local className =
                    result.className
                    or VehicleClassNames[classId]
                    or 'Unknown'
                local plate =
                    result.plate
                    or payload.vehiclePlate
                    or GetVehicleNumberPlateText(vehicle)
                    or 'unknown'
                local conditionPercent =
                    tonumber(result.conditionPercent)
                    or math.floor(((tonumber(result.conditionMultiplier) or 1.0) * 100) + 0.5)

                print('[gs_chopshop] ===== Chop Bay Vehicle =====')
                print(('[gs_chopshop] Plate: %s'):format(plate))
                print(('[gs_chopshop] Vehicle: %s'):format(vehicleLabel))
                print(('[gs_chopshop] Model Hash: %s'):format(result.model or payload.vehicleModel))
                print(('[gs_chopshop] Class: %s (%s)'):format(className, classId))
                print(('[gs_chopshop] Condition: %s%%'):format(conditionPercent))
                print(('[gs_chopshop] Value Source: %s'):format(result.valueSource or 'unknown'))
                if result.vehicleCategory then
                    print(('[gs_chopshop] Category: %s'):format(result.vehicleCategory))
                end
                print(('[gs_chopshop] Base Value: %s'):format(FormatMoney(result.baseValue)))
                print(('[gs_chopshop] Recovered Parts: %s'):format(FormatMoney(result.recoveredPartsValue)))
                print(('[gs_chopshop] Est. Player Payout: %s'):format(FormatMoney(result.payout)))
                print(('[gs_chopshop] Shop Cut: %s'):format(FormatMoney(result.shopCut)))
                print('[gs_chopshop] ============================')

                Notify(('Vehicle detected: %s | %s'):format(className, plate), 'primary')

                local debugConfig =
                    Config.DebugVehicleInfo or {}

                if debugConfig.show3DText ~= false then
                    activeDebugVehicleInfo = {
                        expiresAt = GetGameTimer() + ((tonumber(debugConfig.displaySeconds) or 8) * 1000),
                        coords = shop.vehicleZone and shop.vehicleZone.coords or GetEntityCoords(vehicle),
                        lines = {
                            ('%s | %s'):format(className, plate),
                            ('Base: %s'):format(FormatMoney(result.baseValue)),
                            ('Payout: %s'):format(FormatMoney(result.payout)),
                        },
                    }
                end
            end, payload)
        else
            print('[gs_chopshop] bayVehicle=none')
            Notify('No bay vehicle detected.', 'primary')
        end
    end
end, false)

local function DrawBayMarkers(shop)
    local marker =
        Config.VehicleBayMarker or {}

    if marker.enabled == false
    or not shop
    or not shop.vehicleZone
    or not shop.vehicleZone.coords then
        return
    end

    local coords =
        shop.vehicleZone.coords
    local color =
        marker.color or {}
    local scale =
        marker.scale or vector3(3.0, 3.0, 1.0)

    DrawMarker(
        marker.type or 36,
        coords.x,
        coords.y,
        coords.z + 0.35,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        shop.vehicleZone.heading or 0.0,
        scale.x,
        scale.y,
        scale.z,
        color.r or 0,
        color.g or 255,
        color.b or 120,
        color.a or 120,
        marker.bobUpAndDown or false,
        true,
        2,
        marker.rotate or false,
        nil,
        nil,
        false
    )

    if marker.showArrow then
        DrawMarker(
            2,
            coords.x,
            coords.y,
            coords.z + 1.75,
            0.0,
            0.0,
            0.0,
            180.0,
            0.0,
            0.0,
            0.45,
            0.45,
            0.45,
            color.r or 0,
            color.g or 255,
            color.b or 120,
            190,
            true,
            true,
            2,
            true,
            nil,
            nil,
            false
        )
    end

    if marker.showGroundStrips then
        local stripCount =
            tonumber(marker.stripCount) or 3
        local spacing =
            tonumber(marker.stripSpacing) or 1.25
        local heading =
            math.rad(shop.vehicleZone.heading or 0.0)
        local right =
            vector3(math.cos(heading), math.sin(heading), 0.0)
        local startOffset =
            -((stripCount - 1) * spacing) / 2.0

        for index = 1, stripCount do
            local offset =
                startOffset + ((index - 1) * spacing)
            local stripCoords =
                coords + vector3(right.x * offset, right.y * offset, 0.0)

            DrawMarker(
                1,
                stripCoords.x,
                stripCoords.y,
                stripCoords.z - 0.92,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                shop.vehicleZone.heading or 0.0,
                0.18,
                3.0,
                0.04,
                color.r or 0,
                color.g or 255,
                color.b or 120,
                95,
                false,
                false,
                2,
                false,
                nil,
                nil,
                false
            )
        end
    end

    if marker.showText then
        DrawText3D(coords + vector3(0.0, 0.0, 1.25), marker.text or 'Park Here')
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    ResetChopState('resource_stop')
    DeleteShopPeds()
end)

CreateThread(function()
    while true do
        local sleep =
            1000
        local playerPed =
            PlayerPedId()
        local playerCoords =
            playerPed and GetEntityCoords(playerPed) or nil
        local marker =
            Config.VehicleBayMarker or {}
        local drawDistance =
            tonumber(marker.drawDistance) or 35.0

        if playerCoords
        and marker.enabled ~= false then
            for _, shop in ipairs(Config.ChopShops or {}) do
                if shop.enabled ~= false
                and shop.vehicleZone
                and shop.vehicleZone.coords
                and #(playerCoords - shop.vehicleZone.coords) <= drawDistance then
                    sleep =
                        0
                    DrawBayMarkers(shop)

                    if activeDebugVehicleInfo then
                        if GetGameTimer() >= activeDebugVehicleInfo.expiresAt then
                            activeDebugVehicleInfo =
                                nil
                        elseif activeDebugVehicleInfo.coords then
                            DrawDebugText3D(
                                activeDebugVehicleInfo.coords + vector3(0.0, 0.0, 2.25),
                                activeDebugVehicleInfo.lines
                            )
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    Wait(1000)

    for _, shop in ipairs(Config.ChopShops or {}) do
        SpawnShopPed(shop)
    end
end)

CreateThread(function()
    while true do
        local sleep =
            1000
        local playerPed =
            PlayerPedId()
        local playerCoords =
            playerPed and GetEntityCoords(playerPed) or nil

        if playerCoords then
            for _, shop in ipairs(Config.ChopShops or {}) do
                if shop.enabled ~= false
                and shop.ped
                and shop.ped.coords then
                    local pedCoords =
                        vector3(shop.ped.coords.x, shop.ped.coords.y, shop.ped.coords.z)
                    local distance =
                        #(playerCoords - pedCoords)

                    if distance <= 12.0 then
                        sleep =
                            0

                        if distance <= (Config.InteractDistance or 2.0) then
                            DrawText3D(pedCoords + vector3(0.0, 0.0, 1.0), Config.Messages.prompt)

                            if not nearInteractionLogged[shop.id] then
                                nearInteractionLogged[shop.id] =
                                    true
                                DebugPrint('Player near chop ped interaction range')
                            end

                            if IsControlJustPressed(0, Config.InteractKey or 38) then
                                DebugPrint('E pressed near chop ped')
                                StartChopInteraction(shop)
                            end
                        else
                            nearInteractionLogged[shop.id] =
                                nil
                        end
                    else
                        nearInteractionLogged[shop.id] =
                            nil
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
