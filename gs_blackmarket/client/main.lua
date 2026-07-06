GSBlackMarket = GSBlackMarket or {}
GSBlackMarket.Client = GSBlackMarket.Client or {}

local QBCore =
    exports['qb-core']:GetCoreObject()
local isInteracting =
    false
local isUiOpen =
    false
local nuiReady =
    false
local nuiOpenAck =
    false
local bmTestUiActive =
    false
local knockRequestCooldowns =
    {}
local activeLocations =
    {}
local isShadowMarketOpen =
    false

local function Notify(message, notificationType)
    if QBCore
    and QBCore.Functions
    and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, notificationType or 'primary')
        return
    end

    TriggerEvent('chat:addMessage', {
        args = {
            'Black Market',
            message,
        },
    })
end

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

    local factor =
        string.len(text) / 370

    DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 120)
    ClearDrawOrigin()
end

local function LoadAnimDict(dict)
    if not dict
    or dict == '' then
        return false
    end

    if HasAnimDictLoaded(dict) then
        return true
    end

    RequestAnimDict(dict)

    local timeout =
        GetGameTimer() + 3000

    while not HasAnimDictLoaded(dict) do
        Wait(10)

        if GetGameTimer() > timeout then
            return false
        end
    end

    return true
end

local function CleanupKnockState(ped)
    if ped
    and ped ~= 0 then
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
    end

    isInteracting =
        false
end

local function GetLocationById(locationId)
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

local function RefreshActiveLocations()
    QBCore.Functions.TriggerCallback('gs_blackmarket:server:getActiveLocations', function(data)
        activeLocations =
            data or {}
    end)
end

local function IsClientLocationActive(location)
    if not location then
        return false
    end

    if location.enabled == false then
        return false
    end

    if Config.Relocation
    and Config.Relocation.enabled then
        return activeLocations[location.id] == true
    end

    return location.active ~= false
end

local function OpenBlackMarketMenu(location)
    local menu = {
        {
            header = 'Black Market',
            txt = 'No refunds. No questions.',
            isMenuHeader = true,
        },
    }

    for index, item in ipairs(Config.Items or {}) do
        menu[#menu + 1] = {
            header = ('%s - $%s'):format(item.label, tostring(item.price)),
            txt = item.description or ('Category: ' .. (item.category or 'unknown')),
            params = {
                event = 'gs_blackmarket:client:selectItem',
                args = {
                    locationId = location.id,
                    itemIndex = index,
                },
            },
        }
    end

    menu[#menu + 1] = {
        header = 'Leave',
        txt = 'Walk away from the door.',
        params = {
            event = 'qb-menu:client:closeMenu',
        },
    }

    exports['qb-menu']:openMenu(menu)
end

local function CloseBlackMarketUI()
    isUiOpen =
        false
    nuiOpenAck =
        false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'close',
    })
end

local function CloseShadowMarketUI()
    isShadowMarketOpen =
        false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'shadowmarketClose',
    })
end

local function OpenShadowMarketPhone()
    isShadowMarketOpen =
        true

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'shadowmarketOpen',
        visibleName = (Config.PhoneApp and Config.PhoneApp.visibleName) or 'Calculator',
        hiddenName = (Config.PhoneApp and Config.PhoneApp.hiddenName) or 'ShadowMarket',
    })
end

local function OpenBlackMarketFallback(location)
    print('[gs_blackmarket] Opening fallback qb-menu')

    if bmTestUiActive then
        print('[gs_blackmarket] /bm_testui fallback opened qb-menu')
        bmTestUiActive =
            false
    end

    isUiOpen =
        false
    nuiOpenAck =
        false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'close',
    })

    if not location then
        Notify('Black market menu is unavailable.', 'error')
        return
    end

    if OpenBlackMarketMenu then
        OpenBlackMarketMenu(location)
    else
        Notify('Black market menu is unavailable.', 'error')
    end
end

