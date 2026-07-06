local QBCore =
    exports['qb-core']:GetCoreObject()

print('[gs_chopshop] server/main.lua loaded')

local chopCooldowns = {}
local pendingChops = {}
local nextToken = 1
local VehicleClassNames = {
    [0] = 'Compact',
    [1] = 'Sedan',
    [2] = 'SUV',
    [3] = 'Coupe',
    [4] = 'Muscle',
    [5] = 'Sports Classic',
    [6] = 'Sports',
    [7] = 'Super',
    [8] = 'Motorcycle',
    [9] = 'Off-road',
    [10] = 'Industrial',
    [11] = 'Utility',
    [12] = 'Van',
    [13] = 'Cycle',
    [14] = 'Boat',
    [15] = 'Helicopter',
    [16] = 'Plane',
    [17] = 'Service',
    [18] = 'Emergency',
    [19] = 'Military',
    [20] = 'Commercial',
    [21] = 'Train',
}

local function DebugPrint(message)
    if Config.Debug then
        print('[gs_chopshop] ' .. message)
    end
end

local function NormalizePlate(plate)
    return tostring(plate or ''):upper():gsub('%s+', '')
end

local function Notify(source, message, notificationType)
    TriggerClientEvent('QBCore:Notify', source, message, notificationType or 'primary')
end

local function GetConditionPercent(bodyHealth, engineHealth)
    local body =
        math.max(0.0, math.min(1000.0, tonumber(bodyHealth) or 1000.0))
    local engine =
        math.max(0.0, math.min(1000.0, tonumber(engineHealth) or 1000.0))

    return math.floor((((body / 1000.0) + (engine / 1000.0)) / 2.0) * 100 + 0.5)
end

local function GetShop(shopId)
    if type(shopId) ~= 'string' then
        return nil
    end

    for _, shop in ipairs(Config.ChopShops or {}) do
        if shop.id == shopId then
            return shop
        end
    end

    return nil
end

local function GetCitizenId(Player, source)
    if Player
    and Player.PlayerData
    and Player.PlayerData.citizenid then
        return Player.PlayerData.citizenid
    end

    return tostring(source)
end

local function IsPlayerNearShop(source, shop)
    local ped =
        GetPlayerPed(source)

    if not ped
    or ped == 0 then
        return false
    end

    local playerCoords =
        GetEntityCoords(ped)
    local pedConfig =
        shop.ped or {}
    local zone =
        shop.vehicleZone or {}
    local allowedDistance =
        math.max((tonumber(zone.radius) or 4.0) + 8.0, 12.0)

    if pedConfig.coords then
        local pedCoords =
            vector3(pedConfig.coords.x, pedConfig.coords.y, pedConfig.coords.z)

        if #(playerCoords - pedCoords) <= allowedDistance then
            return true
        end
    end

    if zone.coords
    and #(playerCoords - zone.coords) <= allowedDistance then
        return true
    end

    return false
end

local function IsVehicleInShopBay(vehicle, shop)
    if not vehicle
    or vehicle == 0
    or not DoesEntityExist(vehicle)
    or not shop
    or not shop.vehicleZone
    or not shop.vehicleZone.coords then
        return false
    end

    local zone =
        shop.vehicleZone
    local radius =
        tonumber(zone.radius) or 4.0
    local coords =
        GetEntityCoords(vehicle)

    return #(coords - zone.coords) <= radius + 1.0
end

-- Occupancy is validated client-side because passenger-seat natives are not
-- available server-side in this runtime.

local function IsBlockedVehicle(payload)
    local rules =
        Config.VehicleRules or {}
    local vehicleClass =
        tonumber(payload.vehicleClass)
    local vehicleModel =
        tonumber(payload.vehicleModel)

    if rules.blockedClasses
    and vehicleClass
    and rules.blockedClasses[vehicleClass] then
        return true
    end

    if rules.blockEmergencyVehicles
    and vehicleClass == 18 then
        return true
    end

    if rules.blockedModels
    and vehicleModel
    and rules.blockedModels[vehicleModel] then
        return true
    end

    return false
