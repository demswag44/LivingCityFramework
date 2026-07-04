---------------------------------------------------------------------
-- GS Organizations
--
-- File: territories.lua
-- Purpose:
--     Persistent territory framework runtime
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

Logger.Info(
    "TERRITORIES",
    "Module Loaded"
)

GSOrganizations = GSOrganizations or {}
GS = GS or {}
GS.TerritoryConfig =
    GS.TerritoryConfig
    or {
        DefaultInfluence = 0,
        DefaultHeat = 0,
        MaximumInfluence = 1000,
        MaximumHeat = 100,
        CaptureCooldown = 0,
    }

local Territories = GSOrganizations.Territories or {}

Logger.Info(
    "TERRITORIES",
    "Publishing Module"
)

GSOrganizations.Territories = Territories

Logger.Info(
    "TERRITORIES",
    "Module Published"
)

local Repository =
    GSOrganizations.Repository
    and GSOrganizations.Repository.Territories
    or nil
local Organization = GSOrganizations.Manager

Territories.List = Territories.List or {}
Territories.Ready = false

local function DecodePolygon(value)
    if type(value) == "table" then
        return value
    end

    if type(value) ~= "string" or value == "" then
        return {}
    end

    local ok, decoded = pcall(json.decode, value)

    if ok and type(decoded) == "table" then
        return decoded
    end

    return {}
end

local function NormalizeTerritory(row)
    if not row then
        return nil
    end

    return {
        Id = row.id,
        Name = row.name,
        Description = row.description or "",
        OwnerOrganizationId = row.owner_organization_id,
        Color = row.color or "",
        Polygon = DecodePolygon(row.polygon),
        Center = {
            x = tonumber(row.center_x) or 0,
            y = tonumber(row.center_y) or 0,
            z = tonumber(row.center_z) or 0,
        },
        Influence = tonumber(row.influence)
            or GS.TerritoryConfig.DefaultInfluence,
        Heat = tonumber(row.heat)
            or GS.TerritoryConfig.DefaultHeat,
        Income = tonumber(row.income) or 0,
        Population = tonumber(row.population) or 0,
        CreatedAt = row.created_at,
        UpdatedAt = row.updated_at,
    }
end

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or 0

    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local function PointInPolygon(x, y, polygon)
    local inside = false
    local count = #polygon

    if count < 3 then
        return false
    end

    local j = count

    for i = 1, count do
        local current = polygon[i]
        local previous = polygon[j]

        local xi = tonumber(current.x or current[1])
        local yi = tonumber(current.y or current[2])
        local xj = tonumber(previous.x or previous[1])
        local yj = tonumber(previous.y or previous[2])

        if xi and yi and xj and yj then
            local intersects =
                ((yi > y) ~= (yj > y))
                and (
                    x
                    < (xj - xi) * (y - yi) / ((yj - yi) + 0.0) + xi
                )

            if intersects then
                inside = not inside
            end
        end

        j = i
    end

    return inside
end

local function AddActivity(territory, activityType, title, description, metadata)
    if not territory then
        return
    end

    local organizationId =
        territory.OwnerOrganizationId

    if not organizationId then
        return
    end

    if Organization.AddActivity then
        Organization.AddActivity(
            organizationId,
            "system",
            "System",
            activityType,
            title,
            description,
            metadata or {
                Territory = territory.Id,
            }
        )
    end
end

