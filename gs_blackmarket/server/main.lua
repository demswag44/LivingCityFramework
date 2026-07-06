GSBlackMarket = GSBlackMarket or {}
GSBlackMarket.Server = GSBlackMarket.Server or {}

local QBCore =
    exports['qb-core']:GetCoreObject()

local purchaseCooldowns = {}
local knockCooldowns = {}
local alertCooldowns = {}
local dealerStock = {}
local nextRestockAt = {}
local dealerReputation = {}
local activeRotation = {}
local nextRotationAt = {}
local activeDealerLocations = {}
local nextRelocationAt = 0
local shadowMarketEvidence = {}
local shadowMarketFailedAttempts = {}
local phoneOrders = {}
local nextOrderId = 1
local activeVehicleOffers = {}
local dynamicVehicleOffers = {}
local nextVehicleOfferRotationAt = 0
local vehicleOfferHeat = {}
local recentVehicleDeliveries = {}
local nextVehicleOfferId = 1
local AllowedEvidenceTypes = {
    phone_seized = true,
    near_pickup = true,
    informant_tip = true,
    door_surveillance = true,
    undercover_buy = true,
    metadata_recovered = true,
    failed_wipe = true,
    stolen_goods_trace = true,
}
local GetLocation

local function Log(message)
    local prefix =
        Config
        and Config.LogPrefix
        or 'GS BLACKMARKET'

    print(('[%s] %s'):format(prefix, message))
end

local function GetPlayerKey(Player, src, locationId)
    local citizenid =
        Player
        and Player.PlayerData
        and Player.PlayerData.citizenid
        or tostring(src)

    return ('%s:%s'):format(citizenid, locationId)
end

local function GetPlayerIdentifier(src)
    local Player =
        QBCore.Functions.GetPlayer(src)

    if Player
    and Player.PlayerData
    and Player.PlayerData.citizenid then
        return Player.PlayerData.citizenid
    end

    return tostring(src)
end

local function GetRepKey(src, locationId)
    local identifier =
        GetPlayerIdentifier(src)

    if Config.Reputation
    and Config.Reputation.perDealer then
        return ('%s:%s'):format(identifier, locationId)
    end

    return identifier
end

local function GetDealerRep(src, locationId)
    local key =
        GetRepKey(src, locationId)

    if dealerReputation[key] == nil then
        dealerReputation[key] =
            Config.Reputation
            and tonumber(Config.Reputation.defaultRep)
            or 0
    end

    return dealerReputation[key]
end

local function GetCurrentActiveDealerLocation()
    for locationId, active in pairs(activeDealerLocations or {}) do
        if active then
            return GetLocation(locationId)
        end
    end

    return Config.BlackMarketLocations
        and Config.BlackMarketLocations[1]
        or nil
end

local function AddShadowMarketEvidence(src, evidenceType, details)
    if not AllowedEvidenceTypes[evidenceType] then
        return false
    end

    local identifier =
        GetPlayerIdentifier(src)

    shadowMarketEvidence[identifier] =
        shadowMarketEvidence[identifier] or {}

    shadowMarketEvidence[identifier][#shadowMarketEvidence[identifier] + 1] = {
        type = evidenceType,
        details = details or {},
        time = os.time(),
    }

    return true
end

local function HasShadowMarketEvidence(src)
    local identifier =
        GetPlayerIdentifier(src)
    local evidence =
        shadowMarketEvidence[identifier]

    return evidence ~= nil
        and #evidence > 0
end

local function GetShadowMarketEvidence(src)
    local identifier =
        GetPlayerIdentifier(src)

    return shadowMarketEvidence[identifier] or {}
end

local function ClearShadowMarketEvidence(src)
    local identifier =
        GetPlayerIdentifier(src)

    shadowMarketEvidence[identifier] =
        nil
end

local function CanAccessShadowMarket(src)
    if not Config.PhoneApp
    or Config.PhoneApp.enabled == false then
        return false, 'disabled'
    end

    local location =
        GetCurrentActiveDealerLocation()
    local locationId =
        location
        and location.id
        or 'global'
    local rep =
        GetDealerRep(src, locationId)

    if Config.PhoneApp.requireDealerRep then
        local required =
            tonumber(Config.PhoneApp.requiredRep) or 10

        if rep < required then
            return false, 'low_rep', {
                reputation = rep,
                requiredRep = required,
                activeDealer = locationId,
            }
        end
    end

    if Config.PhoneApp.requireEncryptedSim then
        local Player =
            QBCore.Functions.GetPlayer(src)

        if not Player then
            return false, 'no_player'
        end

        local item =
            Player.Functions.GetItemByName
            and Player.Functions.GetItemByName(Config.PhoneApp.encryptedSimItem)
            or nil

        if not item then
            return false, 'missing_sim', {
                reputation = rep,
                activeDealer = locationId,
            }
        end
    end

    return true, 'ok', {
        reputation = rep,
        activeDealer = locationId,
    }
end

local function AddDealerRep(src, locationId, amountSpent)
    if not Config.Reputation
    or Config.Reputation.enabled == false then
        return
    end

    local key =
        GetRepKey(src, locationId)
    local current =
        GetDealerRep(src, locationId)
    local gain =
        tonumber(Config.Reputation.gainPerPurchase) or 0
    local perDollar =
        tonumber(Config.Reputation.gainPerDollarSpent) or 0

    gain =
        gain + math.floor((tonumber(amountSpent) or 0) * perDollar)

    if gain <= 0 then
        return
    end

    local maxRep =
        tonumber(Config.Reputation.maxRep) or 100

    dealerReputation[key] =
        math.min(maxRep, current + gain)

    TriggerClientEvent(
        'QBCore:Notify',
        src,
        (
            Config.Reputation.messages
            and Config.Reputation.messages.gained
        )
        or 'Dealer trust increased.',
        'success'
    )
end

local function IsCooldownActive(cooldowns, key)
    local expiresAt =
        cooldowns[key]

    if not expiresAt then
        return false
    end

    if os.time() >= expiresAt then
        cooldowns[key] =
            nil
        return false
    end

    return true, expiresAt - os.time()
end

local function SetCooldown(cooldowns, key, seconds)
    seconds =
        tonumber(seconds) or 0

    if seconds <= 0 then
        return
    end

    cooldowns[key] =
        os.time() + seconds
end

local function EncodeForDebug(data)
    local ok, encoded =
        pcall(json.encode, data)

    if ok then
        return encoded
    end

    return '<alert payload could not be json encoded>'
end

local function Notify(source, message, notificationType)
    TriggerClientEvent(
        'QBCore:Notify',
        source,
        message,
        notificationType or 'primary'
    )
end

function GetLocation(locationId)
    if type(locationId) ~= 'string' then
        return nil
    end

    for _, location in ipairs(Config.BlackMarketLocations or {}) do
        if location.id == locationId then
            return location
        end
    end

    return nil
end

local function IsLocationUsable(location)
    if not location then
        return false
    end

    if location.enabled == false then
        return false
    end

    if Config.Relocation
    and Config.Relocation.enabled
    and Config.Relocation.singleActiveLocation then
        return activeDealerLocations[location.id] == true
    end

    if location.active == false then
        return false
    end

    return true
end