end

local function IsOwnedVehicle(plate)
    local normalizedPlate =
        NormalizePlate(plate)

    if normalizedPlate == '' then
        return false
    end

    if not MySQL
    or not MySQL.scalar
    or not MySQL.scalar.await then
        if Config.Debug then
            print('[gs_chopshop] MySQL unavailable; skipping player_vehicles ownership check.')
        end

        return false
    end

    local success, owner =
        pcall(function()
            return MySQL.scalar.await(
                "SELECT citizenid FROM player_vehicles WHERE REPLACE(UPPER(plate), ' ', '') = ? LIMIT 1",
                { normalizedPlate }
            )
        end)

    if not success then
        if Config.Debug then
            print(('[gs_chopshop] player_vehicles lookup failed: %s'):format(owner))
        end

        return false
    end

    return owner ~= nil, owner
end

local function GetQBCoreVehicleByHash(modelHash)
    if not modelHash
    or not QBCore
    or not QBCore.Shared
    or not QBCore.Shared.VehicleHashes then
        return nil
    end

    local hashes =
        QBCore.Shared.VehicleHashes

    if hashes[modelHash] then
        return hashes[modelHash]
    end

    if modelHash < 0 then
        return hashes[modelHash + 4294967296]
    end

    if modelHash > 2147483647 then
        return hashes[modelHash - 4294967296]
    end

    return nil
end

local function GetConfiguredVehicleValue(modelHash)
    if not modelHash
    or not Config.VehicleValues then
        return nil
    end

    if Config.VehicleValues[modelHash] then
        return Config.VehicleValues[modelHash]
    end

    if modelHash < 0 then
        return Config.VehicleValues[modelHash + 4294967296]
    end

    if modelHash > 2147483647 then
        return Config.VehicleValues[modelHash - 4294967296]
    end

    return nil
end

local function GetVehicleBaseValue(model, modelName)
    local defaultValue =
        Config.Payment
        and Config.Payment.defaultVehicleValue
        or 25000
    local modelHash =
        tonumber(model)

    if Config.Payment
    and Config.Payment.useQBCoreVehiclePrices
    and QBCore
    and QBCore.Shared then
        local hashVehicleData =
            GetQBCoreVehicleByHash(modelHash)

        if hashVehicleData then
            local price =
                tonumber(hashVehicleData.price)

            if price
            and price > 0 then
                return price, 'qbcore_hash', hashVehicleData
            end
        end

        local normalizedModelName =
            type(modelName) == 'string'
            and modelName:lower()
            or nil

        if normalizedModelName
        and normalizedModelName ~= ''
        and QBCore.Shared.Vehicles
        and QBCore.Shared.Vehicles[normalizedModelName] then
            local modelVehicleData =
                QBCore.Shared.Vehicles[normalizedModelName]
            local price =
                tonumber(modelVehicleData.price)

            if price
            and price > 0 then
                return price, 'qbcore_model', modelVehicleData
            end
        end
    end

    local configuredValue =
        GetConfiguredVehicleValue(modelHash)

    if configuredValue then
        return configuredValue, 'config_hash', nil
    end

    return defaultValue, 'default', nil
end

local function GetConditionMultiplier(bodyHealth, engineHealth)
    if Config.Payment.conditionAffectsPrice == false then
        return 1.0
    end

    local body =
        tonumber(bodyHealth) or 1000.0
    local engine =
        tonumber(engineHealth) or 1000.0
    local bodyRatio =
        math.max(0.0, math.min(1.0, body / 1000.0))
    local engineRatio =
        math.max(0.0, math.min(1.0, engine / 1000.0))
    local average =
        (bodyRatio + engineRatio) / 2.0
    local minMultiplier =
        Config.Payment.minConditionMultiplier or 0.45

    return math.max(minMultiplier, average)
