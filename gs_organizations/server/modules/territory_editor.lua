---------------------------------------------------------------------
-- GS Organizations
--
-- File: territory_editor.lua
-- Purpose:
--     UI-agnostic territory editor backend API
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

Logger.Info(
    "TERRITORY EDITOR",
    "Module Loaded"
)

GSOrganizations = GSOrganizations or {}

local TerritoryEditor = {}

GSOrganizations.TerritoryEditor =
    TerritoryEditor

Logger.Info(
    "TERRITORY EDITOR",
    "Module Published"
)

TerritoryEditor.Drafts = {}
TerritoryEditor.Ready = false
TerritoryEditor.NameCounter = TerritoryEditor.NameCounter or 0

local function Response(success, dataOrMessage)
    if success then
        dataOrMessage =
            dataOrMessage or {}
        dataOrMessage.success = true
        return dataOrMessage
    end

    return {
        success = false,
        message = dataOrMessage,
    }
end

local function ActorKey(actor)
    if type(actor) == "table" then
        return tostring(actor.source or actor.id or actor.identifier)
    end

    return tostring(actor)
end

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return value:match("^%s*(.-)%s*$") or ""
end

local function IsWorldEditorActor(actor)
    return type(actor) == "table"
        and actor.isWorldEditor == true
        and actor.bypassGameplayPermissions == true
end

local function IsGenericWorldEditorName(name)
    local normalized =
        Trim(name):lower()

    return normalized == ""
        or normalized == "world territory"
        or normalized:match("^new territory") ~= nil
end

local function GenerateWorldEditorTerritoryName(actor)
    TerritoryEditor.NameCounter =
        (TerritoryEditor.NameCounter or 0) + 1

    local source =
        type(actor) == "table"
        and tonumber(actor.source)
        or tonumber(actor)
        or 0
    local uniqueValue =
        math.random(1000, 9999) + TerritoryEditor.NameCounter

    return ("World Territory %s-%s-%s"):format(
        tostring(source),
        tostring(os.time()),
        tostring(uniqueValue)
    )
end

local function EnsureWorldEditorTerritoryName(data, actor)
    local prepared = {}

    if type(data) == "table" then
        for key, value in pairs(data) do
            prepared[key] = value
        end
    end

    if IsWorldEditorActor(actor)
    and IsGenericWorldEditorName(prepared.name) then
        prepared.name =
            GenerateWorldEditorTerritoryName(actor)
        prepared._worldEditorGeneratedName =
            true
    else
        prepared.name =
            Trim(prepared.name)
    end

    return prepared
end

local function IsAdmin(actor)
    local source =
        type(actor) == "table"
        and tonumber(actor.source)
        or tonumber(actor)

    if source == nil then
        return false
    end

    return source == 0
        or IsPlayerAceAllowed(source, "command")
        or IsPlayerAceAllowed(source, "command.org")
        or IsPlayerAceAllowed(source, "gs_organizations.admin")
        or IsPlayerAceAllowed(source, "gs_organizations.territories")
end

local function HasWorldEditorPermission(source)
    source = tonumber(source)

    if source == nil then
        return false
    end

    if source == 0 then
        return true
    end

    local permissions = {
        "gs_world_editor.admin",
        "gs_world_editor.territories",
        "gs_organizations.admin",
        "gs_organizations.territories",
        "command",
        "command.org",
    }

    for _, permission in ipairs(permissions) do
        if IsPlayerAceAllowed(source, permission) then
            return true
        end
    end

    return false
end

local function HasTerritoryEditorAccess(actor)
    local source =
        type(actor) == "table"
        and tonumber(actor.source)
        or tonumber(actor)
    local session =
        type(actor) == "table"
        and actor.session
        or nil
    local hasWorldEditorPermission =
        HasWorldEditorPermission(source)
    local isAdmin =
        IsAdmin(actor)
    local worldEditorResult =
        type(actor) == "table"
        and actor.isWorldEditor == true
        and actor.bypassGameplayPermissions == true
        and type(session) == "table"
        and session.toolId == "territories"
        and tonumber(session.source) == source
        and hasWorldEditorPermission
        or false

    if worldEditorResult then
        return true
    end

    return isAdmin
end

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end

    local copied = {}

    for key, item in pairs(value) do
        copied[key] = Copy(item)
    end

    return copied
end

