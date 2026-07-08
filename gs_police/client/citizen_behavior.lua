local QBCore =
    exports["qb-core"]:GetCoreObject()

print("[gs_police] client/citizen_behavior.lua loaded")

local CitizenCooldowns = {}

local function DebugCitizen(...)
    if Config
    and Config.CitizenBehavior
    and Config.CitizenBehavior.debug then
        print("[gs_police:citizen_behavior]", ...)
    end
end

local function GetWeatherModifier(exportName, fallback)
    local resourceName = (Config.WeatherIntegration and Config.WeatherIntegration.ResourceName) or 'gs_world'

    if not Config.WeatherIntegration or not Config.WeatherIntegration.Enabled then
        return fallback
    end

    if GetResourceState(resourceName) ~= 'started' then
        return fallback
    end

    local ok, result = pcall(function()
        return exports[resourceName][exportName]()
    end)

    if not ok or result == nil then
        return fallback
    end

    return result
end

local function ShouldWeatherAllowCitizenReport()
    if not Config.WeatherIntegration or Config.WeatherIntegration.WitnessEnabled == false then
        return true
    end

    local witnessModifier = tonumber(GetWeatherModifier('GetWitnessModifier', 1.0)) or 1.0
    local chance = math.max(0.0, math.min(1.0, witnessModifier))

    if math.random() <= chance then
        return true
    end

    if Config.WeatherIntegration.Debug then
        print(('[gs_police:weather] citizen report suppressed modifier=%s'):format(tostring(witnessModifier)))
    end

    return false
end

local function CanRunCitizenEvent(key, seconds)
    local now =
        GetGameTimer()
    local last =
        CitizenCooldowns[key] or 0

    if now - last < ((seconds or 10) * 1000) then
        return false
    end

    CitizenCooldowns[key] =
        now

    return true
end

local function RollCitizenReaction(profileKey)
    local cfg =
        Config.CitizenBehavior or {}
    local chances =
        cfg.reactionChance or {}
    local profile =
        chances[profileKey or cfg.defaultProfile or "normal"]
        or chances.normal
        or {}
    local roll =
        math.random(1, 100)
    local cursor =
        0

    cursor =
        cursor + (profile.comply or 0)
    if roll <= cursor then
        return "comply", roll
    end

    cursor =
        cursor + (profile.flee or 0)
    if roll <= cursor then
        return "flee", roll
    end

    cursor =
        cursor + (profile.freeze or 0)
    if roll <= cursor then
        return "freeze", roll
    end

    cursor =
        cursor + (profile.fight or 0)
    if roll <= cursor then
        return "fight", roll
    end

    return "armedDefense", roll
end

local function GiveCitizenDefenseWeapon(ped)
    local armedDefense =
        Config.CitizenBehavior
        and Config.CitizenBehavior.armedDefense

    if not armedDefense
    or armedDefense.enabled == false then
        return
    end

    local weapons =
        armedDefense.weaponModels or { "WEAPON_PISTOL" }
    local weaponName =
        weapons[math.random(1, #weapons)]
    local weaponHash =
        joaat(weaponName)

    GiveWeaponToPed(ped, weaponHash, 24, false, true)
    SetCurrentPedWeapon(ped, weaponHash, true)
end

local function ApplyCitizenReaction(ped, reaction, sourcePed)
    if not ped
    or not DoesEntityExist(ped) then
        return
    end

    sourcePed =
        sourcePed or PlayerPedId()

    SetBlockingOfNonTemporaryEvents(ped, false)

    if reaction == "comply" then
        ClearPedTasks(ped)
        TaskHandsUp(ped, 15000, sourcePed, -1, true)
    elseif reaction == "flee" then
        TaskSmartFleePed(ped, sourcePed, 100.0, -1, false, false)
    elseif reaction == "freeze" then
        ClearPedTasks(ped)
        TaskStandStill(ped, 8000)
    elseif reaction == "fight" then
        TaskCombatPed(ped, sourcePed, 0, 16)
    elseif reaction == "armedDefense" then
        GiveCitizenDefenseWeapon(ped)
        TaskCombatPed(ped, sourcePed, 0, 16)
    end
end

CreateThread(function()
    while true do
        Wait(Config.CitizenBehavior and Config.CitizenBehavior.scanIntervalMs or 750)

        local cfg =
            Config.CitizenBehavior

        if cfg
        and cfg.enabled ~= false then
            local playerPed =
                PlayerPedId()

            if DoesEntityExist(playerPed)
            and not IsPedDeadOrDying(playerPed, true)
            and IsPedArmed(playerPed, 4) then
                local playerCoords =
                    GetEntityCoords(playerPed)
                local peds =
                    GetGamePool("CPed")

                for _, ped in ipairs(peds) do
                    if DoesEntityExist(ped)
                    and not IsPedAPlayer(ped)
                    and not IsPedDeadOrDying(ped, true) then
                        local pedCoords =
                            GetEntityCoords(ped)
                        local distance =
                            #(playerCoords - pedCoords)

                        if distance <= (cfg.robberyThreatDistance or 12.0) then
                            local key =
                                ("threat:%s"):format(ped)

                            if CanRunCitizenEvent(key, cfg.cooldowns and cfg.cooldowns.weaponThreatSeconds or 10) then
                                local reaction =
                                    RollCitizenReaction(cfg.defaultProfile)

                                ApplyCitizenReaction(ped, reaction, playerPed)

                                if ShouldWeatherAllowCitizenReport() then
                                    TriggerServerEvent("gs_police:server:citizenBehaviorReport", {
                                        behavior = "citizen_threatened",
                                        reaction = reaction,
                                        coords = {
                                            x = pedCoords.x,
                                            y = pedCoords.y,
                                            z = pedCoords.z
                                        },
                                        metadata = {
                                            source = "weapon_threat",
                                            player = GetPlayerServerId(PlayerId())
                                        }
                                    })
                                end

                                DebugCitizen("citizen threatened", ped, reaction)
                            end
                        end
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(250)

        local cfg =
            Config.CitizenBehavior

        if cfg
        and cfg.enabled ~= false
        and IsPedShooting(PlayerPedId())
        and CanRunCitizenEvent("shots_fired_global", cfg.cooldowns and cfg.cooldowns.shotsFiredSeconds or 20) then
            local playerPed =
                PlayerPedId()
            local playerCoords =
                GetEntityCoords(playerPed)
            local peds =
                GetGamePool("CPed")

            for _, ped in ipairs(peds) do
                if DoesEntityExist(ped)
                and not IsPedAPlayer(ped)
                and not IsPedDeadOrDying(ped, true) then
                    local pedCoords =
                        GetEntityCoords(ped)

                    if #(playerCoords - pedCoords) <= (cfg.shotsRadius or 75.0) then
                        TaskSmartFleePed(ped, playerPed, 150.0, -1, false, false)
                    end
                end
            end

            if ShouldWeatherAllowCitizenReport() then
                TriggerServerEvent("gs_police:server:citizenBehaviorReport", {
                    behavior = "shots_fired",
                    reaction = "panic",
                    coords = {
                        x = playerCoords.x,
                        y = playerCoords.y,
                        z = playerCoords.z
                    },
                    metadata = {
                        source = "shots_fired",
                        player = GetPlayerServerId(PlayerId())
                    }
                })
            end

            DebugCitizen("shots fired panic/report")
        end
    end
end)

RegisterCommand("police_citizendebug", function()
    QBCore.Functions.Notify("Citizen behavior module active.", "primary")
    print("[gs_police:citizen_behavior] module active")
end, false)