end

local function CalculateChopPayout(data)
    local model =
        data.vehicleModel or data.model
    local vehicleClass =
        tonumber(data.vehicleClass) or 0
    local bodyHealth =
        tonumber(data.bodyHealth) or 1000.0
    local engineHealth =
        tonumber(data.engineHealth) or 1000.0
    local baseValue, valueSource, vehicleData =
        GetVehicleBaseValue(model, data.modelName)
    local classMultiplier =
        1.0

    if Config.Payment.classMultipliers then
        classMultiplier =
            Config.Payment.classMultipliers[vehicleClass] or 1.0
    end

    local conditionMultiplier =
        GetConditionMultiplier(bodyHealth, engineHealth)
    local recoverablePercent =
        Config.Payment.recoverablePartsPercent or 0.35
    local thiefCut =
        Config.Payment.thiefCutPercent or 0.35
    local demandMultiplier =
        Config.Payment.demandMultiplier or 1.0
    local heatMultiplier =
        Config.Payment.policeHeatMultiplier or 1.0
    local adjustedVehicleValue =
        baseValue * classMultiplier * conditionMultiplier
    local recoveredPartsValue =
        adjustedVehicleValue * recoverablePercent
    local playerPayout =
        recoveredPartsValue * thiefCut

    playerPayout =
        playerPayout * demandMultiplier * heatMultiplier

    local randomBonus =
        math.random(
            Config.Payment.randomBonusMin or 0,
            Config.Payment.randomBonusMax or 0
        )

    playerPayout =
        playerPayout + randomBonus

    local minPayout =
        Config.Payment.minPayout or 500
    local maxPayout =
        Config.Payment.maxPayout or 25000

    playerPayout =
        math.floor(math.max(minPayout, math.min(maxPayout, playerPayout)))

    local shopCut =
        math.floor(recoveredPartsValue - playerPayout)

    return {
        payout = playerPayout,
        baseValue = math.floor(baseValue),
        adjustedVehicleValue = math.floor(adjustedVehicleValue),
        recoveredPartsValue = math.floor(recoveredPartsValue),
        shopCut = shopCut,
        classMultiplier = classMultiplier,
        conditionMultiplier = conditionMultiplier,
        recoverablePercent = recoverablePercent,
        thiefCut = thiefCut,
        valueSource = valueSource,
        vehicleName = vehicleData and vehicleData.name or nil,
        vehicleBrand = vehicleData and vehicleData.brand or nil,
        vehicleCategory = vehicleData and vehicleData.category or nil
    }
end

local function BuildEvidencePayload(source, shop, payload, payment)
    return {
        types = {
            'chopshop_vehicle_seen',
            'stolen_vehicle_trace',
            'plate_reader_hit',
            'door_surveillance',
            'informant_tip',
        },
        source = source,
        shopId = shop.id,
        plate = payload.vehiclePlate,
        vehicleModel = payload.vehicleModel,
        vehicleClass = payload.vehicleClass,
        payment = payment,
        createdAt = os.time(),
    }
end

local function RouteAlertToPolice(alertData)
    if not alertData then
        return false
    end

    alertData.sourceResource =
        alertData.sourceResource or 'gs_chopshop'

    if GetResourceState('gs_police') == 'started' then
        TriggerEvent('gs_police:server:assessIncident', alertData)

        if Config.Debug then
            print('[gs_chopshop] Routed alert to gs_police')
        end

        return true
    end

    if Config.Debug then
        print('[gs_chopshop] gs_police not started; alert not assessed')
    end

    return false
end