local function IsJSONSafe(value, seen)
    local valueType =
        type(value)

    if valueType == "nil"
    or valueType == "string"
    or valueType == "number"
    or valueType == "boolean" then
        return true
    end

    if valueType ~= "table" then
        return false
    end

    seen = seen or {}

    if seen[value] then
        return false
    end

    seen[value] = true

    for key, item in pairs(value) do
        local keyType =
            type(key)

        if keyType ~= "string"
        and keyType ~= "number" then
            return false
        end

        if not IsJSONSafe(item, seen) then
            return false
        end
    end

    seen[value] = nil

    return true
end

local function NormalizeCenter(center)
    if type(center) ~= "table" then
        return nil
    end

    local x =
        tonumber(center.x or center[1])
    local y =
        tonumber(center.y or center[2])
    local z =
        tonumber(center.z or center[3])

    if not x or not y or not z then
        return nil
    end

    return {
        x = x,
        y = y,
        z = z,
    }
end

local function BuildPolygonEnvelope(data)
    return {
        points = data.polygon or {},
        type = data.type,
        radius = data.radius,
        height = data.height,
        enabled = data.enabled,
        metadata = data.metadata or {},
    }
end

local function ToPersistenceData(data)
    return {
        name = data.name,
        description = data.description or "",
        owner_organization_id = data.owner_id,
        color = data.color or "",
        polygon = BuildPolygonEnvelope(data),
        center_x = data.center.x,
        center_y = data.center.y,
        center_z = data.center.z,
        influence = data.influence or GS.TerritoryConfig.DefaultInfluence,
        heat = data.heat or GS.TerritoryConfig.DefaultHeat,
        income = data.income or 0,
        population = data.population or 0,
    }
end

local function ReloadRuntime()
    if GSOrganizations.Territories
    and GSOrganizations.Territories.Initialize then
        GSOrganizations.Territories.Initialize()
    end

    if GSOrganizations.TerritoryZones
    and GSOrganizations.TerritoryZones.Initialize then
        GSOrganizations.TerritoryZones.Initialize()
    end

    Logger.Success(
        "TERRITORY EDITOR",
        "Territory Runtime Reloaded"
    )
end

local function GetRepository()
    local Repository =
        GSOrganizations.Repository
        and GSOrganizations.Repository.TerritoryEditor

    if not Repository then
        return nil, "Territory editor repository is unavailable."
    end

    return Repository
end

function TerritoryEditor.Initialize()
    TerritoryEditor.Ready = true

    Logger.Success(
        "TERRITORY EDITOR",
        "Territory Editor Initialized"
    )

    return true
end

function TerritoryEditor.ValidateTerritoryData(data)
    if type(data) ~= "table" then
        return false, "Territory data must be a table."
    end

    local normalized =
        Copy(data)

    if type(normalized.name) ~= "string"
    or normalized.name:match("^%s*$") then
        return false, "Territory name is required."
    end

    normalized.name =
        normalized.name:match("^%s*(.-)%s*$")

    normalized.type =
        tostring(normalized.type or GS.TerritoryEditor.DefaultType):lower()

    if not GS.TerritoryEditor.ValidTypes[normalized.type] then
        normalized.type =
            GS.TerritoryEditor.DefaultType
    end

    normalized.center =
        NormalizeCenter(normalized.center)

    if not normalized.center then
        return false, "Territory center must include x, y, and z."
    end

    normalized.radius =
        tonumber(normalized.radius)
        or GS.TerritoryZoneConfig.DefaultRadius

    if normalized.radius <= 0 then
        return false, "Territory radius must be positive."
    end

    normalized.height =
        tonumber(normalized.height)
        or GS.TerritoryZoneConfig.DefaultHeight

    if normalized.height <= 0 then
        return false, "Territory height must be positive."
    end

    if normalized.owner_id ~= nil
    and normalized.owner_id ~= "" then
        normalized.owner_id =
            tonumber(normalized.owner_id)

        if not normalized.owner_id
        or not GSOrganizations.Manager.Get(normalized.owner_id) then
            return false, "Territory owner organization does not exist."
        end
    else
        normalized.owner_id = nil
    end

    normalized.enabled =
        normalized.enabled ~= false

    normalized.metadata =
        normalized.metadata or {}

    if not IsJSONSafe(normalized.metadata) then
        return false, "Territory metadata must be JSON-safe."
    end

    if normalized.polygon ~= nil
    and not IsJSONSafe(normalized.polygon) then
        return false, "Territory polygon must be JSON-safe."
    end

    normalized.polygon =
        normalized.polygon or {}

    return true, normalized
end

