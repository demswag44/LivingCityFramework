local QBCore = exports['qb-core']:GetCoreObject()

local Config = {}

Config.Blip = {
    coords = vector3(1149.2612, -780.6829, 56.9040),
    name = "RedLine AI Mechanic",
    sprite = 446,
    color = 1,
    scale = 0.85
}

Config.ServiceBays = {
    {
        id = 1,
        label = "Service Bay 1",
        coords = vector3(1140.4211, -785.0733, 56.9852),
        heading = 359.7885
    },
    {
        id = 2,
        label = "Service Bay 2",
        coords = vector3(1131.5096, -785.0923, 56.9827),
        heading = 352.4185
    },
    {
        id = 3,
        label = "Service Bay 3",
        coords = vector3(1122.8546, -784.9346, 56.9843),
        heading = 0.2755
    }
}

Config.DrawDistance = 35.0
Config.UseDistance = 3.0

local CurrentVehicle = nil
local CurrentBay = nil
local PreviewCam = nil
local PreviewCameraMode = "rear"
local FrozenVehicle = nil
local RedLineState = {
    wheelSize = 50,
    wheelWidth = 50,
    neonIntensity = 50,
    windowTint = 0,
    neonColor = { r = 255, g = 0, b = 0 },
    windowTintColor = { r = 0, g = 0, b = 0 }
}

local WheelCategories = {
    { label = "Sport", type = 0 },
    { label = "Muscle", type = 1 },
    { label = "Lowrider", type = 2 },
    { label = "SUV", type = 3 },
    { label = "Offroad", type = 4 },
    { label = "Tuner", type = 5 },
    { label = "High End", type = 7 },
    { label = "Benny's Original", type = 8 },
    { label = "Benny's Bespoke", type = 9 },
    { label = "Open Wheel", type = 10 },
    { label = "Street", type = 11 },
    { label = "Track", type = 12 }
}

local PaintColors = {
    { label = "Black", id = 0 },
    { label = "Graphite", id = 1 },
    { label = "Silver", id = 4 },
    { label = "White", id = 111 },
    { label = "Red", id = 27 },
    { label = "Torino Red", id = 28 },
    { label = "Orange", id = 38 },
    { label = "Race Yellow", id = 89 },
    { label = "Dark Green", id = 49 },
    { label = "Lime Green", id = 92 },
    { label = "Blue", id = 64 },
    { label = "Ultra Blue", id = 70 },
    { label = "Purple", id = 71 },
    { label = "Hot Pink", id = 135 }
}

local PerformanceMods = {
    { label = "Engine", slot = 11 },
    { label = "Brakes", slot = 12 },
    { label = "Transmission", slot = 13 },
    { label = "Suspension", slot = 15 },
    { label = "Armor", slot = 16 }
}

local BodyMods = {
    { label = "Spoilers", slot = 0 },
    { label = "Front Bumper", slot = 1 },
    { label = "Rear Bumper", slot = 2 },
    { label = "Side Skirt", slot = 3 },
    { label = "Exhaust", slot = 4 },
    { label = "Frame", slot = 5 },
    { label = "Grille", slot = 6 },
    { label = "Hood", slot = 7 },
    { label = "Fender", slot = 8 },
    { label = "Right Fender", slot = 9 },
    { label = "Roof", slot = 10 }
}

local PlateStyles = {
    { label = "Blue / White 1", id = 0 },
    { label = "Blue / White 2", id = 1 },
    { label = "Blue / White 3", id = 2 },
    { label = "Yellow / Black", id = 3 },
    { label = "Yellow / Blue", id = 4 },
    { label = "North Yankton", id = 5 }
}

local HeadlightColors = {
    { label = "Stock / Default", id = -1 },
    { label = "White", id = 0 },
    { label = "Blue", id = 1 },
    { label = "Electric Blue", id = 2 },
    { label = "Mint Green", id = 3 },
    { label = "Lime Green", id = 4 },
    { label = "Yellow", id = 5 },
    { label = "Golden Shower", id = 6 },
    { label = "Orange", id = 7 },
    { label = "Red", id = 8 },
    { label = "Pony Pink", id = 9 },
    { label = "Hot Pink", id = 10 },
    { label = "Purple", id = 11 },
    { label = "Blacklight", id = 12 }
}

local NeonColors = {
    { label = "Pure White", r = 255, g = 255, b = 255 },
    { label = "Ice Blue", r = 120, g = 220, b = 255 },
    { label = "Electric Blue", r = 0, g = 80, b = 255 },
    { label = "Aqua", r = 0, g = 255, b = 200 },
    { label = "Mint", r = 80, g = 255, b = 170 },
    { label = "Lime", r = 120, g = 255, b = 0 },
    { label = "Yellow", r = 255, g = 230, b = 0 },
    { label = "Amber", r = 255, g = 170, b = 0 },
    { label = "Orange", r = 255, g = 90, b = 0 },
    { label = "Red", r = 255, g = 0, b = 0 },
    { label = "Hot Pink", r = 255, g = 0, b = 180 },
    { label = "Purple", r = 160, g = 0, b = 255 },
    { label = "Blacklight", r = 40, g = 0, b = 255 }
}

local WindowTintPresets = {
    { label = "None", id = 0 },
    { label = "Light Smoke", id = 3 },
    { label = "Dark Smoke", id = 2 },
    { label = "Pure Black", id = 1 },
    { label = "Limo", id = 5 },
    { label = "Green Tint", id = 6 }
}

local HornPresets = {
    { label = "Stock Horn", index = -1 },
    { label = "Truck Horn", index = 1 },
    { label = "Cop Horn", index = 2 },
    { label = "Clown Horn", index = 3 }
}

local function DrawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)

    SetTextScale(0.34, 0.34)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 0, 0, 235)
    SetTextCentre(true)
    SetTextOutline()

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)

    ClearDrawOrigin()
end

local function CreateRedLineBlip()
    local blip = AddBlipForCoord(Config.Blip.coords.x, Config.Blip.coords.y, Config.Blip.coords.z)

    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipDisplay(blip, 4)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Blip.name)
    EndTextCommandSetBlipName(blip)