local function TryPoliceAlert(source, shop, payload, payout, shadowMarketOffer)
    local chance =
        tonumber(shop.policeAlertChance) or 0

    if chance <= 0
    or math.random(100) > chance then
        return
    end

    local payment =
        payout and payout.payout or 0
    local metadata = {
        shopId = shop.id,
        plate = payload.vehiclePlate,
        vehicleModel = payload.vehicleModel,
        vehicleClass = payload.vehicleClass,
        valueSource = payout and payout.valueSource or nil,
        baseValue = payout and payout.baseValue or nil,
        payout = payment,
    }

    if shadowMarketOffer then
        metadata.offerId =
            shadowMarketOffer.id or shadowMarketOffer.offerId
        metadata.templateId =
            shadowMarketOffer.templateId
        metadata.demandLevel =
            shadowMarketOffer.demandLevel
        metadata.heatLevel =
            shadowMarketOffer.heatLevel
        metadata.bonus =
            shadowMarketOffer.bonus
    end

    local incidentType =
        shadowMarketOffer and 'stolen_vehicle_delivery' or 'chopshop_activity'

    local alertData = {
        title = 'Suspicious Vehicle Activity',
        message = 'Possible stolen vehicle chop activity reported.',
        coords = shop.vehicleZone and shop.vehicleZone.coords or nil,
        incidentType = incidentType,
        threatLevel = 'low',
        preferredResponse = 'investigate',
        forcePolicy = 'less_lethal_preferred',
        source = source,
        sourceResource = 'gs_chopshop',
        plate = payload.vehiclePlate,
        vehicleModel = payload.vehicleModel,
        metadata = metadata,
        evidence = BuildEvidencePayload(source, shop, payload, payment),
    }

    RouteAlertToPolice(alertData)

    if GetResourceState('gs_dispatch') == 'started' then
        TriggerEvent('gs_dispatch:server:createAlert', alertData)
        return
    end

    if Config.Debug then
        print(('[gs_chopshop] Dispatch unavailable. Alert: %s plate=%s'):format(alertData.title, alertData.plate or 'unknown'))
    end
end

local function GetShadowMarketVehicleOffer(source, shop, payload)
    if GetResourceState('gs_blackmarket') ~= 'started' then
        return nil
    end

    local ok, result =
        pcall(function()
            return exports['gs_blackmarket']:GetActiveVehicleOffer(source, {
                shopId = shop and shop.id or nil,
                vehiclePlate = payload and payload.vehiclePlate or nil,
                vehicleModel = payload and payload.vehicleModel or nil,
                vehicleClass = payload and payload.vehicleClass or nil,
            })
        end)

    if not ok
    or type(result) ~= 'table'
    or result.ok ~= true then
        return nil
    end

    return result.offer
end

local function CompleteShadowMarketVehicleOffer(source, pending)
    if not pending
    or not pending.shadowMarketOffer
    or GetResourceState('gs_blackmarket') ~= 'started' then
        return
    end

    pcall(function()
        exports['gs_blackmarket']:CompleteVehicleOffer(source, pending.shadowMarketOffer.id, {
            shopId = pending.shopId,
            vehiclePlate = pending.plate,
            vehicleModel = pending.payload and pending.payload.vehicleModel or nil,
            vehicleClass = pending.payload and pending.payload.vehicleClass or nil,
            payout = pending.payment,
            bonus = pending.shadowMarketOffer.bonus,
        })
    end)
end