function Territories.Initialize()
    Repository =
        Repository
        or (
            GSOrganizations.Repository
            and GSOrganizations.Repository.Territories
        )

    if not Repository
    or not Repository.LoadTerritories then
        Logger.Error(
            "TERRITORIES",
            "Territory repository is unavailable during initialization."
        )
        return false
    end

    Territories.List = {}

    local rows =
        Repository.LoadTerritories()

    for _, row in ipairs(rows) do
        local territory =
            NormalizeTerritory(row)

        if territory then
            Territories.List[territory.Id] = territory
        end
    end

    Territories.Ready = true

    Logger.Success(
        "TERRITORIES",
        ("%d territory record(s) loaded.")
            :format(#rows)
    )

    Logger.Success(
        "TERRITORIES",
        "Territories Module Initialized"
    )

    return true
end

function Territories.Get(id)
    return Territories.List[tonumber(id)]
end

function Territories.GetAll()
    return Territories.List
end

function Territories.GetByOrganization(orgId)
    local territories = {}

    for _, territory in pairs(Territories.List) do
        if tonumber(territory.OwnerOrganizationId) == tonumber(orgId) then
            territories[#territories + 1] = territory
        end
    end

    table.sort(territories, function(left, right)
        return left.Name < right.Name
    end)

    return territories
end

function Territories.GetPlayerTerritory(source)
    local ped =
        GetPlayerPed(source)

    if not ped or ped == 0 then
        return nil
    end

    local coords =
        GetEntityCoords(ped)

    for _, territory in pairs(Territories.List) do
        if PointInPolygon(
            coords.x,
            coords.y,
            territory.Polygon
        ) then
            return {
                territory = territory,
                owner = territory.OwnerOrganizationId,
                influence = territory.Influence,
                heat = territory.Heat,
            }
        end
    end

    return nil
end

function Territories.SaveTerritory(data)
    if type(data) ~= "table" then
        return false, "Invalid territory data."
    end

    local territoryData = {
        id = data.id or data.Id,
        name = data.name or data.Name,
        description = data.description or data.Description or "",
        owner_organization_id =
            data.owner_organization_id
            or data.OwnerOrganizationId,
        color = data.color or data.Color or "",
        polygon = data.polygon or data.Polygon or {},
        center_x =
            data.center_x
            or data.CenterX
            or (data.Center and data.Center.x)
            or 0,
        center_y =
            data.center_y
            or data.CenterY
            or (data.Center and data.Center.y)
            or 0,
        center_z =
            data.center_z
            or data.CenterZ
            or (data.Center and data.Center.z)
            or 0,
        influence =
            data.influence
            or data.Influence
            or GS.TerritoryConfig.DefaultInfluence,
        heat =
            data.heat
            or data.Heat
            or GS.TerritoryConfig.DefaultHeat,
        income = data.income or data.Income or 0,
        population = data.population or data.Population or 0,
    }

    if not territoryData.name
    or territoryData.name == "" then
        return false, "Territory name is required."
    end

    local isNew =
        territoryData.id == nil

    local result =
        Repository.SaveTerritory(territoryData)

    if not result or not result.id then
        return false, "Failed to save territory."
    end

    territoryData.id =
        result.id

    local territory =
        NormalizeTerritory(territoryData)

    Territories.List[territory.Id] =
        territory

    if isNew then
        AddActivity(
            territory,
            "system",
            "Territory created",
            ("%s territory was created."):format(territory.Name),
            {
                Territory = territory.Id,
            }
        )

        if GSOrganizations.Events
        and GSOrganizations.Events.TerritoryCreated then
            GSOrganizations.Events.TerritoryCreated(
                territory.Id,
                territory.OwnerOrganizationId
            )
        end
    end

    return true, territory
end

function Territories.SetOwner(id, organizationId)
    local territory =
        Territories.Get(id)

    if not territory then
        return false, "Territory not found."
    end

    if organizationId
    and not Organization.Get(tonumber(organizationId)) then
        return false, "Organization not found."
    end

    local oldOwner =
        territory.OwnerOrganizationId

    local result =
        Repository.UpdateOwner(
            territory.Id,
            organizationId and tonumber(organizationId) or nil
        )

    if not result or result.affectedRows < 1 then
        return false, "Failed to update territory owner."
    end

    territory.OwnerOrganizationId =
        organizationId and tonumber(organizationId) or nil

    AddActivity(
        territory,
        "system",
        "Territory owner changed",
        ("%s owner changed."):format(territory.Name),
        {
            Territory = territory.Id,
            PreviousOwner = oldOwner,
            NewOwner = territory.OwnerOrganizationId,
        }
    )

    if GSOrganizations.Events
    and GSOrganizations.Events.TerritoryOwnerChanged then
        GSOrganizations.Events.TerritoryOwnerChanged(
            territory.Id,
            oldOwner,
            territory.OwnerOrganizationId
        )
    end

    return true, territory
end

function Territories.AddInfluence(id, amount)
    local territory =
        Territories.Get(id)

    if not territory then
        return false, "Territory not found."
    end

    local previous =
        territory.Influence

    territory.Influence =
        Clamp(
            territory.Influence + (tonumber(amount) or 0),
            0,
            GS.TerritoryConfig.MaximumInfluence
        )

    Repository.UpdateInfluence(
        territory.Id,
        territory.Influence
    )

    AddActivity(
        territory,
        "system",
        "Territory influence changed",
        ("%s influence changed to %s."):format(
            territory.Name,
            tostring(territory.Influence)
        ),
        {
            Territory = territory.Id,
            PreviousInfluence = previous,
            Influence = territory.Influence,
        }
    )

    if GSOrganizations.Events
    and GSOrganizations.Events.TerritoryInfluenceChanged then
        GSOrganizations.Events.TerritoryInfluenceChanged(
            territory.Id,
            territory.Influence
        )
    end

    return true, territory.Influence
end

function Territories.RemoveInfluence(id, amount)
    return Territories.AddInfluence(
        id,
        -(tonumber(amount) or 0)
    )
end

function Territories.AddHeat(id, amount)
    local territory =
        Territories.Get(id)

    if not territory then
        return false, "Territory not found."
    end

    local previous =
        territory.Heat

    territory.Heat =
        Clamp(
            territory.Heat + (tonumber(amount) or 0),
            0,
            GS.TerritoryConfig.MaximumHeat
        )

    Repository.UpdateHeat(
        territory.Id,
        territory.Heat
    )

    AddActivity(
        territory,
        "system",
        "Territory heat changed",
        ("%s heat changed to %s."):format(
            territory.Name,
            tostring(territory.Heat)
        ),
        {
            Territory = territory.Id,
            PreviousHeat = previous,
            Heat = territory.Heat,
        }
    )

    if GSOrganizations.Events
    and GSOrganizations.Events.TerritoryHeatChanged then
        GSOrganizations.Events.TerritoryHeatChanged(
            territory.Id,
            territory.Heat
        )
    end

    return true, territory.Heat
end

function Territories.RemoveHeat(id, amount)
    return Territories.AddHeat(
        id,
        -(tonumber(amount) or 0)
    )
end

return Territories