local function OpenBlackMarketUI(location)
    if not location then
        Notify('Black market location error.', 'error')
        return
    end

    if not Config.UseCustomUI
    or (
        Config.UI
        and Config.UI.enabled == false
    ) then
        OpenBlackMarketFallback(location)
        return
    end

    local ok, errorMessage =
        pcall(function()
            print('[gs_blackmarket] Attempting to open black market UI')
            print('[gs_blackmarket] UseCustomUI:', Config.UseCustomUI)
            print('[gs_blackmarket] NUI ready:', nuiReady)
            print('[gs_blackmarket] Location:', location and location.id)
            print('[gs_blackmarket] Items count:', Config.Items and #Config.Items or 0)

            isUiOpen =
                true
            nuiOpenAck =
                false

            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
            print('[gs_blackmarket] NUI open sent without focus; waiting for uiOpened')

            QBCore.Functions.TriggerCallback('gs_blackmarket:server:getDealerData', function(data)
                if not data then
                    print('[gs_blackmarket] Dealer data callback failed; falling back to qb-menu')
                    OpenBlackMarketFallback(location)
                    return
                end

                SendNUIMessage({
                    action = 'open',
                    title = (Config.UI and Config.UI.title) or 'Black Market',
                    subtitle = (Config.UI and Config.UI.subtitle) or 'No refunds. No questions.',
                    flavor = (Config.UI and Config.UI.flavor) or 'Cash only. No names.',
                    locationId = location.id,
                    items = data.items or {},
                    restockRemaining = data.restockRemaining or 0,
                    assetPath = (Config.UI and Config.UI.assetPath) or 'assets/',
                    maxQuantity = (Config.UI and Config.UI.maxQuantity) or 10,
                })

                print('[gs_blackmarket] SendNUIMessage open sent')
            end, location.id)
        end)

    if not ok then
        print(('[gs_blackmarket] NUI open error: %s'):format(errorMessage))
        isUiOpen =
            false
        OpenBlackMarketFallback(location)
        return
    end

    CreateThread(function()
        Wait(1500)

        if isUiOpen
        and not nuiOpenAck then
            print('[gs_blackmarket] NUI did not confirm open; falling back to qb-menu')
            OpenBlackMarketFallback(location)
        end
    end)
end

local OpenDealerDoorMenu

local function KnockAtLocation(location)
    if isInteracting then
        return
    end

    isInteracting =
        true

    CreateThread(function()
        local ped =
            PlayerPedId()
        local success, errorMessage =
            pcall(function()
                if not ped
                or ped == 0 then
                    return
                end

                SetEntityHeading(ped, location.heading or GetEntityHeading(ped))
                Notify('You knock on the door...', 'primary')

                local animation =
                    Config.KnockAnimation

                if animation
                and animation.anim
                and LoadAnimDict(animation.dict) then
                    TaskPlayAnim(
                        ped,
                        animation.dict,
                        animation.anim,
                        8.0,
                        -8.0,
                        animation.duration or 1800,
                        animation.flag or 49,
                        0,
                        false,
                        false,
                        false
                    )

                    Wait(animation.duration or 1800)
                else
                    Wait(Config.KnockDelay or 1500)
                end

                ClearPedTasks(ped)
                FreezeEntityPosition(ped, false)

                Wait(250)

                Notify('A voice behind the door says: "No names. No problems. What you need?"', 'primary')

                Wait(400)

                OpenDealerDoorMenu(location)
            end)

        if not success then
            print(('[gs_blackmarket] Knock flow error: %s'):format(errorMessage))
            Notify('Something went wrong at the door.', 'error')
            OpenBlackMarketFallback(location)
        end

        CleanupKnockState(ped)
    end)
end

local function OpenPickupOrder(location, orders)
    local order =
        orders
        and orders[1]
        or nil

    if not order then
        Notify('You have no pending orders.', 'error')
        return
    end

    TriggerServerEvent('gs_blackmarket:server:pickupPhoneOrder', order.id, location.id)
end

function OpenDealerDoorMenu(location)
    QBCore.Functions.TriggerCallback('gs_blackmarket:server:getPendingOrders', function(orders)
        orders =
            orders or {}

        if #orders < 1 then
            OpenBlackMarketUI(location)
            return
        end

        local opened =
            pcall(function()
                exports['qb-menu']:openMenu({
                    {
                        header = 'Black Market',
                        txt = 'The voice waits behind the door.',
                        isMenuHeader = true,
                    },
                    {
                        header = 'Open Shop',
                        txt = 'Browse the dealer inventory.',
                        params = {
                            event = 'gs_blackmarket:client:openShopFromDoor',
                            args = {
                                locationId = location.id,
                            },
                        },
                    },
                    {
                        header = 'Pick Up Order',
                        txt = ('%s pending order%s'):format(#orders, #orders == 1 and '' or 's'),
                        params = {
                            event = 'gs_blackmarket:client:pickupOrderFromDoor',
                            args = {
                                locationId = location.id,
                            },
                        },
                    },
                })
            end)

        if not opened then
            OpenBlackMarketUI(location)
        end
    end, location.id)
end

local function RequestKnock(location)
    if isInteracting
    or not location
    or not location.id then
        return
    end

    local now =
        GetGameTimer()
    local nextAllowed =
        knockRequestCooldowns[location.id] or 0

    if now < nextAllowed then
        return
    end

    knockRequestCooldowns[location.id] =
        now + 1000

    TriggerServerEvent('gs_blackmarket:server:knock', location.id)
end

RegisterCommand('bm_unfreeze', function()
    local ped =
        PlayerPedId()

    if ped
    and ped ~= 0 then
        ClearPedTasksImmediately(ped)
        FreezeEntityPosition(ped, false)
    end

    isInteracting =
        false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'close',
    })
    SendNUIMessage({
        action = 'shadowmarketClose',
    })

    isUiOpen =
        false
    nuiOpenAck =
        false
    isShadowMarketOpen =
        false

    Notify('Black market state reset.', 'success')
    print('[gs_blackmarket] /bm_unfreeze executed')
end, false)