local function ValidateChopRequest(source, payload)
    if type(payload) ~= 'table' then
        return false, Config.Messages.failed
    end

    local Player =
        QBCore.Functions.GetPlayer(source)

    if not Player then
        return false, Config.Messages.failed
    end

    local shop =
        GetShop(payload.shopId)

    if not shop
    or shop.enabled == false then
        return false, Config.Messages.failed
    end

    if not IsPlayerNearShop(source, shop) then
        return false, Config.Messages.tooFar
    end

    local citizenId =
        GetCitizenId(Player, source)
    local cooldownUntil =
        chopCooldowns[citizenId] or 0
    local now =
        os.time()

    if cooldownUntil > now then
        return false, (Config.Messages.cooldown):format(cooldownUntil - now)
    end

    if IsBlockedVehicle(payload) then
        return false, Config.Messages.invalidVehicle
    end

    local plate =
        NormalizePlate(payload.vehiclePlate)

    if plate == '' then
        return false, Config.Messages.invalidVehicle
    end

    local rules =
        Config.VehicleRules or {}
    local owned, owner =
        IsOwnedVehicle(plate)

    if owned
    and (
        rules.allowPlayerOwnedVehicles == false
        or (
            rules.requireNotOwnedByPlayer
            and owner == citizenId
        )
    ) then
        return false, Config.Messages.registered
    end

    local vehicleNetId =
        tonumber(payload.vehicleNetId)

    if not vehicleNetId then
        return false, Config.Messages.invalidVehicle
    end

    local vehicle =
        NetworkGetEntityFromNetworkId(vehicleNetId)

    if not vehicle
    or vehicle == 0
    or not DoesEntityExist(vehicle) then
        return false, Config.Messages.invalidVehicle
    end

    if not IsVehicleInShopBay(vehicle, shop) then
        return false, Config.Messages.noVehicle
    end

    return true, nil, Player, shop, vehicle
end

QBCore.Functions.CreateCallback('gs_chopshop:server:getPayoutPreview', function(source, cb, payload)
    if type(payload) ~= 'table' then
        cb({
            ok = false,
        })
        return
    end

    -- Future hardening:
    -- Compare client-sent model/class against server entity state when possible.
    -- Add VIN/ownership metadata.
    -- Add stolen vehicle flag.
    -- Add police/insurance trace.
    local payout =
        CalculateChopPayout(payload)
    local vehicleClass =
        tonumber(payload.vehicleClass) or 0

    payout.ok =
        true
    payout.plate =
        payload.vehiclePlate
    payout.model =
        payload.vehicleModel or payload.model
    payout.modelName =
        payload.modelName or tostring(payload.vehicleModel or payload.model or 'unknown')
    payout.vehicleClass =
        vehicleClass
    payout.className =
        VehicleClassNames[vehicleClass] or 'Unknown'
    payout.bodyHealth =
        tonumber(payload.bodyHealth) or 1000.0
    payout.engineHealth =
        tonumber(payload.engineHealth) or 1000.0
    payout.conditionPercent =
        GetConditionPercent(payload.bodyHealth, payload.engineHealth)

    cb(payout)
end)

local function HandleChopRequest(source, payload)
    DebugPrint(('Chop request received from %s'):format(source))

    local valid, message, Player, shop, vehicle =
        ValidateChopRequest(source, payload)

    if not valid then
        TriggerClientEvent('gs_chopshop:client:chopRejected', source, message or Config.Messages.failed)
        return
    end

    DebugPrint(('Chop request validated for plate %s'):format(NormalizePlate(payload.vehiclePlate)))

    local token =
        ('%s:%s:%s'):format(source, os.time(), nextToken)
    nextToken =
        nextToken + 1

    local payout =
        CalculateChopPayout(payload)
    local shadowMarketOffer =
        GetShadowMarketVehicleOffer(source, shop, payload)
    local shadowMarketBonus =
        shadowMarketOffer
        and tonumber(shadowMarketOffer.bonus)
        or 0
    local finalPayment =
        payout.payout + shadowMarketBonus

    pendingChops[token] = {
        source = source,
        citizenId = GetCitizenId(Player, source),
        shopId = shop.id,
        vehicleNetId = tonumber(payload.vehicleNetId),
        plate = NormalizePlate(payload.vehiclePlate),
        payment = finalPayment,
        payout = payout,
        shadowMarketOffer = shadowMarketOffer,
        payload = payload,
        expiresAt = os.time() + 60,
        state = 'stripping',
    }

    DebugPrint(('Pending chop created chopId=%s plate=%s payout=%s'):format(
        token,
        pendingChops[token].plate,
        pendingChops[token].payment
    ))

    TryPoliceAlert(source, shop, payload, payout, shadowMarketOffer)

    TriggerClientEvent('gs_chopshop:client:startChop', source, {
        token = token,
        shopId = shop.id,
        vehicleNetId = tonumber(payload.vehicleNetId),
        plate = pendingChops[token].plate,
        duration = tonumber(Config.ChopDuration) or 8000,
        shadowMarketBonus = shadowMarketBonus,
        shadowMarketOffer = shadowMarketOffer
            and shadowMarketOffer.label
            or nil,
    })