end

local function DrawServiceBayIndicator(bay, isInVehicle, isClose)
    DrawMarker(
        27,
        bay.coords.x,
        bay.coords.y,
        bay.coords.z + 0.015,
        0.0, 0.0, 0.0,
        0.0, 0.0, bay.heading,
        1.35, 1.35, 0.05,
        255, 0, 0, 155,
        false,
        true,
        2,
        false,
        nil,
        nil,
        false
    )

    DrawMarker(
        2,
        bay.coords.x,
        bay.coords.y,
        bay.coords.z + 1.15,
        0.0, 0.0, 0.0,
        180.0, 0.0, bay.heading,
        0.35, 0.35, 0.35,
        255, 0, 0, 220,
        false,
        true,
        2,
        false,
        nil,
        nil,
        false
    )

    if isClose and isInVehicle then
        DrawText3D(
            bay.coords.x,
            bay.coords.y,
            bay.coords.z + 1.55,
            ("~r~%s~s~\n~w~Press ~r~[E]~w~ to customize vehicle"):format(bay.label)
        )
    else
        DrawText3D(
            bay.coords.x,
            bay.coords.y,
            bay.coords.z + 1.55,
            ("~r~%s~s~\n~r~Place vehicle here"):format(bay.label)
        )
    end
end

local function Notify(message, notifyType)
    QBCore.Functions.Notify(message, notifyType or "primary")
end

local function OpenMenu(menu)
    exports['qb-menu']:openMenu(menu)
end

local function AddBackAndClose(menu, backEvent, backArgs)
    menu[#menu + 1] = {
        header = "< Back",
        params = {
            event = backEvent or "gs_redline:client:openMainMenu",
            args = backArgs
        }
    }

    menu[#menu + 1] = {
        header = "Close",
        params = {
            event = "gs_redline:client:closeMenu"
        }
    }
end

local function GetMenuVehicle()
    local ped = PlayerPedId()

    if CurrentVehicle and CurrentVehicle ~= 0 and DoesEntityExist(CurrentVehicle) then
        if GetPedInVehicleSeat(CurrentVehicle, -1) == ped then
            return CurrentVehicle
        end

        Notify("You must stay in the driver seat to customize this vehicle.", "error")
        return nil
    end

    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
        CurrentVehicle = vehicle
        return vehicle
    end

    Notify("You must be the driver of a vehicle.", "error")
    return nil
end

local function PrepareVehicle(vehicle)
    SetVehicleModKit(vehicle, 0)
end

local function IsMotorcycle(vehicle)
    return GetVehicleClass(vehicle) == 8
end

local function ClampColor(value)
    value = math.floor(value + 0.5)

    if value < 0 then
        return 0
    end

    if value > 255 then
        return 255
    end

    return value
end

local function ClampPercent(value)
    value = tonumber(value) or 0

    if value < 0 then
        return 0
    end

    if value > 100 then
        return 100
    end

    return math.floor(value + 0.5)
end

local function PercentToRgb(value)
    return ClampColor((ClampPercent(value) / 100) * 255)
end

local function RgbToPercent(value)
    return ClampPercent(((tonumber(value) or 0) / 255) * 100)
end

local function GetWheelSizeNativeValue()
    return 0.75 + ((RedLineState.wheelSize / 100) * 0.65)
end

local function GetWheelWidthNativeValue()
    return 0.70 + ((RedLineState.wheelWidth / 100) * 0.70)
end

local function GetNeonIntensityMultiplier()
    return 0.15 + ((RedLineState.neonIntensity / 100) * 1.85)
end

local function GetWindowTintIndex(value)
    value = ClampPercent(value)

    if value <= 10 then
        return 0
    elseif value <= 25 then
        return 3
    elseif value <= 45 then
        return 2
    elseif value <= 70 then
        return 1
    end

    return 5
end

local function DestroyPreviewCamera()
    if PreviewCam then
        RenderScriptCams(false, true, 350, true, true)
        DestroyCam(PreviewCam, false)
        PreviewCam = nil
    else
        RenderScriptCams(false, true, 350, true, true)
    end

    if FrozenVehicle and DoesEntityExist(FrozenVehicle) then
        FreezeEntityPosition(FrozenVehicle, false)
    end

    FrozenVehicle = nil
end

