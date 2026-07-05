GSBlackMarket = GSBlackMarket or {}
GSBlackMarket.Server = GSBlackMarket.Server or {}

local QBCore =
    exports['qb-core']:GetCoreObject()

local purchaseCooldowns = {}
local knockCooldowns = {}
local alertCooldowns = {}
local dealerStock = {}
local nextRestockAt = {}

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

local function GetLocation(locationId)
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

    if not location
    or not location.enabled then
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

local function TryPoliceAlert(src, location, reason, forceAlert)
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

    -- Future gs_police integration:
    -- This is a low-threat suspicious activity alert.
    -- AI police should prefer investigation and less-lethal options.
    -- Escalation should only happen if the suspect creates a higher threat:
    -- weapon drawn, shots fired, violent fleeing, attack on officers, hostage, etc.
    local alertData = {
        title = policeAlert.title or 'Suspicious Activity',
        message = policeAlert.message or 'Suspicious activity reported near a residence.',
        coords = location.coords,
        locationId = location.id,
        reason = reason,
        incidentType = policeAlert.incidentType or 'blackmarket_activity',
        threatLevel = policeAlert.threatLevel or 'low',
        preferredResponse = policeAlert.preferredResponse or 'investigate',
        forcePolicy = policeAlert.forcePolicy or 'less_lethal_preferred',
        source = src,
    }

    local dispatchEvent =
        policeAlert.dispatchEvent or 'gs_dispatch:server:createAlert'

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

local function BuildDealerItems(locationId)
    local items = {}

    for itemIndex, item in ipairs(Config.Items or {}) do
        items[#items + 1] = {
            label = item.label,
            price = item.price,
            category = item.category,
            description = item.description,
            image = item.image,
            maxQuantity = item.maxQuantity,
            stock = GetStock(locationId, itemIndex),
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

QBCore.Functions.CreateCallback('gs_blackmarket:server:getDealerData', function(source, cb, locationId)
    local location =
        GetLocation(locationId)

    if not location
    or not location.enabled then
        cb(nil)
        return
    end

    cb({
        items = BuildDealerItems(location.id),
        restockRemaining = GetRestockRemaining(location.id),
    })
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

    if not ValidateStockForOrder(src, location.id, order) then
        return
    end

    if CompleteOrder(src, Player, order, total) then
        ReduceStockForOrder(location.id, order)

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

    if not ValidateStockForOrder(src, location.id, order) then
        return
    end

    if CompleteOrder(src, Player, order, total) then
        ReduceStockForOrder(location.id, order)

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

CreateThread(function()
    while true do
        Wait(30000)

        if IsStockEnabled() then
            CheckRestock()
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