end

RegisterNetEvent('gs_chopshop:server:requestChop', function(payload)
    local source =
        source
    local ok, err =
        pcall(function()
            HandleChopRequest(source, payload)
        end)

    if not ok then
        print(('[gs_chopshop] requestChop error: %s'):format(err))
        TriggerClientEvent(
            'gs_chopshop:client:chopRejected',
            source,
            Config.Messages.cannotProcess or Config.Messages.failed
        )
    end
end)

RegisterNetEvent('gs_chopshop:server:finishChop', function(token)
    local source =
        source

    if not token then
        TriggerClientEvent('gs_chopshop:client:chopRejected', source, Config.Messages.failed)
        return
    end

    local pending =
        pendingChops[token]

    if not pending
    or pending.source ~= source
    or pending.state ~= 'stripping'
    or pending.expiresAt < os.time() then
        TriggerClientEvent('gs_chopshop:client:chopRejected', source, Config.Messages.failed)
        pendingChops[token] =
            nil
        return
    end

    local shop =
        GetShop(pending.shopId)
    local vehicle =
        NetworkGetEntityFromNetworkId(pending.vehicleNetId)

    if not shop
    or not vehicle
    or vehicle == 0
    or not DoesEntityExist(vehicle)
    or not IsVehicleInShopBay(vehicle, shop)
    or not IsPlayerNearShop(source, shop) then
        TriggerClientEvent('gs_chopshop:client:chopRejected', source, Config.Messages.failed)
        pendingChops[token] =
            nil
        return
    end

    pending.state =
        'deleting'
    pending.expiresAt =
        os.time() + 20

    DebugPrint('Awaiting client vehicle deletion confirm')

    TriggerClientEvent('gs_chopshop:client:deleteVehicle', source, {
        token = token,
        vehicleNetId = pending.vehicleNetId,
        shopId = pending.shopId,
        plate = pending.plate,
    })
end)

RegisterNetEvent('gs_chopshop:server:confirmDeleted', function(token, deleted, reason)
    local source =
        source

    if not token then
        Notify(source, Config.Messages.failed, 'error')
        return
    end

    local pending =
        pendingChops[token]

    DebugPrint(('Delete confirmation chopId=%s success=%s reason=%s'):format(
        tostring(token),
        tostring(deleted),
        tostring(reason or 'none')
    ))

    if not pending
    or pending.source ~= source
    or pending.state ~= 'deleting'
    or pending.expiresAt < os.time() then
        pendingChops[token] =
            nil
        Notify(source, Config.Messages.failed, 'error')
        return
    end

    if not deleted then
        pendingChops[token] =
            nil
        Notify(source, Config.Messages.cannotProcess or Config.Messages.failed, 'error')
        return
    end

    local vehicle =
        NetworkGetEntityFromNetworkId(pending.vehicleNetId)

    if vehicle
    and vehicle ~= 0
    and DoesEntityExist(vehicle) then
        DebugPrint(('Client confirmed delete but server still sees entity netId=%s; paying on client confirmation.'):format(
            tostring(pending.vehicleNetId)
        ))
    end

    local Player =
        QBCore.Functions.GetPlayer(source)

    if not Player then
        pendingChops[token] =
            nil
        return
    end

    local account =
        Config.Payment
        and Config.Payment.account
        or 'cash'

    Player.Functions.AddMoney(account, pending.payment, 'chopshop-sell')
    chopCooldowns[pending.citizenId] =
        os.time() + (tonumber((GetShop(pending.shopId) or {}).cooldownSeconds) or 120)

    CompleteShadowMarketVehicleOffer(source, pending)

    if pending.shadowMarketOffer
    and tonumber(pending.shadowMarketOffer.bonus) then
        Notify(
            source,
            ('Vehicle stripped. You got $%s including a $%s ShadowMarket bonus.'):format(
                pending.payment,
                tonumber(pending.shadowMarketOffer.bonus) or 0
            ),
            'success'
        )
    else
        Notify(source, (Config.Messages.paid):format(pending.payment), 'success')
    end

    DebugPrint('Chop completion confirmed, paying player')

    if Config.Debug
    and pending.payout then
        DebugPrint(('Chop payout: base=%s recovered=%s payout=%s shopCut=%s condition=%.2f class=%.2f'):format(
            pending.payout.baseValue,
            pending.payout.recoveredPartsValue,
            pending.payout.payout,
            pending.payout.shopCut,
            pending.payout.conditionMultiplier,
            pending.payout.classMultiplier
        ))
    end

    pendingChops[token] =
        nil
end)