function TerritoryEditor.CreateTerritory(data, actor)
    if not HasTerritoryEditorAccess(actor) then
        return Response(false, "You are not allowed to create territories.")
    end

    data =
        EnsureWorldEditorTerritoryName(data, actor)

    local valid, normalized =
        TerritoryEditor.ValidateTerritoryData(data)

    if not valid then
        return Response(false, normalized)
    end

    local Repository, repositoryError =
        GetRepository()

    if not Repository then
        return Response(false, repositoryError)
    end

    local result =
        Repository.CreateTerritory(
            ToPersistenceData(normalized)
        )

    if result
    and result.error == "Territory name already exists."
    and normalized._worldEditorGeneratedName == true then
        normalized.name =
            GenerateWorldEditorTerritoryName(actor)

        result =
            Repository.CreateTerritory(
                ToPersistenceData(normalized)
            )
    end

    if result and result.error then
        return Response(false, result.error)
    end

    if not result or not result.id then
        return Response(false, "Unable to create territory.")
    end

    ReloadRuntime()

    Logger.Success(
        "TERRITORY EDITOR",
        "Territory Created"
    )

    TriggerEvent(
        "gs_organizations:territoryEditor:created",
        result.id,
        actor
    )

    return Response(true, {
        territoryId = result.id,
    })
end

function TerritoryEditor.UpdateTerritory(id, data, actor)
    if not HasTerritoryEditorAccess(actor) then
        return Response(false, "You are not allowed to update territories.")
    end

    id = tonumber(id)

    if not id then
        return Response(false, "Territory id is required.")
    end

    local valid, normalized =
        TerritoryEditor.ValidateTerritoryData(data)

    if not valid then
        return Response(false, normalized)
    end

    local Repository, repositoryError =
        GetRepository()

    if not Repository then
        return Response(false, repositoryError)
    end

    local result =
        Repository.UpdateTerritory(
            id,
            ToPersistenceData(normalized)
        )

    if result and result.error then
        return Response(false, result.error)
    end

    if not result or result.affectedRows < 1 then
        return Response(false, "Territory not found.")
    end

    ReloadRuntime()

    Logger.Success(
        "TERRITORY EDITOR",
        "Territory Updated"
    )

    TriggerEvent(
        "gs_organizations:territoryEditor:updated",
        id,
        actor
    )

    return Response(true, {
        territoryId = id,
    })
end

function TerritoryEditor.DeleteTerritory(id, actor)
    if not HasTerritoryEditorAccess(actor) then
        return Response(false, "You are not allowed to delete territories.")
    end

    id = tonumber(id)

    if not id then
        return Response(false, "Territory id is required.")
    end

    local Repository, repositoryError =
        GetRepository()

    if not Repository then
        return Response(false, repositoryError)
    end

    local result =
        Repository.DeleteTerritory(id)

    if result and result.error then
        return Response(false, result.error)
    end

    if not result or result.affectedRows < 1 then
        return Response(false, "Territory not found.")
    end

    ReloadRuntime()

    Logger.Success(
        "TERRITORY EDITOR",
        "Territory Deleted"
    )

    TriggerEvent(
        "gs_organizations:territoryEditor:deleted",
        id,
        actor
    )

    return Response(true, {
        territoryId = id,
    })
end

function TerritoryEditor.GetDraft(actor)
    return Copy(TerritoryEditor.Drafts[ActorKey(actor)])
end

function TerritoryEditor.SaveDraft(actor, data)
    if not HasTerritoryEditorAccess(actor) then
        return Response(false, "You are not allowed to save territory drafts.")
    end

    local key =
        ActorKey(actor)

    TerritoryEditor.Drafts[key] =
        Copy(data or {})

    Logger.Info(
        "TERRITORY EDITOR",
        "Draft Saved"
    )

    return Response(true, {
        draft = TerritoryEditor.GetDraft(actor),
    })
end

function TerritoryEditor.ClearDraft(actor)
    if not HasTerritoryEditorAccess(actor) then
        return Response(false, "You are not allowed to clear territory drafts.")
    end

    TerritoryEditor.Drafts[ActorKey(actor)] =
        nil

    return Response(true)
end

function TerritoryEditor.GetEditorState(actor)
    if not HasTerritoryEditorAccess(actor) then
        return Response(false, "You are not allowed to use the territory editor.")
    end

    return Response(true, {
        draft = TerritoryEditor.GetDraft(actor),
        config = {
            validTypes = GS.TerritoryEditor.ValidTypes,
            defaultType = GS.TerritoryEditor.DefaultType,
        },
    })