local function SetPreviewCameraPosition(mode)
    local vehicle = GetMenuVehicle()

    if not vehicle then
        DestroyPreviewCamera()
        return
    end

    PreviewCameraMode = mode or PreviewCameraMode or "rear"

    local offsets = {
        front = vector3(0.0, -6.0, 2.2),
        rear = vector3(0.0, 6.0, 2.2),
        left = vector3(-5.2, 0.0, 2.0),
        right = vector3(5.2, 0.0, 2.0)
    }

    local offset = offsets[PreviewCameraMode] or offsets.rear
    local camCoords = GetOffsetFromEntityInWorldCoords(vehicle, offset.x, offset.y, offset.z)

    SetCamCoord(PreviewCam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtEntity(PreviewCam, vehicle, 0.0, 0.0, 0.5, true)
end

local function StartPreviewCamera(mode)
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    if FrozenVehicle and FrozenVehicle ~= vehicle and DoesEntityExist(FrozenVehicle) then
        FreezeEntityPosition(FrozenVehicle, false)
    end

    FrozenVehicle = vehicle
    FreezeEntityPosition(vehicle, true)

    if not PreviewCam then
        PreviewCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamActive(PreviewCam, true)
        RenderScriptCams(true, true, 350, true, true)
    end

    SetPreviewCameraPosition(mode or PreviewCameraMode)
end

local function EnableAllNeon(vehicle, enabled)
    for lightIndex = 0, 3 do
        SetVehicleNeonLightEnabled(vehicle, lightIndex, enabled)
    end
end

local function ApplyCurrentNeonColor(vehicle)
    local intensity = GetNeonIntensityMultiplier()
    local r = ClampColor(RedLineState.neonColor.r * intensity)
    local g = ClampColor(RedLineState.neonColor.g * intensity)
    local b = ClampColor(RedLineState.neonColor.b * intensity)

    EnableAllNeon(vehicle, true)
    SetVehicleNeonLightsColour(vehicle, r, g, b)
end

local function OpenSliderMenu(args)
    local value

    if args.colorKey then
        value = RgbToPercent(RedLineState[args.colorKey][args.channel])
    else
        value = RedLineState[args.stateKey]
    end

    local menu = {
        {
            header = args.title,
            txt = args.description,
            isMenuHeader = true
        },
        {
            header = "-10",
            params = {
                event = "gs_redline:client:adjustSliderValue",
                args = {
                    slider = args,
                    delta = -10
                }
            }
        },
        {
            header = "-1",
            params = {
                event = "gs_redline:client:adjustSliderValue",
                args = {
                    slider = args,
                    delta = -1
                }
            }
        },
        {
            header = ("%s: %s/100"):format(args.currentLabel or "Current Value", value),
            isMenuHeader = true
        },
        {
            header = "+1",
            params = {
                event = "gs_redline:client:adjustSliderValue",
                args = {
                    slider = args,
                    delta = 1
                }
            }
        },
        {
            header = "+10",
            params = {
                event = "gs_redline:client:adjustSliderValue",
                args = {
                    slider = args,
                    delta = 10
                }
            }
        },
        {
            header = "Apply",
            params = {
                event = args.applyEvent,
                args = args
            }
        }
    }

    AddBackAndClose(menu, args.backEvent, args.backArgs)
    OpenMenu(menu)
end

local function OpenWheelSizeSliderMenu()
    OpenSliderMenu({
        title = "RedLine Wheel Size",
        description = "0 = smallest, 50 = default, 100 = biggest",
        stateKey = "wheelSize",
        currentLabel = "Current Size",
        applyEvent = "gs_redline:client:applyWheelSize",
        backEvent = "gs_redline:client:openWheelSizeMenu"
    })
end

local function OpenWheelWidthSliderMenu()
    OpenSliderMenu({
        title = "RedLine Wheel Width",
        description = "0 = narrowest, 50 = default, 100 = widest",
        stateKey = "wheelWidth",
        currentLabel = "Current Width",
        applyEvent = "gs_redline:client:applyWheelWidth",
        backEvent = "gs_redline:client:openWheelSizeMenu"
    })
end

local function OpenNeonIntensitySliderMenu()
    OpenSliderMenu({
        title = "RedLine Neon Intensity",
        description = "Brightness is simulated by RGB intensity.",
        stateKey = "neonIntensity",
        currentLabel = "Current Intensity",
        applyEvent = "gs_redline:client:applyNeonIntensity",
        backEvent = "gs_redline:client:openLightsMenu"
    })
end

local function OpenWindowTintSliderMenu()
    OpenSliderMenu({
        title = "RedLine Window Tint",
        description = "0 = lightest, 100 = darkest. GTA maps this to preset tint indexes.",
        stateKey = "windowTint",
        currentLabel = "Current Tint",
        applyEvent = "gs_redline:client:applyWindowTint",
        backEvent = "gs_redline:client:openWindowTintMenu"
    })
end

local function GetRgbEditorTitle(target)
    if target == "windowTint" then
        return "Future Tint Color Preview"
    end

    return "Neon RGB Color"
end

local function GetRgbEditorStateKey(target)
    if target == "windowTint" then
        return "windowTintColor"
    end

    return "neonColor"
end

local function GetRgbEditorBackEvent(target)
    if target == "windowTint" then
        return "gs_redline:client:openWindowTintMenu"
    end

    return "gs_redline:client:openNeonColorMenu"
end

local function OpenRgbEditorMenu(args)
    local target = args and args.target or "neon"
    local colorKey = GetRgbEditorStateKey(target)
    local color = RedLineState[colorKey]
    local menu = {
        {
            header = "RedLine RGB Color",
            txt = ("%s: %s, %s, %s"):format(GetRgbEditorTitle(target), color.r, color.g, color.b),
            isMenuHeader = true
        },
        {
            header = ("Red Channel: %s/100"):format(RgbToPercent(color.r)),
            params = {
                event = "gs_redline:client:openRgbChannelSlider",
                args = {
                    target = target,
                    colorKey = colorKey,
                    channel = "r",
                    label = "Red Channel"
                }
            }
        },
        {
            header = ("Green Channel: %s/100"):format(RgbToPercent(color.g)),
            params = {
                event = "gs_redline:client:openRgbChannelSlider",
                args = {
                    target = target,
                    colorKey = colorKey,
                    channel = "g",
                    label = "Green Channel"
                }
            }
        },
        {
            header = ("Blue Channel: %s/100"):format(RgbToPercent(color.b)),
            params = {
                event = "gs_redline:client:openRgbChannelSlider",
                args = {
                    target = target,
                    colorKey = colorKey,
                    channel = "b",
                    label = "Blue Channel"
                }
            }
        },
        {
            header = "Preview / Apply",
            params = {
                event = "gs_redline:client:applyRgbEditor",
                args = {
                    target = target
                }
            }
        }
    }

    AddBackAndClose(menu, GetRgbEditorBackEvent(target))
    OpenMenu(menu)
end

local function OpenRgbChannelSlider(args)
    OpenSliderMenu({
        title = ("RedLine RGB Color - %s"):format(args.label),
        description = "0 = no channel color, 100 = full channel color",
        colorKey = args.colorKey,
        channel = args.channel,
        target = args.target,
        currentLabel = args.label,
        applyEvent = "gs_redline:client:applyRgbChannel",
        backEvent = "gs_redline:client:openRgbEditor",
        backArgs = {
            target = args.target
        }
    })
end

local function OpenMainMenu(args)
    if not args or not args.skipCamera then
        StartPreviewCamera(PreviewCameraMode)
    end

    OpenMenu({
        {
            header = "RedLine AI Mechanic",
            isMenuHeader = true
        },
        {
            header = "Camera: Front",
            params = {
                event = "gs_redline:client:setPreviewCamera",
                args = "front"
            }
        },
        {
            header = "Camera: Rear",
            params = {
                event = "gs_redline:client:setPreviewCamera",
                args = "rear"
            }
        },
        {
            header = "Camera: Left",
            params = {
                event = "gs_redline:client:setPreviewCamera",
                args = "left"
            }
        },
        {
            header = "Camera: Right",
            params = {
                event = "gs_redline:client:setPreviewCamera",
                args = "right"
            }
        },
        {
            header = "Camera: Reset / Off",
            params = {
                event = "gs_redline:client:previewCameraOff"
            }
        },
        {
            header = "Repair Vehicle",
            txt = "Fully repair the current vehicle",
            params = {
                event = "gs_redline:client:repairVehicle"
            }
        },
        {
            header = "Paint",
            txt = "Primary, secondary, pearlescent, and wheel colors",
            params = {
                event = "gs_redline:client:openPaintMenu"
            }
        },
        {
            header = "Wheels",
            txt = "Wheel categories and rims",
            params = {
                event = "gs_redline:client:openWheelsMenu"
            }
        },
        {
            header = "Wheel Size / Width",
            txt = "Adjust tire fitment where supported",
            params = {
                event = "gs_redline:client:openWheelSizeMenu"
            }
        },
        {
            header = "Performance",
            txt = "Engine, brakes, transmission, suspension, armor, turbo",
            params = {
                event = "gs_redline:client:openPerformanceMenu"
            }
        },
        {
            header = "Body Mods",
            txt = "Spoilers, bumpers, skirts, exhaust, hood, roof, and more",
            params = {
                event = "gs_redline:client:openBodyModsMenu"
            }
        },
        {
            header = "Lights / Neon",
            txt = "Headlights, neon palette, and neon intensity",
            params = {
                event = "gs_redline:client:openLightsMenu"
            }
        },
        {
            header = "Window Tint",
            txt = "0-100 tint darkness, presets, and future tint preview",
            params = {
                event = "gs_redline:client:openWindowTintMenu"
            }
        },
        {
            header = "Plate Style",
            txt = "Change number plate style",
            params = {
                event = "gs_redline:client:openPlateStyleMenu"
            }
        },
        {
            header = "Vehicle Extras",
            txt = "Toggle available vehicle extras",
            params = {
                event = "gs_redline:client:openExtrasMenu"
            }
        },
        {
            header = "Horn",
            txt = "Install and preview horn options",
            params = {
                event = "gs_redline:client:openHornMenu"
            }
        },
        {
            header = "Save Vehicle",
            txt = "Save vehicle properties for owned vehicles",
            params = {
                event = "gs_redline:client:saveVehicle"
            }
        },
        {
            header = "Close",
            params = {
                event = "gs_redline:client:closeMenu"
            }
        }
    })
end

local function OpenPaintMenu()
    local menu = {
        {
            header = "Paint",
            isMenuHeader = true
        },
        {
            header = "Primary Color",
            params = {
                event = "gs_redline:client:openPaintColorMenu",
                args = { target = "primary" }
            }
        },
        {
            header = "Secondary Color",
            params = {
                event = "gs_redline:client:openPaintColorMenu",
                args = { target = "secondary" }
            }
        },
        {
            header = "Pearlescent Color",
            params = {
                event = "gs_redline:client:openPaintColorMenu",
                args = { target = "pearlescent" }
            }
        },
        {
            header = "Wheel Color",
            params = {
                event = "gs_redline:client:openPaintColorMenu",
                args = { target = "wheel" }
            }
        }
    }

    AddBackAndClose(menu, "gs_redline:client:openMainMenu")
    OpenMenu(menu)
end

local function OpenPaintColorMenu(args)
    local menu = {
        {
            header = "Select Color",
            isMenuHeader = true
        }
    }

    for _, color in ipairs(PaintColors) do
        menu[#menu + 1] = {
            header = color.label,
            txt = ("GTA color ID %s"):format(color.id),
            params = {
                event = "gs_redline:client:applyPaintColor",
                args = {
                    target = args.target,
                    color = color.id
                }
            }
        }
    end

    AddBackAndClose(menu, "gs_redline:client:openPaintMenu")
    OpenMenu(menu)
end

local function OpenWheelsMenu()
    local menu = {
        {
            header = "Wheels",
            isMenuHeader = true
        }
    }

    for _, category in ipairs(WheelCategories) do
        menu[#menu + 1] = {
            header = category.label,
            txt = ("Wheel type %s"):format(category.type),
            params = {
                event = "gs_redline:client:openWheelRims",
                args = {
                    label = category.label,
                    wheelType = category.type
                }
            }
        }
    end

    AddBackAndClose(menu, "gs_redline:client:openMainMenu")
    OpenMenu(menu)
end

local function OpenWheelRimsMenu(args)
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    PrepareVehicle(vehicle)
    SetVehicleWheelType(vehicle, args.wheelType)

    local slot = IsMotorcycle(vehicle) and 24 or 23
    local rimCount = GetNumVehicleMods(vehicle, slot)

    if rimCount <= 0 then
        Notify("No rims are available for this vehicle in that category.", "error")
        OpenWheelsMenu()
        return
    end

    local menu = {
        {
            header = args.label,
            txt = ("Available rims: %s"):format(rimCount),
            isMenuHeader = true
        }
    }

    for rimIndex = 0, rimCount - 1 do
        menu[#menu + 1] = {
            header = ("Rim %s"):format(rimIndex),
            params = {
                event = "gs_redline:client:applyWheelRim",
                args = {
                    label = args.label,
                    wheelType = args.wheelType,
                    rimIndex = rimIndex,
                    slot = slot
                }
            }
        }
    end

    AddBackAndClose(menu, "gs_redline:client:openWheelsMenu")
    OpenMenu(menu)
end

local function OpenWheelSizeMenu()
    local menu = {
        {
            header = "Wheel Size / Width",
            isMenuHeader = true
        },
        {
            header = ("Wheel Size: %s/100"):format(RedLineState.wheelSize),
            txt = "0 = smallest, 50 = default, 100 = biggest",
            params = {
                event = "gs_redline:client:openWheelSizeSlider"
            }
        }
    }

    menu[#menu + 1] = {
        header = ("Wheel Width: %s/100"):format(RedLineState.wheelWidth),
        txt = "0 = narrowest, 50 = default, 100 = widest",
        params = {
            event = "gs_redline:client:openWheelWidthSlider"
        }
    }

    AddBackAndClose(menu, "gs_redline:client:openMainMenu")
    OpenMenu(menu)
end

local function OpenModSlotMenu(args)
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    PrepareVehicle(vehicle)

    local modCount = GetNumVehicleMods(vehicle, args.slot)
    local menu = {
        {
            header = args.label,
            txt = ("Available options: %s"):format(modCount),
            isMenuHeader = true
        },
        {
            header = "Stock",
            params = {
                event = "gs_redline:client:applyVehicleMod",
                args = {
                    slot = args.slot,
                    modIndex = -1,
                    backEvent = args.backEvent
                }
            }
        }
    }

    for modIndex = 0, modCount - 1 do
        menu[#menu + 1] = {
            header = ("Option %s"):format(modIndex + 1),
            params = {
                event = "gs_redline:client:applyVehicleMod",
                args = {
                    slot = args.slot,
                    modIndex = modIndex,
                    backEvent = args.backEvent
                }
            }
        }
    end

    AddBackAndClose(menu, args.backEvent)
    OpenMenu(menu)
end

local function OpenPerformanceMenu()
    local menu = {
        {
            header = "Performance",
            isMenuHeader = true
        }
    }

    for _, mod in ipairs(PerformanceMods) do
        menu[#menu + 1] = {
            header = mod.label,
            params = {
                event = "gs_redline:client:openModSlotMenu",
                args = {
                    label = mod.label,
                    slot = mod.slot,
                    backEvent = "gs_redline:client:openPerformanceMenu"
                }
            }
        }
    end

    menu[#menu + 1] = {
        header = "Turbo",
        txt = "Toggle turbo tuning",
        params = {
            event = "gs_redline:client:toggleTurbo"
        }
    }

    AddBackAndClose(menu, "gs_redline:client:openMainMenu")
    OpenMenu(menu)
end

local function OpenBodyModsMenu()
    local menu = {
        {
            header = "Body Mods",
            isMenuHeader = true
        }
    }

    for _, mod in ipairs(BodyMods) do
        menu[#menu + 1] = {
            header = mod.label,
            params = {
                event = "gs_redline:client:openModSlotMenu",
                args = {
                    label = mod.label,
                    slot = mod.slot,
                    backEvent = "gs_redline:client:openBodyModsMenu"
                }
            }
        }
    end

    AddBackAndClose(menu, "gs_redline:client:openMainMenu")
    OpenMenu(menu)
end

local function OpenLightsMenu()
    local menu = {
        {
            header = "Lights / Neon",
            isMenuHeader = true
        },
        {
            header = "Xenon Headlights On / Off",
            params = {
                event = "gs_redline:client:toggleXenon"
            }
        },
        {
            header = "Headlight Color",
            params = {
                event = "gs_redline:client:openHeadlightColorMenu"
            }
        },
        {
            header = "Neon On",
            params = {
                event = "gs_redline:client:setNeonEnabled",
                args = true
            }
        },
        {
            header = "Neon Off",
            params = {
                event = "gs_redline:client:setNeonEnabled",
                args = false
            }
        },
        {
            header = "Neon Color Palette",
            params = {
                event = "gs_redline:client:openNeonColorMenu"
            }
        },
        {
            header = "Neon Brightness / Intensity",
            params = {
                event = "gs_redline:client:openNeonIntensityMenu"
            }
        }
    }

    AddBackAndClose(menu, "gs_redline:client:openMainMenu")
    OpenMenu(menu)
end

local function OpenHeadlightColorMenu()
    local menu = {
        {
            header = "Headlight Color",
            isMenuHeader = true
        }
    }

    for _, color in ipairs(HeadlightColors) do
        menu[#menu + 1] = {
            header = color.label,
            txt = ("Xenon color %s"):format(color.id),
            params = {
                event = "gs_redline:client:applyHeadlightColor",
                args = color.id
            }
        }
    end

    AddBackAndClose(menu, "gs_redline:client:openLightsMenu")
    OpenMenu(menu)
end

local function OpenNeonColorMenu()
    local menu = {
        {
            header = "Neon Color Palette",
            isMenuHeader = true
        }
    }

    for _, color in ipairs(NeonColors) do
        menu[#menu + 1] = {
            header = color.label,
            params = {
                event = "gs_redline:client:applyNeonColor",
                args = {
                    r = color.r,
                    g = color.g,
                    b = color.b
                }
            }
        }
    end

    AddBackAndClose(menu, "gs_redline:client:openLightsMenu")
    OpenMenu(menu)
end

local function OpenNeonIntensityMenu()
    OpenNeonIntensitySliderMenu()
end

local function OpenWindowTintMenu()
    local menu = {
        {
            header = "Window Tint",
            isMenuHeader = true
        },
        {
            header = ("Tint Darkness: %s/100"):format(RedLineState.windowTint),
            txt = "0 = no tint, 100 = darkest. GTA native uses preset tint indexes.",
            params = {
                event = "gs_redline:client:openWindowTintSlider"
            }
        },
        {
            header = "Window Tint Presets",
            txt = "Apply native GTA tint presets",
            params = {
                event = "gs_redline:client:openWindowTintPresets"
            }
        },
        {
            header = "Future Tint Color Preview",
            txt = ("Stored RGB: %s, %s, %s"):format(
                RedLineState.windowTintColor.r,
                RedLineState.windowTintColor.g,
                RedLineState.windowTintColor.b
            ),
            params = {
                event = "gs_redline:client:openRgbEditor",
                args = {
                    target = "windowTint"
                }
            }
        }
    }

    AddBackAndClose(menu, "gs_redline:client:openMainMenu")
    OpenMenu(menu)
end

local function OpenWindowTintPresetsMenu()
    local menu = {
        {
            header = "Window Tint Presets",
            isMenuHeader = true
        }
    }

    for _, tint in ipairs(WindowTintPresets) do
        menu[#menu + 1] = {
            header = tint.label,
            params = {
                event = "gs_redline:client:applyWindowTintPreset",
                args = tint.id
            }
        }
    end

    AddBackAndClose(menu, "gs_redline:client:openTintMenu")
    OpenMenu(menu)
end

local function OpenHornMenu()
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    PrepareVehicle(vehicle)

    local hornCount = GetNumVehicleMods(vehicle, 14)
    local menu = {
        {
            header = "Horn",
            txt = ("Available horn mods: %s"):format(hornCount),
            isMenuHeader = true
        },
        {
            header = "Preview Horn",
            params = {
                event = "gs_redline:client:previewHorn"
            }
        }
    }

    for _, horn in ipairs(HornPresets) do
        menu[#menu + 1] = {
            header = horn.label,
            params = {
                event = "gs_redline:client:applyHorn",
                args = horn.index
            }
        }
    end

    if hornCount > 0 then
        menu[#menu + 1] = {
            header = "Musical Horns",
            isMenuHeader = true
        }

        for hornIndex = 0, hornCount - 1 do
            menu[#menu + 1] = {
                header = ("Horn %s"):format(hornIndex),
                params = {
                    event = "gs_redline:client:applyHorn",
                    args = hornIndex
                }
            }
        end
    end

    AddBackAndClose(menu, "gs_redline:client:openMainMenu")
    OpenMenu(menu)
end

local function OpenPlateStyleMenu()
    local menu = {
        {
            header = "Plate Style",
            isMenuHeader = true
        }
    }

    for _, plate in ipairs(PlateStyles) do
        menu[#menu + 1] = {
            header = plate.label,
            params = {
                event = "gs_redline:client:applyPlateStyle",
                args = plate.id
            }
        }
    end

    AddBackAndClose(menu, "gs_redline:client:openMainMenu")
    OpenMenu(menu)
end

local function OpenExtrasMenu()
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    local menu = {
        {
            header = "Vehicle Extras",
            isMenuHeader = true
        }
    }

    local foundExtra = false

    for extraId = 0, 20 do
        if DoesExtraExist(vehicle, extraId) then
            foundExtra = true

            local isEnabled = IsVehicleExtraTurnedOn(vehicle, extraId)
            menu[#menu + 1] = {
                header = ("Extra %s"):format(extraId),
                txt = isEnabled and "Enabled" or "Disabled",
                params = {
                    event = "gs_redline:client:toggleExtra",
                    args = extraId
                }
            }
        end
    end

    if not foundExtra then
        menu[#menu + 1] = {
            header = "No extras available",
            isMenuHeader = true
        }
    end

    AddBackAndClose(menu, "gs_redline:client:openMainMenu")
    OpenMenu(menu)
end

local function OpenCustomsMenu(vehicle, bay)
    if not vehicle or vehicle == 0 then
        Notify("You must be inside a vehicle.", "error")
        return
    end

    if GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then
        Notify("You must be the driver to customize this vehicle.", "error")
        return
    end

    CurrentVehicle = vehicle
    CurrentBay = bay

    SetVehicleOnGroundProperly(vehicle)
    SetEntityHeading(vehicle, bay.heading)
    PrepareVehicle(vehicle)

    OpenMainMenu()
end

RegisterNetEvent("gs_redline:client:openMainMenu", OpenMainMenu)
RegisterNetEvent("gs_redline:client:openPaintMenu", OpenPaintMenu)
RegisterNetEvent("gs_redline:client:openPaintColorMenu", OpenPaintColorMenu)
RegisterNetEvent("gs_redline:client:openWheelsMenu", OpenWheelsMenu)
RegisterNetEvent("gs_redline:client:openWheelRims", OpenWheelRimsMenu)
RegisterNetEvent("gs_redline:client:openWheelSizeMenu", OpenWheelSizeMenu)
RegisterNetEvent("gs_redline:client:openWheelSizeSlider", OpenWheelSizeSliderMenu)
RegisterNetEvent("gs_redline:client:openWheelWidthSlider", OpenWheelWidthSliderMenu)
RegisterNetEvent("gs_redline:client:openPerformanceMenu", OpenPerformanceMenu)
RegisterNetEvent("gs_redline:client:openModSlotMenu", OpenModSlotMenu)
RegisterNetEvent("gs_redline:client:openBodyModsMenu", OpenBodyModsMenu)
RegisterNetEvent("gs_redline:client:openLightsMenu", OpenLightsMenu)
RegisterNetEvent("gs_redline:client:openHeadlightColorMenu", OpenHeadlightColorMenu)
RegisterNetEvent("gs_redline:client:openNeonColorMenu", OpenNeonColorMenu)
RegisterNetEvent("gs_redline:client:openNeonIntensityMenu", OpenNeonIntensityMenu)
RegisterNetEvent("gs_redline:client:openNeonIntensitySlider", OpenNeonIntensitySliderMenu)
RegisterNetEvent("gs_redline:client:openWindowTintMenu", OpenWindowTintMenu)
RegisterNetEvent("gs_redline:client:openTintMenu", OpenWindowTintMenu)
RegisterNetEvent("gs_redline:client:openWindowTintSlider", OpenWindowTintSliderMenu)
RegisterNetEvent("gs_redline:client:openWindowTintPresets", OpenWindowTintPresetsMenu)
RegisterNetEvent("gs_redline:client:openPlateStyleMenu", OpenPlateStyleMenu)
RegisterNetEvent("gs_redline:client:openExtrasMenu", OpenExtrasMenu)
RegisterNetEvent("gs_redline:client:openHornMenu", OpenHornMenu)
RegisterNetEvent("gs_redline:client:openRgbEditor", OpenRgbEditorMenu)
RegisterNetEvent("gs_redline:client:openRgbChannelSlider", OpenRgbChannelSlider)

RegisterNetEvent("gs_redline:client:adjustSliderValue", function(args)
    local slider = args.slider
    local delta = args.delta or 0

    if slider.colorKey then
        local currentValue = RgbToPercent(RedLineState[slider.colorKey][slider.channel])
        RedLineState[slider.colorKey][slider.channel] = PercentToRgb(currentValue + delta)
    else
        RedLineState[slider.stateKey] = ClampPercent((RedLineState[slider.stateKey] or 0) + delta)
    end

    OpenSliderMenu(slider)
end)

RegisterNetEvent("gs_redline:client:setPreviewCamera", function(mode)
    StartPreviewCamera(mode)
    OpenMainMenu({ skipCamera = true })
end)

RegisterNetEvent("gs_redline:client:previewCameraOff", function()
    DestroyPreviewCamera()
    Notify("Preview camera disabled.", "primary")
    OpenMainMenu({ skipCamera = true })
end)

RegisterNetEvent("gs_redline:client:repairVehicle", function()
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    Notify("Vehicle repaired.", "success")
    OpenMainMenu()
end)

RegisterNetEvent("gs_redline:client:applyPaintColor", function(args)
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    local primary, secondary = GetVehicleColours(vehicle)
    local pearlescent, wheelColor = GetVehicleExtraColours(vehicle)

    if args.target == "primary" then
        SetVehicleColours(vehicle, args.color, secondary)
    elseif args.target == "secondary" then
        SetVehicleColours(vehicle, primary, args.color)
    elseif args.target == "pearlescent" then
        SetVehicleExtraColours(vehicle, args.color, wheelColor)
    elseif args.target == "wheel" then
        SetVehicleExtraColours(vehicle, pearlescent, args.color)
    end

    Notify("Paint updated.", "success")
    OpenPaintMenu()
end)

RegisterNetEvent("gs_redline:client:applyWheelRim", function(args)
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    PrepareVehicle(vehicle)
    SetVehicleWheelType(vehicle, args.wheelType)
    SetVehicleMod(vehicle, args.slot, args.rimIndex, false)

    if IsMotorcycle(vehicle) and args.slot == 24 then
        SetVehicleMod(vehicle, 23, args.rimIndex, false)
    end

    Notify("Rims applied.", "success")
    OpenWheelRimsMenu(args)
end)

RegisterNetEvent("gs_redline:client:applyWheelSize", function()
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    local nativeSize = GetWheelSizeNativeValue()
    local ok = pcall(function()
        SetVehicleWheelSize(vehicle, nativeSize)
    end)

    if ok then
        Notify(("Wheel size applied: %s/100"):format(RedLineState.wheelSize), "success")
    else
        Notify("Wheel size is not supported on this server artifact.", "error")
    end

    OpenWheelSizeSliderMenu()
end)

RegisterNetEvent("gs_redline:client:applyWheelWidth", function()
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    local nativeWidth = GetWheelWidthNativeValue()
    local ok = pcall(function()
        SetVehicleWheelWidth(vehicle, nativeWidth)
    end)

    if ok then
        Notify(("Wheel width applied: %s/100"):format(RedLineState.wheelWidth), "success")
    else
        Notify("Wheel width is not supported on this server artifact.", "error")
    end

    OpenWheelWidthSliderMenu()
end)

RegisterNetEvent("gs_redline:client:applyVehicleMod", function(args)
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    PrepareVehicle(vehicle)
    SetVehicleMod(vehicle, args.slot, args.modIndex, false)
    Notify("Modification applied.", "success")

    if args.backEvent then
        TriggerEvent(args.backEvent)
    end
end)

RegisterNetEvent("gs_redline:client:toggleTurbo", function()
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    PrepareVehicle(vehicle)
    ToggleVehicleMod(vehicle, 18, not IsToggleModOn(vehicle, 18))
    Notify("Turbo toggled.", "success")
    OpenPerformanceMenu()
end)

RegisterNetEvent("gs_redline:client:toggleXenon", function()
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    PrepareVehicle(vehicle)
    ToggleVehicleMod(vehicle, 22, not IsToggleModOn(vehicle, 22))
    Notify("Xenon toggled.", "success")
    OpenLightsMenu()
end)

RegisterNetEvent("gs_redline:client:applyHeadlightColor", function(colorIndex)
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    PrepareVehicle(vehicle)
    ToggleVehicleMod(vehicle, 22, true)

    local ok = pcall(function()
        SetVehicleXenonLightsColor(vehicle, colorIndex)
    end)

    if ok then
        Notify("Headlight color applied.", "success")
    else
        Notify("Headlight color native is not supported on this server artifact.", "error")
    end

    OpenHeadlightColorMenu()
end)

RegisterNetEvent("gs_redline:client:toggleNeon", function()
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    local enable = not IsVehicleNeonLightEnabled(vehicle, 0)

    EnableAllNeon(vehicle, enable)

    if enable then
        ApplyCurrentNeonColor(vehicle)
    end

    Notify("Neon toggled.", "success")
    OpenLightsMenu()
end)

RegisterNetEvent("gs_redline:client:setNeonEnabled", function(enabled)
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    EnableAllNeon(vehicle, enabled)

    if enabled then
        ApplyCurrentNeonColor(vehicle)
    end

    Notify(enabled and "Neon enabled." or "Neon disabled.", "success")
    OpenLightsMenu()
end)

RegisterNetEvent("gs_redline:client:applyNeonRed", function()
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    RedLineState.neonColor = { r = 255, g = 0, b = 0 }
    ApplyCurrentNeonColor(vehicle)
    Notify("Red neon applied.", "success")
    OpenLightsMenu()
end)

RegisterNetEvent("gs_redline:client:applyNeonColor", function(color)
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    RedLineState.neonColor = {
        r = color.r,
        g = color.g,
        b = color.b
    }

    ApplyCurrentNeonColor(vehicle)
    Notify("Neon color applied.", "success")
    OpenNeonColorMenu()
end)

RegisterNetEvent("gs_redline:client:applyNeonIntensity", function()
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    ApplyCurrentNeonColor(vehicle)
    Notify("Neon brightness is simulated by color intensity.", "primary")
    OpenNeonIntensitySliderMenu()
end)

RegisterNetEvent("gs_redline:client:applyWindowTint", function()
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    local tintIndex = GetWindowTintIndex(RedLineState.windowTint)
    SetVehicleWindowTint(vehicle, tintIndex)
    Notify(("Window tint applied: %s/100 mapped to tint index %s."):format(RedLineState.windowTint, tintIndex), "success")
    OpenWindowTintSliderMenu()
end)

RegisterNetEvent("gs_redline:client:applyWindowTintPreset", function(tintIndex)
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    SetVehicleWindowTint(vehicle, tintIndex)
    Notify(("Window tint preset applied: %s."):format(tintIndex), "success")
    OpenWindowTintPresetsMenu()
end)

RegisterNetEvent("gs_redline:client:applyRgbChannel", function(args)
    Notify("RGB channel value updated.", "success")
    OpenRgbChannelSlider(args)
end)

RegisterNetEvent("gs_redline:client:applyRgbEditor", function(args)
    local target = args and args.target or "neon"

    if target == "windowTint" then
        Notify("RGB window tint color is not supported by GTA native tint. Use tint darkness or preset tint.", "primary")
        OpenRgbEditorMenu({ target = "windowTint" })
        return
    end

    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    ApplyCurrentNeonColor(vehicle)
    Notify("Custom neon RGB color applied.", "success")
    OpenRgbEditorMenu({ target = "neon" })
end)

RegisterNetEvent("gs_redline:client:applyPlateStyle", function(plateIndex)
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    SetVehicleNumberPlateTextIndex(vehicle, plateIndex)
    Notify("Plate style applied.", "success")
    OpenPlateStyleMenu()
end)

RegisterNetEvent("gs_redline:client:toggleExtra", function(extraId)
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    local enabled = IsVehicleExtraTurnedOn(vehicle, extraId)
    SetVehicleExtra(vehicle, extraId, enabled and 1 or 0)
    Notify(("Extra %s toggled."):format(extraId), "success")
    OpenExtrasMenu()
end)

RegisterNetEvent("gs_redline:client:applyHorn", function(hornIndex)
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    PrepareVehicle(vehicle)
    SetVehicleMod(vehicle, 14, hornIndex, false)
    Notify("Horn applied.", "success")
    OpenHornMenu()
end)

RegisterNetEvent("gs_redline:client:previewHorn", function()
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    local ok = pcall(function()
        StartVehicleHorn(vehicle, 1000, GetHashKey("HELDDOWN"), false)
    end)

    if ok then
        Notify("Previewing horn.", "primary")
    else
        Notify("Horn preview is not supported on this server artifact.", "error")
    end

    OpenHornMenu()
end)

RegisterNetEvent("gs_redline:client:saveVehicle", function()
    local vehicle = GetMenuVehicle()

    if not vehicle then
        return
    end

    local props = QBCore.Functions.GetVehicleProperties(vehicle)
    TriggerServerEvent('qb-mechanicjob:server:SaveVehicleProps', props)
    Notify("Vehicle properties saved.", "success")
    Notify("Wheel size, wheel width, and custom tint color may require RedLine-specific persistence later.", "primary")
    OpenMainMenu()
end)

RegisterNetEvent("gs_redline:client:closeMenu", function()
    exports['qb-menu']:closeMenu()
    DestroyPreviewCamera()
    CurrentVehicle = nil
    CurrentBay = nil
end)

RegisterCommand("redlinecamoff", function()
    exports['qb-menu']:closeMenu()
    DestroyPreviewCamera()
    CurrentVehicle = nil
    CurrentBay = nil
    Notify("RedLine preview camera reset.", "success")
end, false)

CreateThread(function()
    CreateRedLineBlip()
end)

CreateThread(function()
    while true do
        local sleep = 500

        if PreviewCam then
            sleep = 0

            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) then -- Backspace / ESC
                Wait(100)
                DestroyPreviewCamera()
                CurrentVehicle = nil
                CurrentBay = nil
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local vehicle = GetVehiclePedIsIn(ped, false)
        local isDriver = false
        local isInVehicle = vehicle ~= 0

        if isInVehicle then
            isDriver = GetPedInVehicleSeat(vehicle, -1) == ped
        end

        for _, bay in ipairs(Config.ServiceBays) do
            local dist = #(playerCoords - bay.coords)

            if dist <= Config.DrawDistance then
                sleep = 0

                local isClose = dist <= Config.UseDistance

                DrawServiceBayIndicator(bay, isInVehicle and isDriver, isClose)

                if isClose and isInVehicle and isDriver then
                    if IsControlJustPressed(0, 38) then -- E
                        OpenCustomsMenu(vehicle, bay)
                    end
                elseif isClose and isInVehicle and not isDriver then
                    DrawText3D(
                        bay.coords.x,
                        bay.coords.y,
                        bay.coords.z + 1.9,
                        "~r~You must be the driver"
                    )
                end
            end
        end

        if CurrentBay and CurrentVehicle then
            local bayDist = #(playerCoords - CurrentBay.coords)
            local stillInVehicle = vehicle == CurrentVehicle and isDriver

            if bayDist > Config.DrawDistance or not stillInVehicle or not DoesEntityExist(CurrentVehicle) then
                exports['qb-menu']:closeMenu()
                DestroyPreviewCamera()
                CurrentVehicle = nil
                CurrentBay = nil
            end
        end

        Wait(sleep)
    end
end)

RegisterCommand("redlinebays", function()
    for _, bay in ipairs(Config.ServiceBays) do
        print(("[gs_redline] %s: %.4f, %.4f, %.4f heading %.4f"):format(
            bay.label,
            bay.coords.x,
            bay.coords.y,
            bay.coords.z,
            bay.heading
        ))
    end
end, false)