RegisterNetEvent('gs_chopshop:server:cancelChop', function(token, reason)
    local source =
        source
    local pending =
        pendingChops[token]

    if pending
    and pending.source == source then
        pendingChops[token] =
            nil

        if Config.Debug then
            print(('[gs_chopshop] Chop cancelled token=%s reason=%s'):format(token, reason or 'unknown'))
        end
    end
end)

RegisterNetEvent('gs_chopshop:server:debugPing', function()
    local source =
        source

    print(('[gs_chopshop] debugPing received from %s'):format(source))
    Notify(source, 'gs_chopshop server event received.', 'success')
end)

RegisterCommand('chop_reset', function(source)
    if source == 0 then
        chopCooldowns = {}
        print('[gs_chopshop] All chop cooldowns reset.')
        return
    end

    local Player =
        QBCore.Functions.GetPlayer(source)

    if not Player then
        return
    end

    chopCooldowns[GetCitizenId(Player, source)] =
        nil
    Notify(source, 'Chop shop cooldown reset.', 'success')
end, false)

RegisterCommand('chop_testpoliceroute', function(source)
    local src =
        source

    if src == 0 then
        print('[gs_chopshop] Run this in-game.')
        return
    end

    local ped =
        GetPlayerPed(src)
    local coords =
        GetEntityCoords(ped)

    local alertData = {
        title = 'Test Chop Shop Police Route',
        message = 'Testing chop shop alert routing.',
        coords = coords,
        incidentType = 'chopshop_activity',
        threatLevel = 'low',
        preferredResponse = 'investigate',
        forcePolicy = 'less_lethal_preferred',
        source = src,
        sourceResource = 'gs_chopshop',
        reason = 'manual_test',
        metadata = {
            shopId = nil,
            plate = nil,
            vehicleModel = nil,
            vehicleClass = nil,
        },
    }

    RouteAlertToPolice(alertData)

    TriggerClientEvent('QBCore:Notify', src, 'Chop shop alert routed to police.', 'success')
end, false)

CreateThread(function()
    while true do
        Wait(5000)

        local now =
            os.time()

        for token, pending in pairs(pendingChops) do
            if pending.expiresAt < now then
                if pending.source then
                    Notify(pending.source, Config.Messages.cannotProcess, 'error')
                    TriggerClientEvent('gs_chopshop:client:chopFailed', pending.source)
                end

                DebugPrint(('Pending chop timed out token=%s state=%s'):format(token, pending.state or 'unknown'))
                pendingChops[token] =
                    nil
            end
        end
    end
end)