local function InitializeActiveLocations()
    activeDealerLocations = {}

    if not Config.Relocation
    or not Config.Relocation.enabled then
        for _, location in ipairs(Config.BlackMarketLocations or {}) do
            if location.enabled ~= false
            and location.active ~= false then
                activeDealerLocations[location.id] =
                    true
            end
        end

        return
    end

    if Config.Relocation.singleActiveLocation then
        local candidates = {}

        for _, location in ipairs(Config.BlackMarketLocations or {}) do
            local enabledOk =
                location.enabled ~= false
            local eligibleOk =
                location.relocationEligible ~= false

            if enabledOk
            and eligibleOk then
                candidates[#candidates + 1] =
                    location
            end
        end

        if #candidates == 0 then
            print('[gs_blackmarket] No eligible dealer locations found for relocation.')
            return
        end

        local selected =
            nil

        for _, location in ipairs(candidates) do
            if location.active == true then
                selected =
                    location
                break
            end
        end

        if not selected then
            selected =
                candidates[math.random(#candidates)]
        end

        activeDealerLocations[selected.id] =
            true

        print(('[gs_blackmarket] Active dealer location: %s'):format(selected.id))
        return
    end

    for _, location in ipairs(Config.BlackMarketLocations or {}) do
        if location.enabled ~= false
        and location.active ~= false then
            activeDealerLocations[location.id] =
                true
        end
    end
end

local function GetRelocationRemaining()
    if not nextRelocationAt
    or nextRelocationAt <= 0 then
        return 0
    end

    return math.max(0, nextRelocationAt - os.time())
end

local function RelocateDealer()
    if not Config.Relocation
    or not Config.Relocation.enabled then
        return
    end

    local candidates = {}

    for _, location in ipairs(Config.BlackMarketLocations or {}) do
        local enabledOk =
            location.enabled ~= false
        local eligibleOk =
            location.relocationEligible ~= false

        if enabledOk
        and eligibleOk then
            candidates[#candidates + 1] =
                location
        end
    end

    if #candidates == 0 then
        print('[gs_blackmarket] No relocation candidates available.')
        return
    end

    local currentId =
        nil

    for locationId, active in pairs(activeDealerLocations) do
        if active then
            currentId =
                locationId
            break
        end
    end

    local selected =
        nil

    if #candidates == 1 then
        selected =
            candidates[1]
    else
        local attempts =
            0

        while attempts < 10 do
            local candidate =
                candidates[math.random(#candidates)]

            if candidate.id ~= currentId then
                selected =
                    candidate
                break
            end

            attempts =
                attempts + 1
        end

        selected =
            selected or candidates[math.random(#candidates)]
    end

    activeDealerLocations = {}
    activeDealerLocations[selected.id] =
        true
    TriggerClientEvent('gs_blackmarket:client:refreshActiveLocations', -1)

    nextRelocationAt =
        os.time() + (
            Config.Relocation
            and tonumber(Config.Relocation.relocateSeconds)
            or 7200
        )

    if Config.Relocation.debugRelocation
    or Config.Debug then
        print(('[gs_blackmarket] Dealer relocated to %s'):format(selected.id))
    end
end

local function GetItem(itemIndex)
    itemIndex =
        tonumber(itemIndex)

    if not itemIndex then
        return nil
    end

    return Config.Items and Config.Items[itemIndex] or nil
end

local GetMaxQuantity

local function IsStockEnabled()
    return Config.Stock
        and Config.Stock.enabled ~= false
end

local function GetStockKey(locationId, itemIndex)
    if Config.Stock
    and Config.Stock.perLocationStock then
        return ('%s:%s'):format(locationId, itemIndex)
    end

    return ('global:%s'):format(itemIndex)
end

local function GetRestockSeconds()
    return Config.Stock
        and tonumber(Config.Stock.restockSeconds)
        or 1800
end

local function GetItemMaxQuantity(item)
    local itemMax =
        item
        and tonumber(item.maxQuantity)

    if itemMax
    and itemMax > 0 then
        return itemMax
    end

    return GetMaxQuantity()
end

local function GetStock(locationId, itemIndex)
    if not IsStockEnabled() then
        return nil
    end

    local key =
        GetStockKey(locationId, itemIndex)

    if dealerStock[key] == nil then
        local item =
            GetItem(itemIndex)

        dealerStock[key] =
            item
            and tonumber(item.stock)
            or 0
    end

    return tonumber(dealerStock[key]) or 0
end

local function GetRestockRemaining(locationId)
    if not IsStockEnabled() then
        return 0
    end

    local nextAt =
        nextRestockAt[locationId]

    if not nextAt then
        return 0
    end

    return math.max(0, nextAt - os.time())
end

local function RestockLocation(locationId)
    for itemIndex, item in ipairs(Config.Items or {}) do
        local key =
            GetStockKey(locationId, itemIndex)

        dealerStock[key] =
            tonumber(item.restockAmount) or tonumber(item.stock) or 0
    end

    if Config.Debug then
        print(('[gs_blackmarket] Restocked dealer location %s'):format(locationId))
    end
end

local function InitializeStock()
    dealerStock = {}
    nextRestockAt = {}

    if not IsStockEnabled() then
        return
    end

    local restockSeconds =
        GetRestockSeconds()

    for _, location in ipairs(Config.BlackMarketLocations or {}) do
        for itemIndex, item in ipairs(Config.Items or {}) do
            local key =
                GetStockKey(location.id, itemIndex)

            dealerStock[key] =
                tonumber(item.stock) or 0
        end

        nextRestockAt[location.id] =
            os.time() + restockSeconds
    end

    print('[gs_blackmarket] Dealer stock initialized.')
end

local function ShouldFailOpenAccess()
    return not Config.Access
        or Config.Access.failOpenForMissingSystems ~= false
end

local function PlayerHasGangAccess(src, locationId, item)
    if not item.requiresGang then
        return true
    end

    if not Config.Access
    or Config.Access.enabled == false
    or not Config.Access.useOrganizations then
        return ShouldFailOpenAccess()
    end

    if GetResourceState('gs_organizations') ~= 'started' then
        return ShouldFailOpenAccess()
    end

    -- Future gs_organizations integration:
    -- Replace this placeholder with an export once available.
    -- Example future:
    -- return exports.gs_organizations:HasBlackMarketAccess(src, locationId, item.item)
    return ShouldFailOpenAccess()
end

local function PlayerHasTerritoryAccess(src, locationId, item)
    if not item.requiresTerritoryControl then
        return true
    end

    if not Config.Access
    or Config.Access.enabled == false
    or not Config.Access.useTerritories then
        return ShouldFailOpenAccess()
    end

    if GetResourceState('gs_organizations') ~= 'started' then
        return ShouldFailOpenAccess()
    end

    -- Future gs_organizations/territory integration:
    -- Check whether the player's organization controls the dealer territory.
    -- Example future:
    -- return exports.gs_organizations:ControlsBlackMarketTerritory(src, locationId)
    return ShouldFailOpenAccess()
end

local function BuildRotationForLocation(locationId)
    activeRotation[locationId] = {}

    local rotatingIndexes = {}

    for index, item in ipairs(Config.Items or {}) do
        if not item.alwaysAvailable then
            rotatingIndexes[#rotatingIndexes + 1] =
                index
        end
    end

    for i = #rotatingIndexes, 2, -1 do
        local j =
            math.random(i)

        rotatingIndexes[i], rotatingIndexes[j] =
            rotatingIndexes[j], rotatingIndexes[i]
    end

    local maxItems =
        Config.RotatingInventory
        and tonumber(Config.RotatingInventory.maxRotatingItems)
        or 4

    for i = 1, math.min(maxItems, #rotatingIndexes) do
        activeRotation[locationId][rotatingIndexes[i]] =
            true
    end

    if Config.Debug then
        print(('[gs_blackmarket] Rotation built for %s'):format(locationId))
    end
end

local function InitializeRotation()
    activeRotation = {}
    nextRotationAt = {}

    if not Config.RotatingInventory
    or Config.RotatingInventory.enabled == false then
        return
    end

    local now =
        os.time()
    local rotateSeconds =
        Config.RotatingInventory
        and tonumber(Config.RotatingInventory.rotateSeconds)
        or 3600

    for _, location in ipairs(Config.BlackMarketLocations or {}) do
        BuildRotationForLocation(location.id)
        nextRotationAt[location.id] =
            now + rotateSeconds
    end
end

local function IsItemInRotation(locationId, itemIndex, item)
    if not Config.RotatingInventory
    or Config.RotatingInventory.enabled == false then
        return true
    end

    if item.alwaysAvailable then
        return true
    end

    return activeRotation[locationId]
        and activeRotation[locationId][itemIndex] == true
end

local function GetRotationRemaining(locationId)
    if not Config.RotatingInventory
    or Config.RotatingInventory.enabled == false then
        return 0
    end

    local nextAt =
        nextRotationAt[locationId]

    if not nextAt then
        return 0
    end

    return math.max(0, nextAt - os.time())
end

local function GetCash(Player)
    if not Player
    or not Player.PlayerData
    or not Player.PlayerData.money then
        return 0
    end

    return tonumber(Player.PlayerData.money.cash) or 0
end

function GetMaxQuantity()
    return Config.UI
        and tonumber(Config.UI.maxQuantity)
        or 10
end

local function IsPlayerNearLocation(source, location)
    local ped =
        GetPlayerPed(source)

    if not ped
    or ped == 0 then
        return false
    end

    local playerCoords =
        GetEntityCoords(ped)
    local distance =
        #(playerCoords - location.coords)

    return distance <= (Config.MaxPurchaseDistance or 5.0)
end

local function ValidatePurchaseContext(src, locationId)
    local location =
        GetLocation(locationId)

    if not IsLocationUsable(location) then
        Notify(src, 'This dealer is unavailable.', 'error')
        return nil
    end

    if not IsPlayerNearLocation(src, location) then
        Notify(src, 'You are too far from the dealer.', 'error')
        return nil
    end

    return location
end

local function GetCooldownMessage(remaining)
    remaining =
        tonumber(remaining) or 0

    if remaining > 0 then
        return ('The door goes quiet. Come back in %ss.'):format(remaining)
    end

    return Config.DealerCooldown
        and Config.DealerCooldown.message
        or 'The door goes quiet. Come back later.'
end

local function RouteAlertToPolice(alertData)
    if not alertData then
        return false
    end

    alertData.sourceResource =
        alertData.sourceResource or 'gs_blackmarket'

    if GetResourceState('gs_police') == 'started' then
        TriggerEvent('gs_police:server:assessIncident', alertData)

        if Config.Debug then
            print('[gs_blackmarket] Routed alert to gs_police')
        end

        return true
    end

    if Config.Debug then
        print('[gs_blackmarket] gs_police not started; alert not assessed')
    end

    return false
end

local function TryPoliceAlert(src, location, reason, forceAlert, metadata)
    local policeAlert =
        Config.PoliceAlert or {}

    if policeAlert.enabled == false
    or not location then
        return
    end

    local cooldownKey =
        location.id or 'unknown'

    if not forceAlert
    and IsCooldownActive(alertCooldowns, cooldownKey) then
        return
    end

    local chance =
        tonumber(policeAlert.chance) or 0

    if forceAlert and Config.Debug then
        print('[gs_blackmarket] Police alert forced by test command.')
    end

    if not forceAlert then
        local roll =
            math.random(1, 100)

        if chance <= 0
        or roll > chance then
            if Config.Debug then
                print(('[gs_blackmarket] Police alert not triggered. Roll=%s Chance=%s'):format(roll, chance))
            end

            return
        end
    end

    if not forceAlert then
        SetCooldown(
            alertCooldowns,
            cooldownKey,
            policeAlert.alertCooldownSeconds or 180
        )
    end

    local incidentTypes = {
        shadowmarket_order = 'shadowmarket_order',
        shadowmarket_pickup = 'shadowmarket_pickup',
    }
    local incidentType =
        incidentTypes[reason]
        or policeAlert.incidentType
        or 'blackmarket_activity'

    local alertData = {
        title = policeAlert.title or 'Suspicious Activity',
        message = policeAlert.message or 'Suspicious activity reported near a residence.',
        coords = location.coords,
        locationId = location.id,
        reason = reason,
        incidentType = incidentType,
        threatLevel = policeAlert.threatLevel or 'low',
        preferredResponse = policeAlert.preferredResponse or 'investigate',
        forcePolicy = policeAlert.forcePolicy or 'less_lethal_preferred',
        source = src,
        sourceResource = 'gs_blackmarket',
        metadata = {
            locationId = location.id,
            heatLevel = metadata and metadata.heatLevel or nil,
            demandLevel = metadata and metadata.demandLevel or nil,
            offerId = metadata and metadata.offerId or nil,
            orderId = metadata and metadata.orderId or nil,
        },
    }

    local dispatchEvent =
        policeAlert.dispatchEvent or 'gs_dispatch:server:createAlert'

    RouteAlertToPolice(alertData)

    if GetResourceState('gs_dispatch') == 'started' then
        TriggerEvent(dispatchEvent, alertData)
        return
    end

    -- Dispatch integration placeholders:
    -- qb-policejob, qb-dispatch, ps-dispatch, cd_dispatch, gs_dispatch.
    if Config.Debug
    or forceAlert then
        print('[gs_blackmarket] Police alert placeholder:')
        print(EncodeForDebug(alertData))
    end
end

local function IsDealerCooldownActive(src, Player, locationId, cooldowns)
    local key =
        GetPlayerKey(Player, src, locationId)

    if not Config.DealerCooldown
    or Config.DealerCooldown.enabled == false then
        return false, key
    end

    local active, remaining =
        IsCooldownActive(cooldowns, key)

    return active, key, remaining
end

local function GetItemAccessState(src, locationId, itemIndex, item)
    local rep =
        GetDealerRep(src, locationId)
    local unlocked =
        true
    local lockReason =
        nil
    local requiredRep =
        tonumber(item.requiredRep) or 0

    if Config.Reputation
    and Config.Reputation.enabled ~= false
    and requiredRep > 0
    and rep < requiredRep then
        unlocked =
            false
        lockReason =
            ('Requires dealer reputation %s.'):format(requiredRep)
    end

    if unlocked
    and not PlayerHasGangAccess(src, locationId, item) then
        unlocked =
            false
        lockReason =
            Config.Access
            and Config.Access.messages
            and Config.Access.messages.gangRequired
            or 'You need the right connections for that.'
    end

    if unlocked
    and not PlayerHasTerritoryAccess(src, locationId, item) then
        unlocked =
            false
        lockReason =
            Config.Access
            and Config.Access.messages
            and Config.Access.messages.territoryLocked
            or 'This dealer is controlled by someone else.'
    end

    if unlocked
    and not IsItemInRotation(locationId, itemIndex, item) then
        unlocked =
            false
        lockReason =
            'This item is not available right now.'
    end

    return unlocked, lockReason
end

local function ValidateAccessForOrder(src, locationId, order)
    for _, line in ipairs(order or {}) do
        local unlocked, lockReason =
            GetItemAccessState(src, locationId, line.itemIndex, line.item)

        if not unlocked then
            Notify(
                src,
                lockReason
                or (
                    Config.Access
                    and Config.Access.messages
                    and Config.Access.messages.locked
                )
                or 'The dealer will not sell you that.',
                'error'
            )
            return false
        end
    end

    return true
end

local function BuildCartOrder(src, cart)
    if type(cart) ~= 'table'
    or #cart < 1 then
        Notify(src, 'The dealer ignores you.', 'error')
        return nil
    end

    local order = {}
    local total = 0
    local mergedCart = {}
    local mergedOrder = {}

    for _, line in ipairs(cart) do
        if type(line) ~= 'table' then
            Notify(src, 'The dealer ignores you.', 'error')
            return nil
        end

        local itemIndex =
            tonumber(line.itemIndex)
        local quantity =
            tonumber(line.quantity)

        if not itemIndex
        or not quantity
        or quantity < 1 then
            Notify(src, 'The dealer ignores you.', 'error')
            return nil
        end

        itemIndex =
            math.floor(itemIndex)
        quantity =
            math.floor(quantity)

        if not mergedCart[itemIndex] then
            mergedCart[itemIndex] =
                0
            mergedOrder[#mergedOrder + 1] =
                itemIndex
        end

        mergedCart[itemIndex] =
            mergedCart[itemIndex] + quantity
    end

    for _, itemIndex in ipairs(mergedOrder) do
        local quantity =
            mergedCart[itemIndex]

        local item =
            GetItem(itemIndex)

        if not item then
            Notify(src, 'This item is unavailable.', 'error')
            return nil
        end

        if not QBCore.Shared
        or not QBCore.Shared.Items
        or not QBCore.Shared.Items[item.item] then
            Notify(src, 'This item is unavailable.', 'error')
            return nil
        end

        local price =
            tonumber(item.price) or 0
        local amount =
            tonumber(item.amount) or 1
        local maxQuantity =
            GetItemMaxQuantity(item)

        quantity =
            math.min(quantity, maxQuantity)

        if price <= 0
        or amount <= 0 then
            Notify(src, 'This item is unavailable.', 'error')
            return nil
        end

        local finalAmount =
            amount * quantity

        order[#order + 1] = {
            itemIndex = itemIndex,
            item = item,
            amount = finalAmount,
            quantity = quantity,
            subtotal = price * quantity,
        }

        total =
            total + (price * quantity)
    end

    return order, total
end

local function RollbackItems(Player, addedItems)
    for _, line in ipairs(addedItems or {}) do
        Player.Functions.RemoveItem(line.item.item, line.amount)
    end
end

local function CompleteOrder(src, Player, order, total)
    if GetCash(Player) < total then
        Notify(src, "You don't have enough cash.", 'error')
        return false
    end

    local addedItems = {}

    for _, line in ipairs(order) do
        local added =
            Player.Functions.AddItem(line.item.item, line.amount)

        if not added then
            RollbackItems(Player, addedItems)
            Notify(src, 'You cannot carry this order.', 'error')
            return false
        end

        addedItems[#addedItems + 1] =
            line
    end

    local removed =
        Player.Functions.RemoveMoney('cash', total, 'black-market-purchase')

    if removed == false then
        RollbackItems(Player, addedItems)
        Notify(src, "You don't have enough cash.", 'error')
        return false
    end

    for _, line in ipairs(addedItems) do
        TriggerClientEvent(
            'inventory:client:ItemBox',
            src,
            QBCore.Shared.Items[line.item.item],
            'add',
            line.amount
        )
    end

    Notify(src, 'Purchase successful.', 'success')
    return true
end

local function ValidateStockForOrder(src, locationId, order)
    if not IsStockEnabled() then
        return true
    end

    for _, line in ipairs(order or {}) do
        local availableStock =
            GetStock(locationId, line.itemIndex)

        if line.quantity > availableStock then
            Notify(
                src,
                ('Not enough stock for %s. Available: %s.'):format(line.item.label or line.itemIndex, availableStock),
                'error'
            )
            return false
        end
    end

    return true
end

local function ReduceStockForOrder(locationId, order)
    if not IsStockEnabled() then
        return
    end

    for _, line in ipairs(order or {}) do
        local key =
            GetStockKey(locationId, line.itemIndex)

        dealerStock[key] =
            math.max(0, (tonumber(dealerStock[key]) or 0) - line.quantity)
    end
end

local function GetPhoneOrderMessage(key, fallback)
    return Config.PhoneOrders
        and Config.PhoneOrders.messages
        and Config.PhoneOrders.messages[key]
        or fallback
end

local function GetOrderOwnerId(src)
    local Player =
        QBCore.Functions.GetPlayer(src)

    if Player
    and Player.PlayerData
    and Player.PlayerData.citizenid then
        return Player.PlayerData.citizenid
    end

    return tostring(src)
end

local function BuildLocationHint(location)
    if not location then
        return 'Unknown Door'
    end

    return location.label or 'Unknown Door'
end

local function CountActiveOrders(owner)
    local count = 0

    for _, order in pairs(phoneOrders) do
        if order.owner == owner
        and order.status == 'pending' then
            count = count + 1
        end
    end

    return count
end

local function ReturnReservedStock(order)
    if not order
    or not IsStockEnabled() then
        return
    end

    local locationId =
        order.locationId

    for _, line in ipairs(order.items or {}) do
        local key =
            GetStockKey(locationId, line.itemIndex)

        dealerStock[key] =
            (tonumber(dealerStock[key]) or 0) + (tonumber(line.quantity) or 0)
    end
end

local function ExpirePhoneOrders()
    local now =
        os.time()

    for _, order in pairs(phoneOrders) do
        if order.status == 'pending'
        and order.expiresAt <= now then
            order.status =
                'expired'

            if Config.PhoneOrders
            and Config.PhoneOrders.returnStockOnExpire ~= false then
                ReturnReservedStock(order)
            end
        end
    end
end

local function BuildPlayerOrders(src)
    ExpirePhoneOrders()

    local owner =
        GetOrderOwnerId(src)
    local orders = {}
    local now =
        os.time()

    for _, order in pairs(phoneOrders) do
        if order.owner == owner
        and order.status == 'pending' then
            local location =
                GetLocation(order.locationId)

            if Config.PhoneOrders
            and Config.PhoneOrders.followRelocation then
                location =
                    GetCurrentActiveDealerLocation() or location
            end

            orders[#orders + 1] = {
                id = order.id,
                status = order.status,
                pickup = BuildLocationHint(location),
                locationId = location and location.id or order.locationId,
                expiresAt = order.expiresAt,
                expiresIn = math.max(0, order.expiresAt - now),
                total = order.total,
                depositPaid = order.depositPaid,
                remainingDue = order.remainingDue,
                items = order.items,
            }
        end
    end

    table.sort(orders, function(a, b)
        return (a.id or 0) < (b.id or 0)
    end)

    return orders
end

local function GetVehicleOffersConfig()
    return Config.VehicleOffers or {}
end

local function IsDynamicVehicleOffersEnabled()
    return Config.VehicleOfferDemand
        and Config.VehicleOfferDemand.enabled ~= false
end

local function GetVehicleOfferRotationSeconds()
    return Config.VehicleOfferDemand
        and tonumber(Config.VehicleOfferDemand.rotateSeconds)
        or tonumber((GetVehicleOffersConfig()).expireSeconds)
        or 1800
end

local function GetVehicleOfferRotationRemaining()
    if not nextVehicleOfferRotationAt
    or nextVehicleOfferRotationAt <= 0 then
        return 0
    end

    return math.max(0, nextVehicleOfferRotationAt - os.time())
end

local function PickWeighted(items)
    local totalWeight =
        0

    for _, item in ipairs(items or {}) do
        totalWeight =
            totalWeight + (tonumber(item.weight) or 1)
    end

    if totalWeight <= 0 then
        return nil
    end

    local roll =
        math.random() * totalWeight
    local running =
        0

    for _, item in ipairs(items or {}) do
        running =
            running + (tonumber(item.weight) or 1)

        if roll <= running then
            return item
        end
    end

    return items and items[#items] or nil
end

local function BuildWeightedLevelList(levels)
    local list = {}

    for key, level in pairs(levels or {}) do
        list[#list + 1] = {
            key = key,
            label = level.label or key,
            weight = tonumber(level.weight) or 1,
            data = level,
        }
    end

    return list
end

local function PickDemandLevel()
    local demand =
        Config.VehicleOfferDemand or {}
    local picked =
        PickWeighted(BuildWeightedLevelList(demand.levels))

    if picked then
        return picked.key, picked.data
    end

    return 'normal', {
        label = 'Normal',
        bonusMultiplier = 1.0,
    }
end

local function PickHeatLevel()
    local heat =
        Config.VehicleOfferHeat or {}
    local picked =
        PickWeighted(BuildWeightedLevelList(heat.levels))

    if picked then
        return picked.key, picked.data
    end

    local defaultHeat =
        heat.defaultHeat or 'low'

    return defaultHeat, (
        heat.levels
        and heat.levels[defaultHeat]
    ) or {
        label = 'Low',
        alertChance = 10,
        evidenceChance = 10,
        bonusRiskMultiplier = 1.0,
    }
end

local function GetModelHash(model)
    if type(model) == 'number' then
        return model
    end

    if type(model) ~= 'string'
    or model == '' then
        return nil
    end

    if joaat then
        return joaat(model)
    end

    if GetHashKey then
        return GetHashKey(model)
    end

    return nil
end

local function BuildModelHashSet(template)
    local hashes = {}

    if template.model then
        local hash =
            GetModelHash(template.model)

        if hash then
            hashes[hash] =
                true
        end
    end

    for _, model in ipairs(template.models or {}) do
        local hash =
            GetModelHash(model)

        if hash then
            hashes[hash] =
                true
        end
    end

    return hashes
end

local function GetTemplateSource()
    if Config.VehicleOfferTemplates
    and #Config.VehicleOfferTemplates > 0 then
        return Config.VehicleOfferTemplates
    end

    local templates = {}

    for _, offer in ipairs((GetVehicleOffersConfig()).offers or {}) do
        templates[#templates + 1] = {
            id = offer.id,
            label = offer.requestLabel or offer.label,
            matchType = offer.type or offer.matchType,
            vehicleClass = offer.vehicleClass,
            model = offer.model,
            baseBonus = offer.bonus,
            requiredRep = offer.requiredRep,
            deliveryShopId = offer.deliveryShopId,
            deliveryLabel = offer.deliveryLabel,
            weight = offer.weight or 10,
        }
    end

    return templates
end

local function GenerateVehicleOffers()
    local demandConfig =
        Config.VehicleOfferDemand or {}

    if demandConfig.enabled == false then
        return
    end

    local templates =
        GetTemplateSource()
    local offersPerCycle =
        tonumber(demandConfig.offersPerCycle) or 5
    local rotateSeconds =
        GetVehicleOfferRotationSeconds()
    local now =
        os.time()
    local usedTemplates = {}
    local generated = {}

    for _ = 1, math.min(offersPerCycle, #templates) do
        local candidates = {}

        for _, template in ipairs(templates) do
            if not usedTemplates[template.id] then
                candidates[#candidates + 1] =
                    template
            end
        end

        if #candidates < 1 then
            break
        end

        local template =
            PickWeighted(candidates)

        if not template then
            break
        end

        usedTemplates[template.id] =
            true

        local demandLevel, demand =
            PickDemandLevel()
        local heatLevel, heat =
            PickHeatLevel()
        local baseBonus =
            tonumber(template.baseBonus or template.bonus) or 1000
        local finalBonus =
            math.floor(
                baseBonus
                * (tonumber(demand.bonusMultiplier) or 1.0)
                * (tonumber(heat.bonusRiskMultiplier) or 1.0)
            )
        local offerId =
            ('vehicle_offer_%s_%s'):format(now, nextVehicleOfferId)

        nextVehicleOfferId =
            nextVehicleOfferId + 1

        generated[#generated + 1] = {
            id = offerId,
            templateId = template.id,
            label = template.label or template.id,
            requestLabel = template.label or template.id,
            matchType = template.matchType or template.type or 'model',
            type = template.matchType or template.type or 'model',
            vehicleClass = template.vehicleClass,
            model = template.model,
            modelHash = GetModelHash(template.model),
            modelHashes = BuildModelHashSet(template),
            baseBonus = baseBonus,
            finalBonus = finalBonus,
            bonus = finalBonus,
            demandLevel = demandLevel,
            demandLabel = demand.label or demandLevel,
            heatLevel = heatLevel,
            heatLabel = heat.label or heatLevel,
            policeHeat = heat.label or heatLevel,
            alertChance = tonumber(heat.alertChance) or 0,
            evidenceChance = tonumber(heat.evidenceChance) or 0,
            requiredRep = tonumber(template.requiredRep) or 0,
            deliveryShopId = template.deliveryShopId or 'bennys_chop_01',
            deliveryLabel = template.deliveryLabel or "Benny's Back Room",
            expiresAt = now + rotateSeconds,
            createdAt = now,
        }
    end

    dynamicVehicleOffers =
        generated
    nextVehicleOfferRotationAt =
        now + rotateSeconds

    print(('[gs_blackmarket] Generated %s ShadowMarket vehicle offers.'):format(#dynamicVehicleOffers))
end

local function EnsureVehicleOffersGenerated()
    if not IsDynamicVehicleOffersEnabled() then
        return
    end

    if #dynamicVehicleOffers < 1
    or GetVehicleOfferRotationRemaining() <= 0 then
        GenerateVehicleOffers()
    end
end

local function GetVehicleOfferById(offerId)
    if not offerId then
        return nil
    end

    EnsureVehicleOffersGenerated()

    for _, offer in ipairs(dynamicVehicleOffers or {}) do
        if offer.id == offerId then
            return offer
        end
    end

    if IsDynamicVehicleOffersEnabled() then
        return nil
    end

    for _, offer in ipairs((GetVehicleOffersConfig()).offers or {}) do
        if offer.id == offerId then
            return offer
        end
    end

    return nil
end

local function GetVehicleOfferOwner(src)
    return GetOrderOwnerId(src)
end

local function ExpireVehicleOffer(owner)
    local active =
        owner and activeVehicleOffers[owner] or nil

    if active
    and active.status == 'accepted'
    and active.expiresAt <= os.time() then
        active.status =
            'expired'
        activeVehicleOffers[owner] =
            nil
        return true
    end

    return false
end

local function GetActiveVehicleOfferRecord(src)
    local owner =
        GetVehicleOfferOwner(src)

    ExpireVehicleOffer(owner)

    local active =
        activeVehicleOffers[owner]

    if active
    and active.status == 'accepted' then
        return active
    end

    return nil
end

local function BuildVehicleOfferRow(src, offer, active)
    local location =
        GetCurrentActiveDealerLocation()
    local locationId =
        location
        and location.id
        or 'global'
    local rep =
        GetDealerRep(src, locationId)
    local requiredRep =
        tonumber(offer.requiredRep) or 0
    local unlocked =
        rep >= requiredRep
    local expiresSeconds =
        offer.expiresAt and math.max(0, offer.expiresAt - os.time())
        or tonumber(offer.expiresSeconds)
        or tonumber((GetVehicleOffersConfig()).expireSeconds)
        or 1800

    return {
        id = offer.id,
        label = offer.label or offer.requestLabel or offer.id,
        requestLabel = offer.requestLabel or offer.label or offer.id,
        matchType = offer.matchType or offer.type or 'model',
        vehicleClass = offer.vehicleClass,
        model = offer.model,
        finalBonus = tonumber(offer.finalBonus or offer.bonus) or 0,
        bonus = tonumber(offer.finalBonus or offer.bonus) or 0,
        baseBonus = tonumber(offer.baseBonus or offer.bonus) or 0,
        expiresSeconds = expiresSeconds,
        expiresAt = offer.expiresAt,
        expiresIn = offer.expiresAt and math.max(0, offer.expiresAt - os.time()) or expiresSeconds,
        deliveryShopId = offer.deliveryShopId or 'bennys_chop_01',
        deliveryLabel = offer.deliveryLabel or "Benny's Back Room",
        deliveryShopLabel = offer.deliveryLabel or "Benny's Back Room",
        demandLevel = offer.demandLevel or 'normal',
        demandLabel = offer.demandLabel or 'Normal',
        heatLevel = offer.heatLevel or 'low',
        heatLabel = offer.heatLabel or offer.policeHeat or 'Low',
        policeHeat = offer.heatLabel or offer.policeHeat or 'Low',
        alertChance = tonumber(offer.alertChance) or 0,
        evidenceChance = tonumber(offer.evidenceChance) or 0,
        requiredRep = requiredRep,
        reputation = rep,
        unlocked = unlocked,
        expired = offer.expiresAt ~= nil and offer.expiresAt <= os.time(),
        lockReason = unlocked and nil or ('Requires dealer rep %s.'):format(requiredRep),
        active = active ~= nil and active.offerId == offer.id,
    }
end

local function BuildPlayerVehicleOffers(src)
    local vehicleOffers =
        GetVehicleOffersConfig()

    if vehicleOffers.enabled == false then
        return {}
    end

    local active =
        GetActiveVehicleOfferRecord(src)
    local rows = {}
    local sourceOffers =
        nil

    if IsDynamicVehicleOffersEnabled() then
        EnsureVehicleOffersGenerated()
        sourceOffers =
            dynamicVehicleOffers
    else
        sourceOffers =
            vehicleOffers.offers or {}
    end

    for _, offer in ipairs(sourceOffers or {}) do
        if not offer.expiresAt
        or offer.expiresAt > os.time() then
            rows[#rows + 1] =
                BuildVehicleOfferRow(src, offer, active)
        end
    end

    return rows
end

local function BuildVehicleOffers(src)
    return BuildPlayerVehicleOffers(src)
end

local function BuildActiveVehicleOffer(src)
    local active =
        GetActiveVehicleOfferRecord(src)

    if not active then
        return nil
    end

    return {
        id = active.offerId,
        templateId = active.templateId,
        status = active.status,
        label = active.label or active.requestLabel or active.offerId,
        requestLabel = active.requestLabel or active.label or active.offerId,
        finalBonus = tonumber(active.finalBonus or active.bonus) or 0,
        bonus = tonumber(active.finalBonus or active.bonus) or 0,
        deliveryShopId = active.deliveryShopId or 'bennys_chop_01',
        deliveryLabel = active.deliveryLabel or "Benny's Back Room",
        demandLevel = active.demandLevel or 'normal',
        demandLabel = active.demandLabel or 'Normal',
        heatLevel = active.heatLevel or 'low',
        heatLabel = active.heatLabel or active.policeHeat or 'Low',
        policeHeat = active.heatLabel or active.policeHeat or 'Low',
        alertChance = tonumber(active.alertChance) or 0,
        evidenceChance = tonumber(active.evidenceChance) or 0,
        acceptedAt = active.acceptedAt,
        expiresAt = active.expiresAt,
        expiresIn = math.max(0, (active.expiresAt or os.time()) - os.time()),
    }
end

local function BuildVehicleOfferMetadata(offer, action, extra)
    local metadata = {
        type = 'stolen_vehicle_offer',
        action = action,
        offerId = offer and (offer.id or offer.offerId) or nil,
        templateId = offer and offer.templateId or nil,
        demandLevel = offer and offer.demandLevel or nil,
        heatLevel = offer and offer.heatLevel or nil,
        vehicleClass = offer and offer.vehicleClass or nil,
        model = offer and offer.model or nil,
        deliveryShopId = offer and offer.deliveryShopId or nil,
        time = os.time(),
    }

    for key, value in pairs(extra or {}) do
        metadata[key] =
            value
    end

    return metadata
end

local function TryVehicleOfferEvidence(src, offer, action, chance, extra)
    chance =
        tonumber(chance) or 0

    if chance <= 0
    or math.random(100) > chance then
        return
    end

    AddShadowMarketEvidence(
        src,
        'stolen_goods_trace',
        BuildVehicleOfferMetadata(offer, action, extra)
    )
end

local function TryVehicleOfferPoliceAlert(src, reason, chance, offer, extra)
    chance =
        tonumber(chance) or 0

    if chance <= 0
    or math.random(100) > chance then
        return
    end

    local location =
        GetCurrentActiveDealerLocation()
        or (
            Config.BlackMarketLocations
            and Config.BlackMarketLocations[1]
        )

    if not location then
        return
    end

    local metadata =
        BuildVehicleOfferMetadata(offer, reason, extra)
    local incidentType =
        reason == 'shadowmarket_vehicle_delivery'
        and 'stolen_vehicle_delivery'
        or 'shadowmarket_vehicle_offer'

    local alertData = {
        title = 'ShadowMarket Vehicle Offer',
        message = 'Suspicious stolen vehicle buyer activity reported.',
        coords = location.coords,
        locationId = location.id,
        reason = reason,
        incidentType = incidentType,
        threatLevel = 'low',
        preferredResponse = 'investigate',
        forcePolicy = 'less_lethal_preferred',
        source = src,
        sourceResource = 'gs_blackmarket',
        demandLevel = offer and offer.demandLevel or nil,
        heatLevel = offer and offer.heatLevel or nil,
        vehicleClass = offer and offer.vehicleClass or nil,
        model = offer and offer.model or nil,
        deliveryShopId = offer and offer.deliveryShopId or nil,
        metadata = metadata,
    }

    RouteAlertToPolice(alertData)

    if GetResourceState('gs_dispatch') == 'started' then
        TriggerEvent('gs_dispatch:server:createAlert', alertData)
        return
    end

    if Config.Debug then
        print('[gs_blackmarket] Vehicle offer police alert placeholder:')
        print(EncodeForDebug(alertData))
    end
end

local function OfferMatchesVehicle(offer, vehicleData)
    if type(offer) ~= 'table'
    or type(vehicleData) ~= 'table' then
        return false
    end

    local matchType =
        offer.matchType or offer.type

    if matchType == 'class' then
        return tonumber(vehicleData.vehicleClass) == tonumber(offer.vehicleClass)
    end

    local vehicleModel =
        tonumber(vehicleData.vehicleModel or vehicleData.model)

    if not vehicleModel then
        return false
    end

    if offer.modelHash
    and vehicleModel == tonumber(offer.modelHash) then
        return true
    end

    if offer.model then
        local modelHash =
            GetModelHash(offer.model)

        if modelHash
        and vehicleModel == modelHash then
            return true
        end
    end

    return offer.modelHashes
        and offer.modelHashes[vehicleModel] == true
end

local function GetActiveVehicleOfferForChop(src, vehicleData)
    local active =
        GetActiveVehicleOfferRecord(src)

    if not active then
        return {
            ok = false,
            reason = 'no_active_offer',
        }
    end

    if vehicleData
    and vehicleData.shopId
    and active.deliveryShopId
    and vehicleData.shopId ~= active.deliveryShopId then
        return {
            ok = false,
            reason = 'wrong_delivery',
        }
    end

    if not OfferMatchesVehicle(active, vehicleData) then
        return {
            ok = false,
            reason = 'no_match',
        }
    end

    return {
        ok = true,
        matched = true,
        offer = {
            id = active.offerId,
            templateId = active.templateId,
            label = active.label or active.requestLabel or active.offerId,
            offerLabel = active.label or active.requestLabel or active.offerId,
            requestLabel = active.requestLabel or active.label or active.offerId,
            bonus = tonumber(active.finalBonus or active.bonus) or 0,
            finalBonus = tonumber(active.finalBonus or active.bonus) or 0,
            deliveryShopId = active.deliveryShopId or 'bennys_chop_01',
            deliveryLabel = active.deliveryLabel or "Benny's Back Room",
            demandLevel = active.demandLevel,
            heatLevel = active.heatLevel,
            demandLabel = active.demandLabel,
            heatLabel = active.heatLabel,
            policeHeat = active.heatLabel or active.policeHeat or 'Low',
            alertChance = tonumber(active.alertChance) or 0,
            evidenceChance = tonumber(active.evidenceChance) or 0,
            expiresAt = active.expiresAt,
        },
    }
end

local function CompleteVehicleOffer(src, offerId, deliveryData)
    local owner =
        GetVehicleOfferOwner(src)
    local active =
        activeVehicleOffers[owner]

    if not active
    or active.status ~= 'accepted'
    or active.offerId ~= offerId then
        return {
            ok = false,
            reason = 'no_active_offer',
        }
    end

    active.status =
        'completed'
    active.completedAt =
        os.time()
    active.delivery =
        deliveryData or {}
    recentVehicleDeliveries[#recentVehicleDeliveries + 1] = {
        offerId = offerId,
        templateId = active.templateId,
        demandLevel = active.demandLevel,
        heatLevel = active.heatLevel,
        deliveredAt = active.completedAt,
    }
    vehicleOfferHeat[active.templateId or offerId] = {
        heatLevel = active.heatLevel,
        updatedAt = active.completedAt,
    }
    activeVehicleOffers[owner] =
        nil

    local vehicleOffers =
        GetVehicleOffersConfig()

    if vehicleOffers.createEvidenceOnDelivery ~= false then
        TryVehicleOfferEvidence(
            src,
            active,
            'shadowmarket_vehicle_delivery',
            active.evidenceChance,
            {
                plate = deliveryData and deliveryData.vehiclePlate or nil,
                vehicleModel = deliveryData and deliveryData.vehicleModel or nil,
                vehicleClass = deliveryData and deliveryData.vehicleClass or nil,
                payout = deliveryData and deliveryData.payout or nil,
                bonus = tonumber(active.finalBonus or active.bonus) or 0,
            }
        )
    end

    TryVehicleOfferPoliceAlert(
        src,
        'shadowmarket_vehicle_delivery',
        active.alertChance,
        active,
        deliveryData
    )

    local location =
        GetCurrentActiveDealerLocation()
    local locationId =
        location
        and location.id
        or 'global'
    local repGain =
        tonumber(vehicleOffers.repGainOnDelivery) or 0

    if repGain > 0 then
        local key =
            GetRepKey(src, locationId)
        local current =
            GetDealerRep(src, locationId)
        local maxRep =
            Config.Reputation
            and tonumber(Config.Reputation.maxRep)
            or 100

        dealerReputation[key] =
            math.min(maxRep, current + repGain)
    end

    return {
        ok = true,
        message = (
            vehicleOffers.messages
            and vehicleOffers.messages.completed
        ) or 'Vehicle offer completed.',
        bonus = tonumber(active.finalBonus or active.bonus) or 0,
    }
end

exports('GetActiveVehicleOffer', GetActiveVehicleOfferForChop)
exports('CompleteVehicleOffer', CompleteVehicleOffer)

local function BuildOrderItemsForStorage(order)
    local items = {}

    for _, line in ipairs(order or {}) do
        items[#items + 1] = {
            itemIndex = line.itemIndex,
            itemName = line.item.item,
            label = line.item.label or line.item.item,
            quantity = line.quantity,
            amount = line.amount,
            price = tonumber(line.item.price) or 0,
        }
    end

    return items
end

local function AddOrderItemsToInventory(src, Player, order)
    local addedItems = {}

    for _, line in ipairs(order.items or {}) do
        local added =
            Player.Functions.AddItem(line.itemName, line.amount)

        if not added then
            for _, addedLine in ipairs(addedItems) do
                Player.Functions.RemoveItem(addedLine.itemName, addedLine.amount)
            end

            Notify(src, 'You cannot carry this order.', 'error')
            return false
        end

        addedItems[#addedItems + 1] =
            line
    end

    for _, line in ipairs(addedItems) do
        if QBCore.Shared
        and QBCore.Shared.Items
        and QBCore.Shared.Items[line.itemName] then
            TriggerClientEvent(
                'inventory:client:ItemBox',
                src,
                QBCore.Shared.Items[line.itemName],
                'add',
                line.amount
            )
        end
    end

    return true
end

local function BuildDealerItems(src, locationId)
    local items = {}
    local rep =
        GetDealerRep(src, locationId)

    for itemIndex, item in ipairs(Config.Items or {}) do
        local unlocked, lockReason =
            GetItemAccessState(src, locationId, itemIndex, item)

        items[#items + 1] = {
            itemIndex = itemIndex,
            label = item.label,
            itemName = item.item,
            price = item.price,
            category = item.category,
            description = item.description,
            image = item.image,
            maxQuantity = item.maxQuantity,
            stock = GetStock(locationId, itemIndex),
            requiredRep = item.requiredRep or 0,
            reputation = rep,
            unlocked = unlocked,
            lockReason = lockReason,
            rotationGroup = item.rotationGroup,
        }
    end

    return items
end

local function CheckRestock()
    local now =
        os.time()
    local restockSeconds =
        GetRestockSeconds()

    for _, location in ipairs(Config.BlackMarketLocations or {}) do
        local locationId =
            location.id

        if not nextRestockAt[locationId] then
            nextRestockAt[locationId] =
                now + restockSeconds
        end

        if now >= nextRestockAt[locationId] then
            RestockLocation(locationId)
            nextRestockAt[locationId] =
                now + restockSeconds
        end
    end
end

InitializeStock()
InitializeRotation()
InitializeActiveLocations()

QBCore.Functions.CreateCallback('gs_blackmarket:server:getDealerData', function(source, cb, locationId)
    local location =
        GetLocation(locationId)

    if not IsLocationUsable(location) then
        cb({
            unavailable = true,
            message = (
                Config.Relocation
                and Config.Relocation.messages
                and Config.Relocation.messages.unavailable
            )
            or 'Nobody answers the door.',
            items = {},
            reputation = GetDealerRep(source, locationId),
            restockRemaining = 0,
            rotationRemaining = 0,
            relocationRemaining = GetRelocationRemaining(),
        })
        return
    end

    cb({
        items = BuildDealerItems(source, location.id),
        reputation = GetDealerRep(source, location.id),
        restockRemaining = GetRestockRemaining(location.id),
        rotationRemaining = GetRotationRemaining(location.id),
        relocationRemaining = GetRelocationRemaining(),
    })
end)

QBCore.Functions.CreateCallback('gs_blackmarket:server:getActiveLocations', function(source, cb)
    cb(activeDealerLocations or {})
end)

QBCore.Functions.CreateCallback('gs_blackmarket:server:getShadowMarketData', function(source, cb)
    local location =
        GetCurrentActiveDealerLocation()
    local locationId =
        location
        and location.id
        or 'global'

    cb({
        reputation = GetDealerRep(source, locationId),
        activeLocation = location and {
            id = location.id,
            label = location.label,
            hint = BuildLocationHint(location),
        } or nil,
        items = location and BuildDealerItems(source, location.id) or {},
        pendingOrders = BuildPlayerOrders(source),
        vehicleOffers = BuildVehicleOffers(source),
        activeVehicleOffer = BuildActiveVehicleOffer(source),
        vehicleOfferRotationRemaining = GetVehicleOfferRotationRemaining(),
        orderExpireSeconds = Config.PhoneOrders
            and Config.PhoneOrders.expireSeconds
            or 1800,
    })
end)

QBCore.Functions.CreateCallback('gs_blackmarket:server:acceptVehicleOffer', function(source, cb, offerId)
    local src =
        source
    local vehicleOffers =
        GetVehicleOffersConfig()
    local messages =
        vehicleOffers.messages or {}

    if vehicleOffers.enabled == false then
        cb({
            ok = false,
            message = messages.unavailable or 'That vehicle offer is no longer available.',
        })
        return
    end

    local canAccess =
        CanAccessShadowMarket(src)

    if not canAccess then
        cb({
            ok = false,
            message = Config.PhoneApp
                and Config.PhoneApp.messages
                and Config.PhoneApp.messages.accessDenied
                or 'Nothing happens.',
        })
        return
    end

    local owner =
        GetVehicleOfferOwner(src)

    ExpireVehicleOffer(owner)

    if activeVehicleOffers[owner]
    and activeVehicleOffers[owner].status == 'accepted' then
        cb({
            ok = false,
            message = messages.alreadyActive or 'You already have an active vehicle offer.',
            activeVehicleOffer = BuildActiveVehicleOffer(src),
        })
        return
    end

    local offer =
        GetVehicleOfferById(offerId)

    if not offer then
        cb({
            ok = false,
            message = messages.unavailable or 'That vehicle offer is no longer available.',
        })
        return
    end

    if offer.expiresAt
    and offer.expiresAt <= os.time() then
        cb({
            ok = false,
            message = messages.unavailable or 'That vehicle offer is no longer available.',
        })
        return
    end

    local location =
        GetCurrentActiveDealerLocation()
    local locationId =
        location
        and location.id
        or 'global'
    local rep =
        GetDealerRep(src, locationId)
    local requiredRep =
        tonumber(offer.requiredRep) or 0

    if rep < requiredRep then
        cb({
            ok = false,
            message = messages.locked or 'You need more ShadowMarket reputation for that offer.',
        })
        return
    end

    local now =
        os.time()
    local expiresAt =
        offer.expiresAt
        or now + (
            tonumber(offer.expiresSeconds)
            or tonumber(vehicleOffers.expireSeconds)
            or 1800
        )

    activeVehicleOffers[owner] = {
        owner = owner,
        source = src,
        offerId = offer.id,
        templateId = offer.templateId or offer.id,
        label = offer.label or offer.requestLabel or offer.id,
        requestLabel = offer.requestLabel or offer.label or offer.id,
        matchType = offer.matchType or offer.type or 'model',
        type = offer.matchType or offer.type or 'model',
        vehicleClass = offer.vehicleClass,
        model = offer.model,
        modelHash = offer.modelHash or GetModelHash(offer.model),
        modelHashes = offer.modelHashes or BuildModelHashSet(offer),
        finalBonus = tonumber(offer.finalBonus or offer.bonus) or 0,
        bonus = tonumber(offer.finalBonus or offer.bonus) or 0,
        baseBonus = tonumber(offer.baseBonus or offer.bonus) or 0,
        demandLevel = offer.demandLevel or 'normal',
        demandLabel = offer.demandLabel or 'Normal',
        heatLevel = offer.heatLevel or 'low',
        heatLabel = offer.heatLabel or offer.policeHeat or 'Low',
        policeHeat = offer.heatLabel or offer.policeHeat or 'Low',
        alertChance = tonumber(offer.alertChance) or tonumber(vehicleOffers.acceptPoliceAlertChance) or 0,
        evidenceChance = tonumber(offer.evidenceChance) or 0,
        deliveryShopId = offer.deliveryShopId or 'bennys_chop_01',
        deliveryLabel = offer.deliveryLabel or "Benny's Back Room",
        status = 'accepted',
        acceptedAt = now,
        expiresAt = expiresAt,
    }

    if vehicleOffers.createEvidenceOnAccept ~= false then
        TryVehicleOfferEvidence(
            src,
            activeVehicleOffers[owner],
            'shadowmarket_vehicle_offer_accept',
            activeVehicleOffers[owner].evidenceChance,
            {
                request = offer.requestLabel or offer.label or offer.id,
            }
        )
    end

    TryVehicleOfferPoliceAlert(
        src,
        'shadowmarket_vehicle_offer_accept',
        activeVehicleOffers[owner].alertChance,
        activeVehicleOffers[owner],
        {
            request = offer.requestLabel or offer.label or offer.id,
        }
    )

    Notify(src, messages.accepted or "Vehicle offer accepted. Deliver the vehicle to Benny's.", 'success')

    cb({
        ok = true,
        message = messages.accepted or "Vehicle offer accepted. Deliver the vehicle to Benny's.",
        activeVehicleOffer = BuildActiveVehicleOffer(src),
        vehicleOffers = BuildVehicleOffers(src),
    })
end)

QBCore.Functions.CreateCallback('gs_blackmarket:server:placePhoneOrder', function(source, cb, cart)
    local src =
        source
    local messages =
        Config.PhoneOrders and Config.PhoneOrders.messages or {}

    if not Config.PhoneOrders
    or Config.PhoneOrders.enabled == false then
        cb({ ok = false, message = messages.orderFailed or 'Order could not be placed.' })
        return
    end

    local Player =
        QBCore.Functions.GetPlayer(src)

    if not Player then
        cb({ ok = false, message = messages.orderFailed or 'Order could not be placed.' })
        return
    end

    local canAccess =
        CanAccessShadowMarket(src)

    if not canAccess then
        cb({
            ok = false,
            message = Config.PhoneApp
                and Config.PhoneApp.messages
                and Config.PhoneApp.messages.accessDenied
                or 'Nothing happens.',
        })
        return
    end

    local owner =
        GetOrderOwnerId(src)
    local maxOrders =
        tonumber(Config.PhoneOrders.maxActiveOrders) or 2

    if CountActiveOrders(owner) >= maxOrders then
        cb({ ok = false, message = messages.tooManyOrders or 'You already have too many pending orders.' })
        return
    end

    local location =
        GetCurrentActiveDealerLocation()

    if not IsLocationUsable(location) then
        cb({ ok = false, message = messages.orderFailed or 'Order could not be placed.' })
        return
    end

    local order, total =
        BuildCartOrder(src, cart)

    if not order then
        cb({ ok = false, message = messages.orderFailed or 'Order could not be placed.' })
        return
    end

    if not ValidateAccessForOrder(src, location.id, order) then
        cb({ ok = false, message = messages.orderFailed or 'Order could not be placed.' })
        return
    end

    if not ValidateStockForOrder(src, location.id, order) then
        cb({ ok = false, message = messages.outOfStock or 'The dealer cannot reserve that item.' })
        return
    end

    local depositPercent =
        tonumber(Config.PhoneOrders.depositPercent) or 1.0
    depositPercent =
        math.max(0, math.min(1, depositPercent))

    local deposit =
        math.floor(total * depositPercent)
    local remainingDue =
        total - deposit

    if deposit > 0
    and GetCash(Player) < deposit then
        cb({ ok = false, message = messages.notEnoughCash or "You don't have enough cash." })
        return
    end

    if deposit > 0 then
        local removed =
            Player.Functions.RemoveMoney('cash', deposit, 'shadowmarket-phone-order')

        if removed == false then
            cb({ ok = false, message = messages.notEnoughCash or "You don't have enough cash." })
            return
        end
    end

    ReduceStockForOrder(location.id, order)

    local orderId =
        nextOrderId
    nextOrderId =
        nextOrderId + 1

    local now =
        os.time()
    local expiresAt =
        now + (tonumber(Config.PhoneOrders.expireSeconds) or 1800)

    phoneOrders[orderId] = {
        id = orderId,
        owner = owner,
        source = src,
        locationId = location.id,
        status = 'pending',
        createdAt = now,
        expiresAt = expiresAt,
        depositPaid = deposit,
        remainingDue = remainingDue,
        total = total,
        items = BuildOrderItemsForStorage(order),
    }

    if Config.PhoneOrders.policeAlertOnOrder then
        TryPoliceAlert(src, location, 'shadowmarket_order', false, {
            orderId = orderId,
        })
    end

    if Config.PhoneOrders.createMetadataEvidence then
        AddShadowMarketEvidence(src, 'metadata_recovered', {
            action = 'shadowmarket_order',
            orderId = orderId,
            total = total,
        })
    end

    Notify(src, messages.orderPlaced or 'Order placed. Pickup location sent.', 'success')

    cb({
        ok = true,
        orderId = orderId,
        message = messages.orderPlaced or 'Order placed. Pickup location sent.',
        pickup = BuildLocationHint(location),
        pendingOrders = BuildPlayerOrders(src),
    })
end)

QBCore.Functions.CreateCallback('gs_blackmarket:server:getPendingOrders', function(source, cb, locationId)
    cb(BuildPlayerOrders(source))
end)

QBCore.Functions.CreateCallback('gs_blackmarket:server:unlockShadowMarket', function(source, cb, code)
    local expectedCode =
        Config.PhoneApp
        and tostring(Config.PhoneApp.unlockCode or '7723')
        or '7723'

    if tostring(code or '') ~= expectedCode then
        local identifier =
            GetPlayerIdentifier(source)

        shadowMarketFailedAttempts[identifier] =
            (shadowMarketFailedAttempts[identifier] or 0) + 1

        local failedConfig =
            Config.PhoneApp
            and Config.PhoneApp.failedCodeEvidence
            or {}

        if failedConfig.enabled ~= false
        and shadowMarketFailedAttempts[identifier] >= (tonumber(failedConfig.maxAttempts) or 3) then
            AddShadowMarketEvidence(
                source,
                failedConfig.evidenceType or 'metadata_recovered',
                {
                    reason = 'failed_unlock_attempts',
                    attempts = shadowMarketFailedAttempts[identifier],
                }
            )
            shadowMarketFailedAttempts[identifier] =
                0
        end

        cb({
            ok = false,
            reason = 'bad_code',
            message = Config.PhoneApp.messages.failedCode or 'Invalid calculation.',
        })
        return
    end

    local allowed, reason, data =
        CanAccessShadowMarket(source)

    if not allowed then
        cb({
            ok = false,
            reason = reason,
            message = Config.PhoneApp.messages.accessDenied or 'Nothing happens.',
            reputation = data and data.reputation or 0,
            activeDealer = data and data.activeDealer or 'unknown',
        })
        return
    end

    cb({
        ok = true,
        message = Config.PhoneApp.messages.unlocked or 'ShadowMarket unlocked.',
        reputation = data.reputation or 0,
        activeDealer = data.activeDealer or 'unknown',
        status = 'Online',
    })
end)

QBCore.Functions.CreateCallback('gs_blackmarket:server:wipeShadowMarket', function(source, cb)
    local wipe =
        Config.PhoneApp
        and Config.PhoneApp.wipe
        or {}

    if wipe.enabled == false then
        cb({
            ok = true,
            failed = false,
            message = Config.PhoneApp.messages.wiped or 'App data wiped.',
        })
        return
    end

    local failureChance =
        tonumber(wipe.failureChance) or 0
    local failed =
        failureChance > 0
        and math.random(1, 100) <= failureChance

    if failed then
        AddShadowMarketEvidence(
            source,
            wipe.evidenceTypeOnFailure or 'failed_wipe',
            {
                reason = 'wipe_failed',
            }
        )
    end

    cb({
        ok = not failed,
        failed = failed,
        message = Config.PhoneApp.messages.wiped or 'App data wiped.',
    })
end)

QBCore.Functions.CreateCallback('gs_blackmarket:server:canPoliceDetectShadowMarket', function(source, cb, targetServerId)
    local target =
        tonumber(targetServerId) or source

    -- TODO: validate requester police job once the active police framework is finalized.
    cb({
        detectable = HasShadowMarketEvidence(target),
        evidence = GetShadowMarketEvidence(target),
    })
end)

RegisterNetEvent('gs_blackmarket:server:addShadowMarketEvidence', function(targetServerId, evidenceType, details)
    local src =
        source

    -- TODO: replace debug-only client allowance with police/dispatch authorization.
    if src ~= 0
    and not Config.Debug then
        return
    end

    local target =
        tonumber(targetServerId)

    if not target then
        return
    end

    AddShadowMarketEvidence(target, evidenceType, details)
end)

RegisterNetEvent('gs_blackmarket:server:pickupPhoneOrder', function(orderId, locationId)
    local src =
        source
    local Player =
        QBCore.Functions.GetPlayer(src)
    local messages =
        Config.PhoneOrders and Config.PhoneOrders.messages or {}

    if not Player then
        return
    end

    ExpirePhoneOrders()

    orderId =
        tonumber(orderId)

    local order =
        orderId and phoneOrders[orderId] or nil

    if not order
    or order.owner ~= GetOrderOwnerId(src)
    or order.status ~= 'pending' then
        Notify(src, messages.noOrders or 'You have no pending orders.', 'error')
        return
    end

    if order.expiresAt <= os.time() then
        order.status =
            'expired'

        if Config.PhoneOrders.returnStockOnExpire ~= false then
            ReturnReservedStock(order)
        end

        Notify(src, messages.orderExpired or 'Your order expired.', 'error')
        return
    end

    local pickupLocationId =
        order.locationId

    if Config.PhoneOrders
    and Config.PhoneOrders.followRelocation then
        local active =
            GetCurrentActiveDealerLocation()

        if active then
            pickupLocationId =
                active.id
        end
    end

    if Config.PhoneOrders
    and Config.PhoneOrders.requireActiveLocation
    and pickupLocationId ~= locationId then
        Notify(src, messages.pickupWrongLocation or 'Nobody here knows about that order.', 'error')
        return
    end

    local location =
        ValidatePurchaseContext(src, locationId)

    if not location then
        return
    end

    if order.remainingDue > 0 then
        if GetCash(Player) < order.remainingDue then
            Notify(src, messages.notEnoughCash or "You don't have enough cash.", 'error')
            return
        end

        local removed =
            Player.Functions.RemoveMoney('cash', order.remainingDue, 'shadowmarket-phone-order-pickup')

        if removed == false then
            Notify(src, messages.notEnoughCash or "You don't have enough cash.", 'error')
            return
        end
    end

    if not AddOrderItemsToInventory(src, Player, order) then
        return
    end

    order.status =
        'picked_up'

    AddDealerRep(src, location.id, order.total)

    if Config.PhoneOrders
    and Config.PhoneOrders.policeAlertOnPickup then
        TryPoliceAlert(src, location, 'shadowmarket_pickup', false, {
            orderId = order.id,
        })
    end

    Notify(src, messages.pickedUp or 'Order picked up.', 'success')
end)

RegisterNetEvent('gs_blackmarket:server:knock', function(locationId)
    local src =
        source
    local Player =
        QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    local location =
        ValidatePurchaseContext(src, locationId)

    if not location then
        return
    end

    local cooldownActive, key, remaining =
        IsDealerCooldownActive(src, Player, location.id, knockCooldowns)

    if cooldownActive then
        Notify(src, GetCooldownMessage(remaining), 'error')
        return
    end

    if Config.DealerCooldown
    and Config.DealerCooldown.enabled ~= false then
        SetCooldown(
            knockCooldowns,
            key,
            Config.DealerCooldown.knockCooldownSeconds or 30
        )
    end

    if Config.PoliceAlert
    and Config.PoliceAlert.triggerOnKnock then
        TryPoliceAlert(src, location, 'knock')
    end

    TriggerClientEvent('gs_blackmarket:client:knockApproved', src, location.id)
end)

RegisterNetEvent('gs_blackmarket:server:buyItem', function(locationId, itemIndex)
    local src =
        source
    local Player =
        QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    local location =
        ValidatePurchaseContext(src, locationId)

    if not location then
        return
    end

    local cooldownActive, key, remaining =
        IsDealerCooldownActive(src, Player, location.id, purchaseCooldowns)

    if cooldownActive then
        Notify(src, GetCooldownMessage(remaining), 'error')
        return
    end

    local order, total =
        BuildCartOrder(src, {
            {
                itemIndex = itemIndex,
                quantity = 1,
            },
        })

    if not order then
        return
    end

    if not ValidateAccessForOrder(src, location.id, order) then
        return
    end

    if not ValidateStockForOrder(src, location.id, order) then
        return
    end

    if CompleteOrder(src, Player, order, total) then
        ReduceStockForOrder(location.id, order)
        AddDealerRep(src, location.id, total)

        if Config.DealerCooldown
        and Config.DealerCooldown.enabled ~= false then
            SetCooldown(
                purchaseCooldowns,
                key,
                Config.DealerCooldown.purchaseCooldownSeconds or 120
            )
        end

        if Config.PoliceAlert
        and Config.PoliceAlert.triggerOnPurchase then
            TryPoliceAlert(src, location, 'purchase')
        end
    end
end)

RegisterNetEvent('gs_blackmarket:server:buyCart', function(locationId, cart)
    local src =
        source
    local Player =
        QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    local location =
        ValidatePurchaseContext(src, locationId)

    if not location then
        return
    end

    local cooldownActive, key, remaining =
        IsDealerCooldownActive(src, Player, location.id, purchaseCooldowns)

    if cooldownActive then
        Notify(src, GetCooldownMessage(remaining), 'error')
        return
    end

    local order, total =
        BuildCartOrder(src, cart)

    if not order then
        return
    end

    if not ValidateAccessForOrder(src, location.id, order) then
        return
    end

    if not ValidateStockForOrder(src, location.id, order) then
        return
    end

    if CompleteOrder(src, Player, order, total) then
        ReduceStockForOrder(location.id, order)
        AddDealerRep(src, location.id, total)

        if Config.DealerCooldown
        and Config.DealerCooldown.enabled ~= false then
            SetCooldown(
                purchaseCooldowns,
                key,
                Config.DealerCooldown.purchaseCooldownSeconds or 120
            )
        end

        if Config.PoliceAlert
        and Config.PoliceAlert.triggerOnPurchase then
            TryPoliceAlert(src, location, 'purchase')
        end
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        ExpirePhoneOrders()
    end
end)

CreateThread(function()
    Wait(1000)

    if Config.VehicleOfferDemand
    and Config.VehicleOfferDemand.enabled ~= false then
        GenerateVehicleOffers()

        while true do
            Wait(30000)

            if Config.VehicleOfferDemand
            and Config.VehicleOfferDemand.enabled ~= false
            and os.time() >= nextVehicleOfferRotationAt then
                GenerateVehicleOffers()
            end
        end
    end
end)

RegisterCommand('bm_testalert', function(source)
    local src =
        source

    if src == 0 then
        print('[gs_blackmarket] bm_testalert must be run by an in-game player.')
        return
    end

    local Player =
        QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    local location =
        Config.BlackMarketLocations
        and Config.BlackMarketLocations[1]

    if not location then
        TriggerClientEvent('QBCore:Notify', src, 'No black market location configured.', 'error')
        return
    end

    TryPoliceAlert(src, location, 'manual_test', true)

    TriggerClientEvent('QBCore:Notify', src, 'Black market police alert test triggered.', 'primary')
end, false)

RegisterCommand('bm_testpoliceroute', function(source)
    local src =
        source

    if src == 0 then
        print('[gs_blackmarket] Run this in-game.')
        return
    end

    local ped =
        GetPlayerPed(src)
    local coords =
        GetEntityCoords(ped)

    local alertData = {
        title = 'Test Black Market Police Route',
        message = 'Testing black market alert routing.',
        coords = coords,
        incidentType = 'blackmarket_activity',
        threatLevel = 'low',
        preferredResponse = 'investigate',
        forcePolicy = 'less_lethal_preferred',
        source = src,
        sourceResource = 'gs_blackmarket',
        reason = 'manual_test',
        metadata = {
            locationId = nil,
            heatLevel = nil,
            demandLevel = nil,
            offerId = nil,
            orderId = nil,
        },
    }

    RouteAlertToPolice(alertData)

    TriggerClientEvent('QBCore:Notify', src, 'Black market alert routed to police.', 'success')
end, false)

RegisterCommand('bm_restock', function(source)
    local location =
        Config.BlackMarketLocations
        and Config.BlackMarketLocations[1]

    if not location then
        return
    end

    RestockLocation(location.id)
    nextRestockAt[location.id] =
        os.time() + GetRestockSeconds()

    if source > 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Black market dealer restocked.', 'success')
    else
        print('[gs_blackmarket] Black market dealer restocked.')
    end
end, false)

RegisterCommand('bm_stock', function(source)
    local location =
        Config.BlackMarketLocations
        and Config.BlackMarketLocations[1]

    if not location then
        return
    end

    for index, item in ipairs(Config.Items or {}) do
        local key =
            GetStockKey(location.id, index)
        local count =
            dealerStock[key] or 0

        print(('[gs_blackmarket] %s stock: %s'):format(item.label or index, count))
    end

    if source > 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Stock printed to console.', 'primary')
    end
end, false)

RegisterCommand('sm_orders', function(source)
    if source == 0 then
        print('[gs_blackmarket] sm_orders must be run in-game.')
        return
    end

    local orders =
        BuildPlayerOrders(source)

    if #orders < 1 then
        Notify(source, GetPhoneOrderMessage('noOrders', 'You have no pending orders.'), 'primary')
        print(('[gs_blackmarket] Player %s has no pending ShadowMarket orders.'):format(source))
        return
    end

    Notify(source, ('Pending ShadowMarket orders: %s'):format(#orders), 'primary')

    for _, order in ipairs(orders) do
        print(('[gs_blackmarket] Order #%s pickup=%s total=%s expiresIn=%ss'):format(
            order.id,
            order.pickup,
            order.total,
            order.expiresIn
        ))
    end
end, false)

RegisterCommand('sm_vehicleoffers', function(source)
    EnsureVehicleOffersGenerated()

    local offers =
        source > 0
        and BuildPlayerVehicleOffers(source)
        or dynamicVehicleOffers

    if not offers
    or #offers < 1 then
        if source > 0 then
            Notify(source, 'No ShadowMarket vehicle offers are active.', 'primary')
        else
            print('[gs_blackmarket] No ShadowMarket vehicle offers are active.')
        end
        return
    end

    if source > 0 then
        Notify(source, ('ShadowMarket vehicle offers: %s'):format(#offers), 'primary')
    end

    for _, offer in ipairs(offers) do
        print(('[gs_blackmarket] Offer %s template=%s label=%s demand=%s heat=%s bonus=%s expiresIn=%ss'):format(
            offer.id or 'unknown',
            offer.templateId or 'legacy',
            offer.label or 'unknown',
            offer.demandLabel or offer.demandLevel or 'Normal',
            offer.heatLabel or offer.heatLevel or offer.policeHeat or 'Low',
            offer.finalBonus or offer.bonus or 0,
            offer.expiresIn or (offer.expiresAt and math.max(0, offer.expiresAt - os.time())) or 0
        ))
    end
end, false)

RegisterCommand('sm_rotateoffers', function(source)
    GenerateVehicleOffers()

    if source > 0 then
        Notify(source, 'ShadowMarket vehicle offers rotated.', 'success')
    else
        print('[gs_blackmarket] ShadowMarket vehicle offers rotated.')
    end
end, false)

RegisterCommand('sm_clearoffer', function(source)
    if source == 0 then
        activeVehicleOffers = {}
        print('[gs_blackmarket] Cleared all accepted ShadowMarket vehicle offers.')
        return
    end

    local owner =
        GetVehicleOfferOwner(source)

    activeVehicleOffers[owner] =
        nil

    Notify(source, 'Accepted ShadowMarket vehicle offer cleared.', 'success')
end, false)

RegisterCommand('sm_clearorders', function(source)
    if source == 0 then
        print('[gs_blackmarket] sm_clearorders must be run in-game.')
        return
    end

    local owner =
        GetOrderOwnerId(source)
    local cleared =
        0

    for _, order in pairs(phoneOrders) do
        if order.owner == owner
        and order.status == 'pending' then
            ReturnReservedStock(order)
            order.status =
                'cancelled'
            cleared =
                cleared + 1
        end
    end

    Notify(source, ('Cleared %s pending ShadowMarket orders.'):format(cleared), 'success')
end, false)

RegisterCommand('sm_expireorders', function(source)
    ExpirePhoneOrders()

    if source ~= 0 then
        Notify(source, 'ShadowMarket order expiration check ran.', 'primary')
    else
        print('[gs_blackmarket] ShadowMarket order expiration check ran.')
    end
end, false)

RegisterCommand('bm_rep', function(source)
    if source == 0 then
        print('[gs_blackmarket] bm_rep must be run in-game.')
        return
    end

    local location =
        Config.BlackMarketLocations
        and Config.BlackMarketLocations[1]

    if not location then
        return
    end

    local rep =
        GetDealerRep(source, location.id)

    TriggerClientEvent('QBCore:Notify', source, ('Dealer rep: %s'):format(rep), 'primary')
    print(('[gs_blackmarket] Player %s dealer rep: %s'):format(source, rep))
end, false)

RegisterCommand('bm_addrep', function(source, args)
    if source == 0 then
        print('[gs_blackmarket] bm_addrep must be run in-game.')
        return
    end

    local amount =
        tonumber(args[1]) or 10
    local location =
        Config.BlackMarketLocations
        and Config.BlackMarketLocations[1]

    if not location then
        return
    end

    local key =
        GetRepKey(source, location.id)
    local current =
        GetDealerRep(source, location.id)
    local maxRep =
        Config.Reputation
        and tonumber(Config.Reputation.maxRep)
        or 100

    dealerReputation[key] =
        math.min(maxRep, current + amount)

    TriggerClientEvent(
        'QBCore:Notify',
        source,
        ('Dealer rep increased to %s.'):format(dealerReputation[key]),
        'success'
    )
end, false)

RegisterCommand('bm_rotate', function(source)
    local location =
        Config.BlackMarketLocations
        and Config.BlackMarketLocations[1]

    if not location then
        return
    end

    BuildRotationForLocation(location.id)
    nextRotationAt[location.id] =
        os.time() + (
            Config.RotatingInventory
            and tonumber(Config.RotatingInventory.rotateSeconds)
            or 3600
        )

    if source > 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Dealer inventory rotated.', 'success')
    else
        print('[gs_blackmarket] Dealer inventory rotated.')
    end
end, false)

RegisterCommand('bm_relocate', function(source)
    RelocateDealer()

    if source > 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Dealer relocated.', 'success')
    else
        print('[gs_blackmarket] Dealer relocated.')
    end
end, false)

RegisterCommand('bm_activelocation', function(source)
    local activeText =
        'Active dealer locations:'

    for locationId, active in pairs(activeDealerLocations) do
        if active then
            activeText =
                activeText .. ' ' .. locationId
        end
    end

    if source > 0 then
        TriggerClientEvent('QBCore:Notify', source, activeText, 'primary')
    end

    print('[gs_blackmarket] ' .. activeText)
end, false)

RegisterCommand('sm_evidence', function(source)
    if source == 0 then
        print('[gs_blackmarket] sm_evidence must be run in-game.')
        return
    end

    local evidence =
        GetShadowMarketEvidence(source)

    if #evidence < 1 then
        TriggerClientEvent('QBCore:Notify', source, 'ShadowMarket evidence: none.', 'primary')
        print(('[gs_blackmarket] Player %s ShadowMarket evidence: none'):format(source))
        return
    end

    TriggerClientEvent('QBCore:Notify', source, ('ShadowMarket evidence flags: %s'):format(#evidence), 'primary')

    for index, entry in ipairs(evidence) do
        print(('[gs_blackmarket] Evidence %s for player %s: %s'):format(index, source, entry.type or 'unknown'))
    end
end, false)

RegisterCommand('sm_wipe', function(source)
    if source == 0 then
        print('[gs_blackmarket] sm_wipe must be run in-game.')
        return
    end

    ClearShadowMarketEvidence(source)
    TriggerClientEvent('QBCore:Notify', source, 'ShadowMarket evidence flags wiped.', 'success')
end, false)

CreateThread(function()
    while true do
        Wait(30000)

        if IsStockEnabled() then
            CheckRestock()
        end
    end
end)

CreateThread(function()
    Wait(1000)

    if Config.Relocation
    and Config.Relocation.enabled then
        nextRelocationAt =
            os.time() + (
                Config.Relocation.relocateSeconds or 7200
            )

        while true do
            Wait(30000)

            if os.time() >= nextRelocationAt then
                RelocateDealer()
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(30000)

        if Config.RotatingInventory
        and Config.RotatingInventory.enabled then
            local now =
                os.time()
            local rotateSeconds =
                tonumber(Config.RotatingInventory.rotateSeconds) or 3600

            for _, location in ipairs(Config.BlackMarketLocations or {}) do
                if not nextRotationAt[location.id] then
                    nextRotationAt[location.id] =
                        now + rotateSeconds
                end

                if now >= nextRotationAt[location.id] then
                    BuildRotationForLocation(location.id)
                    nextRotationAt[location.id] =
                        now + rotateSeconds
                end
            end
        end
    end
end)

CreateThread(function()
    if Config
    and Config.Enabled == false then
        return
    end

    Log('Resource Initialized')
end)