RegisterCommand('bm_testui', function()
    local location =
        Config.BlackMarketLocations
        and Config.BlackMarketLocations[1]
        or nil

    if not location then
        Notify('No black market location configured.', 'error')
        return
    end

    print('[gs_blackmarket] /bm_testui executed - attempting custom NUI')
    bmTestUiActive =
        true

    OpenBlackMarketUI(location)
end, false)

RegisterCommand('bm_forcenui', function()
    print('[gs_blackmarket] /bm_forcenui executed - opening NUI without focus first')

    isUiOpen =
        false
    nuiOpenAck =
        false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = 'open',
        title = 'Black Market',
        subtitle = 'No refunds. No questions.',
        locationId = 'house_dealer_01',
        items = Config.Items or {},
        assetPath = 'assets/',
        maxQuantity = 10,
    })

    CreateThread(function()
        Wait(1500)

        if nuiOpenAck then
            print('[gs_blackmarket] /bm_forcenui NUI opened successfully; focus can be enabled manually with /bm_focus')
        else
            print('[gs_blackmarket] /bm_forcenui NUI did not confirm open; focus was not enabled')
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
        end
    end)
end, false)

RegisterCommand('bm_focus', function()
    print('[gs_blackmarket] /bm_focus executed')
    SetNuiFocus(true, true)
end, false)

RegisterCommand('bm_closeui', function()
    print('[gs_blackmarket] /bm_closeui executed')

    isUiOpen =
        false
    nuiOpenAck =
        false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = 'close',
    })

    Notify('Black market UI closed.', 'primary')
end, false)

RegisterCommand('bm_pingui', function()
    print('[gs_blackmarket] /bm_pingui executed')

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = 'ping',
    })
end, false)

RegisterCommand('bm_nuistate', function()
    print(('[gs_blackmarket] nuiReady=%s nuiOpenAck=%s'):format(tostring(nuiReady), tostring(nuiOpenAck)))
    Notify(('NUI Ready: %s | Open Ack: %s'):format(tostring(nuiReady), tostring(nuiOpenAck)), 'primary')
end, false)

RegisterCommand('bm_locations', function()
    QBCore.Functions.TriggerCallback('gs_blackmarket:server:getActiveLocations', function(data)
        activeLocations =
            data or {}

        print('[gs_blackmarket] Active locations refreshed:')

        for id, active in pairs(activeLocations) do
            print(id, active)
        end

        QBCore.Functions.Notify('Black market active locations refreshed.', 'primary')
    end)
end, false)

RegisterCommand('shadowmarket', function()
    print('[gs_blackmarket] /shadowmarket executed')
    OpenShadowMarketPhone()
end, false)

RegisterCommand('shadowmarket_close', function()
    print('[gs_blackmarket] /shadowmarket_close executed')
    CloseShadowMarketUI()
end, false)

RegisterNetEvent('gs_blackmarket:client:selectItem', function(data)
    if type(data) ~= 'table' then
        return
    end

    TriggerServerEvent(
        'gs_blackmarket:server:buyItem',
        data.locationId,
        data.itemIndex
    )
end)

RegisterNetEvent('gs_blackmarket:client:knockApproved', function(locationId)
    local location =
        GetLocationById(locationId)

    if not location then
        Notify('Black market location error.', 'error')
        return
    end

    KnockAtLocation(location)
end)

RegisterNetEvent('gs_blackmarket:client:openShopFromDoor', function(data)
    local location =
        GetLocationById(data and data.locationId)

    if not location then
        Notify('Black market location error.', 'error')
        return
    end

    OpenBlackMarketUI(location)
end)