end

local function Actor(source, overrides)
    local actor = {
        source = source,
        identifier = tostring(source),
    }

    for key, value in pairs(overrides or {}) do
        actor[key] = value
    end

    return actor
end

local function ToWorldEditorTerritory(territory)
    if not territory then
        return nil
    end

    return {
        id = territory.Id,
        name = territory.Name,
        owner = territory.OwnerOrganizationId,
        center = territory.Center,
        radius = territory.Radius,
        height = territory.Height,
        influence = territory.Influence,
        heat = territory.Heat,
        enabled = territory.Enabled ~= false,
    }
end

local function GetWorldEditorTerritories()
    local territories = {}
    local Runtime =
        GSOrganizations.Territories

    if not Runtime or not Runtime.GetAll then
        return territories
    end

    for _, territory in pairs(Runtime.GetAll() or {}) do
        local formatted =
            ToWorldEditorTerritory(territory)

        if formatted then
            territories[#territories + 1] = formatted
        end
    end

    table.sort(territories, function(left, right)
        return tostring(left.name) < tostring(right.name)
    end)

    return territories
end

local function WorldEditorActor(source, payload)
    local actor =
        Copy(payload and payload.actor or {})
    local invokingResource =
        GetInvokingResource
        and GetInvokingResource()
        or nil

    if actor.session == nil
    and payload
    and payload.session then
        actor.session =
            Copy(payload.session)
    end

    actor.source = tonumber(source)
    actor.identifier = tostring(source)
    actor.isWorldEditor = true
    actor.bypassGameplayPermissions = true
    actor.origin = "gs_world_editor"
    actor.originResource = invokingResource

    return Actor(source, actor)
end

local function NormalizeWorldEditorArgs(arg1, arg2)
    local source =
        nil
    local payload =
        nil

    if type(arg1) == "number"
    and type(arg2) == "table" then
        source =
            arg1
        payload =
            arg2
    elseif type(arg1) == "string"
    and type(arg2) == "table" then
        source =
            tonumber(arg1)
        payload =
            arg2
    elseif type(arg1) == "table" then
        payload =
            arg1
        source =
            payload.source
            or payload.actor
            and payload.actor.source
            or payload.session
            and payload.session.source
            or payload.data
            and payload.data.metadata
            and payload.data.metadata.createdBy
    end

    payload =
        payload or {}
    source =
        tonumber(source)

    payload.actor =
        payload.actor or {}
    payload.actor.source =
        tonumber(payload.actor.source) or source
    payload.actor.isWorldEditor =
        true
    payload.actor.bypassGameplayPermissions =
        true
    payload.actor.session =
        payload.actor.session or payload.session
    payload.actor.originResource =
        "gs_world_editor"
    payload.source =
        payload.source or payload.actor.source or source

    return payload.actor.source or source, payload
end

local function AuditWorldEditorSave(source, action, data)
    data = data or {}

    local center =
        data.center or {}
    local actionLabels = {
        create = "Created",
        save = "Created",
        edit = "Updated",
        delete = "Deleted",
    }
    local actionLabel =
        actionLabels[action] or "Saved"

    Logger.Success(
        "TERRITORY EDITOR",
        ("World Editor Territory %s | Source=%s | Action=%s | Name=%s | Center=%.2f, %.2f, %.2f | Radius=%.2f | Timestamp=%s")
            :format(
                actionLabel,
                tostring(source),
                tostring(action or "create"),
                tostring(data.name or "Unnamed Territory"),
                tonumber(center.x) or 0.0,
                tonumber(center.y) or 0.0,
                tonumber(center.z) or 0.0,
                tonumber(data.radius) or 0.0,
                tostring(os.time())
            )
    )
end

local function WorldEditorSave(source, payload)
    source, payload =
        NormalizeWorldEditorArgs(source, payload)

    local invokingResource =
        GetInvokingResource
        and GetInvokingResource()
        or nil

    if invokingResource
    and invokingResource ~= "gs_world_editor" then
        return {
            success = false,
            error = "access denied.",
        }
    end

    local action =
        tostring(payload.action or "create"):lower()
    local actor =
        WorldEditorActor(source, payload)
    local data =
        payload.data or {}
    local result =
        nil

    if action == "create" or action == "save" then
        result =
            TerritoryEditor.CreateTerritory(
                data,
                actor
            )
    elseif action == "edit" then
        result =
            TerritoryEditor.UpdateTerritory(
                data.id or payload.id,
                data,
                actor
            )
    elseif action == "delete" then
        result =
            TerritoryEditor.DeleteTerritory(
                data.id or payload.id,
                actor
            )
    else
        return {
            success = false,
            error = ("unsupported territory action '%s'."):format(action),
        }
    end

    if not result or result.success ~= true then
        return {
            success = false,
            error = result and (result.error or result.message) or "territory editor unavailable.",
        }
    end

    local territory =
        GSOrganizations.Territories
        and GSOrganizations.Territories.Get
        and GSOrganizations.Territories.Get(result.territoryId)
        or nil

    AuditWorldEditorSave(source, action, data)

    return {
        success = true,
        message = "Territory saved.",
        territory = ToWorldEditorTerritory(territory),
        toolData = {
            territories = GetWorldEditorTerritories(),
        },
    }
end

local function WorldEditorSaveTerritory(arg1, arg2)
    return WorldEditorSave(arg1, arg2)
end

exports("WorldEditorSaveTerritory", function(...)
    return WorldEditorSaveTerritory(...)
end)
exports("WorldEditorGetTerritories", function()
    return {
        territories = GetWorldEditorTerritories(),
    }
end)

AddEventHandler("gs_organizations:territoryEditor:worldEditorSave", function(source, payload, cb)
    local result =
        WorldEditorSave(source, payload)

    if type(cb) == "function" then
        cb(result)
    end
end)

lib.callback.register(GS.TerritoryEditor.Callbacks.Create, function(source, data)
    return TerritoryEditor.CreateTerritory(data, Actor(source))
end)

lib.callback.register(GS.TerritoryEditor.Callbacks.Update, function(source, data)
    return TerritoryEditor.UpdateTerritory(
        data and data.id,
        data and data.data,
        Actor(source)
    )
end)

lib.callback.register(GS.TerritoryEditor.Callbacks.Delete, function(source, data)
    return TerritoryEditor.DeleteTerritory(
        data and data.id,
        Actor(source)
    )
end)

lib.callback.register(GS.TerritoryEditor.Callbacks.GetState, function(source)
    return TerritoryEditor.GetEditorState(Actor(source))
end)

lib.callback.register(GS.TerritoryEditor.Callbacks.SaveDraft, function(source, data)
    return TerritoryEditor.SaveDraft(Actor(source), data)
end)

lib.callback.register(GS.TerritoryEditor.Callbacks.ClearDraft, function(source)
    return TerritoryEditor.ClearDraft(Actor(source))
end)

RegisterNetEvent(GS.TerritoryEditor.Callbacks.Create, function(data)
    local result =
        TerritoryEditor.CreateTerritory(data, Actor(source))

    TriggerClientEvent(
        GS.TerritoryEditor.Callbacks.Create .. ":result",
        source,
        result
    )
end)

RegisterNetEvent(GS.TerritoryEditor.Callbacks.Update, function(data)
    local result =
        TerritoryEditor.UpdateTerritory(
            data and data.id,
            data and data.data,
            Actor(source)
        )

    TriggerClientEvent(
        GS.TerritoryEditor.Callbacks.Update .. ":result",
        source,
        result
    )
end)

RegisterNetEvent(GS.TerritoryEditor.Callbacks.Delete, function(data)
    local result =
        TerritoryEditor.DeleteTerritory(
            data and data.id,
            Actor(source)
        )

    TriggerClientEvent(
        GS.TerritoryEditor.Callbacks.Delete .. ":result",
        source,
        result
    )
end)

RegisterNetEvent(GS.TerritoryEditor.Callbacks.GetState, function()
    TriggerClientEvent(
        GS.TerritoryEditor.Callbacks.GetState .. ":result",
        source,
        TerritoryEditor.GetEditorState(Actor(source))
    )
end)

RegisterNetEvent(GS.TerritoryEditor.Callbacks.SaveDraft, function(data)
    TriggerClientEvent(
        GS.TerritoryEditor.Callbacks.SaveDraft .. ":result",
        source,
        TerritoryEditor.SaveDraft(Actor(source), data)
    )
end)

RegisterNetEvent(GS.TerritoryEditor.Callbacks.ClearDraft, function()
    TriggerClientEvent(
        GS.TerritoryEditor.Callbacks.ClearDraft .. ":result",
        source,
        TerritoryEditor.ClearDraft(Actor(source))
    )
end)

return TerritoryEditor