RegisterNetEvent('gs_blackmarket:client:pickupOrderFromDoor', function(data)
    local location =
        GetLocationById(data and data.locationId)

    if not location then
        Notify('Black market location error.', 'error')
        return
    end

    QBCore.Functions.TriggerCallback('gs_blackmarket:server:getPendingOrders', function(orders)
        OpenPickupOrder(location, orders or {})
    end, location.id)
end)

RegisterNetEvent('gs_blackmarket:client:refreshActiveLocations', function()
    RefreshActiveLocations()
end)

RegisterNetEvent('gs_blackmarket:client:openShadowMarketPhone', function()
    OpenShadowMarketPhone()
end)

RegisterNUICallback('close', function(_, cb)
    CloseBlackMarketUI()
    cb({
        ok = true,
    })
end)

RegisterNUICallback('uiReady', function(_, cb)
    nuiReady =
        true

    print('[gs_blackmarket] NUI reported ready')

    cb({
        ok = true,
    })
end)

RegisterNUICallback('uiOpened', function(_, cb)
    nuiOpenAck =
        true
    bmTestUiActive =
        false

    print('[gs_blackmarket] NUI reported opened')

    if isUiOpen then
        SetNuiFocus(true, true)
        print('[gs_blackmarket] NUI focus set after open confirmation')
    end

    cb({
        ok = true,
    })
end)

RegisterNUICallback('purchase', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent(
            'gs_blackmarket:server:buyCart',
            data.locationId,
            data.cart
        )
    end

    cb({
        ok = true,
    })
end)

RegisterNUICallback('shadowMarketOpened', function(_, cb)
    isShadowMarketOpen =
        true
    SetNuiFocus(true, true)

    cb({
        ok = true,
    })
end)

RegisterNUICallback('shadowMarketClose', function(_, cb)
    CloseShadowMarketUI()

    cb({
        ok = true,
    })
end)

RegisterNUICallback('shadowMarketUnlock', function(data, cb)
    QBCore.Functions.TriggerCallback('gs_blackmarket:server:unlockShadowMarket', function(result)
        cb(result or {
            ok = false,
            message = 'Nothing happens.',
        })
    end, data and data.code or '')
end)

RegisterNUICallback('shadowMarketWipe', function(_, cb)
    QBCore.Functions.TriggerCallback('gs_blackmarket:server:wipeShadowMarket', function(result)
        cb(result or {
            ok = true,
            message = 'App data wiped.',
        })
    end)
end)

RegisterNUICallback('shadowMarketGetData', function(_, cb)
    QBCore.Functions.TriggerCallback('gs_blackmarket:server:getShadowMarketData', function(result)
        cb(result or {
            items = {},
            pendingOrders = {},
        })
    end)
end)

RegisterNUICallback('shadowMarketPlaceOrder', function(data, cb)
    QBCore.Functions.TriggerCallback('gs_blackmarket:server:placePhoneOrder', function(result)
        cb(result or {
            ok = false,
            message = 'Order could not be placed.',
        })
    end, data and data.cart or {})
end)

RegisterNUICallback('shadowMarketAcceptVehicleOffer', function(data, cb)
    QBCore.Functions.TriggerCallback('gs_blackmarket:server:acceptVehicleOffer', function(result)
        cb(result or {
            ok = false,
            message = 'Vehicle offer could not be accepted.',
        })
    end, data and data.offerId or nil)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    local ped =
        PlayerPedId()

    if ped
    and ped ~= 0 then
        ClearPedTasksImmediately(ped)
        FreezeEntityPosition(ped, false)
    end

    isInteracting =
        false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'close',
    })
    SendNUIMessage({
        action = 'shadowmarketClose',
    })

    isUiOpen =
        false
    isShadowMarketOpen =
        false
end)

CreateThread(function()
    Wait(2000)
    RefreshActiveLocations()

    while true do
        Wait(60000)
        RefreshActiveLocations()
    end
end)

CreateThread(function()
    if not Config
    or Config.Enabled == false then
        return
    end

    while true do
        local sleep =
            1000
        local ped =
            PlayerPedId()
        local playerCoords =
            GetEntityCoords(ped)

        for _, location in ipairs(Config.BlackMarketLocations or {}) do
            if IsClientLocationActive(location) then
                local distance =
                    #(playerCoords - location.coords)

                if distance <= (Config.PromptDrawDistance or 12.0) then
                    sleep =
                        0

                    if distance <= (location.knockDistance or 2.0) then
                        DrawText3D(location.coords, 'Press [E] to knock')

                        if IsControlJustReleased(0, 38) then
                            RequestKnock(location)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
