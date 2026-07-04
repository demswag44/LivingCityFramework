---------------------------------------------------------------------
-- GS Framework
--
-- File: cache.lua
-- Purpose:
--     Central in-memory cache for the GS Framework.
--
-- Dependencies:
--     logger.lua
---------------------------------------------------------------------

GS = GS or {}

GS.Cache = {}

local Cache = GS.Cache

---------------------------------------------------------------------
-- Framework State
---------------------------------------------------------------------

Cache.Framework = {
    Ready = false,
    Started = false,
    StartupTime = 0
}

---------------------------------------------------------------------
-- Data Stores
---------------------------------------------------------------------

Cache.Data = {
    Organizations = {},
    Players = {},
    NPCs = {},
    Territories = {},
    Properties = {},
    Businesses = {},
    Police = {},
    Dispatch = {},
    AI = {},
    World = {},
    Relationships = {},
    History = {}
}

---------------------------------------------------------------------
-- Statistics
---------------------------------------------------------------------

Cache.Stats = {
    Organizations = 0,
    Players = 0,
    NPCs = 0,
    Territories = 0,
    Businesses = 0
}

---------------------------------------------------------------------
-- Internal Helpers
---------------------------------------------------------------------

local function GetStore(name)
    return Cache.Data[name]
end

local function CreateRecord(value)

    return {
        Value = value,

        Meta = {
            Created = os.time(),
            Updated = os.time(),
            Dirty = false,
            Version = 1,
            Expires = nil
        }
    }

end

---------------------------------------------------------------------
-- Generic Cache API
---------------------------------------------------------------------

function Cache.Set(store, key, value)

    local data = GetStore(store)

    if not data then
        return false
    end

    local record = data[key]

    if record then

        record.Value = value
        record.Meta.Updated = os.time()
        record.Meta.Dirty = true
        record.Meta.Version = record.Meta.Version + 1

    else

        record = CreateRecord(value)
        record.Meta.Dirty = true

        data[key] = record

    end

    return true

end

function Cache.Get(store, key)

    local data = GetStore(store)

    if not data then
        return nil
    end

    local record = data[key]

    if not record then
        return nil
    end

    if record.Meta.Expires and record.Meta.Expires < os.time() then
        data[key] = nil
        return nil
    end

    return record.Value

end

function Cache.Remove(store, key)

    local data = GetStore(store)

    if not data then
        return false
    end

    data[key] = nil

    return true

end

function Cache.Clear(store)

    local data = GetStore(store)

    if not data then
        return
    end

    for k in pairs(data) do
        data[k] = nil
    end

end

---------------------------------------------------------------------
-- Metadata
---------------------------------------------------------------------

function Cache.GetMeta(store, key)

    local data = GetStore(store)

    if not data then
        return nil
    end

    local record = data[key]

    if not record then
        return nil
    end

    return record.Meta

end

function Cache.MarkClean(store, key)

    local meta = Cache.GetMeta(store, key)

    if meta then
        meta.Dirty = false
    end

end

function Cache.SetExpiration(store, key, seconds)

    local meta = Cache.GetMeta(store, key)

    if meta then
        meta.Expires = os.time() + seconds
    end

end

---------------------------------------------------------------------
-- Statistics
---------------------------------------------------------------------

function Cache.Count(store)

    local data = GetStore(store)

    if not data then
        return 0
    end

    local count = 0

    for _ in pairs(data) do
        count = count + 1
    end

    return count

end

---------------------------------------------------------------------
-- Typed APIs
---------------------------------------------------------------------

Cache.Organization = {}

function Cache.Organization.Get(id)
    return Cache.Get("Organizations", id)
end

function Cache.Organization.Set(id, value)
    return Cache.Set("Organizations", id, value)
end

function Cache.Organization.Remove(id)
    return Cache.Remove("Organizations", id)
end

----------------------------------------------------------

Cache.Player = {}

function Cache.Player.Get(id)
    return Cache.Get("Players", id)
end

function Cache.Player.Set(id, value)
    return Cache.Set("Players", id, value)
end

function Cache.Player.Remove(id)
    return Cache.Remove("Players", id)
end

----------------------------------------------------------

Cache.NPC = {}

function Cache.NPC.Get(id)
    return Cache.Get("NPCs", id)
end

function Cache.NPC.Set(id, value)
    return Cache.Set("NPCs", id, value)
end

function Cache.NPC.Remove(id)
    return Cache.Remove("NPCs", id)
end

----------------------------------------------------------

Cache.Territory = {}

function Cache.Territory.Get(id)
    return Cache.Get("Territories", id)
end

function Cache.Territory.Set(id, value)
    return Cache.Set("Territories", id, value)
end

function Cache.Territory.Remove(id)
    return Cache.Remove("Territories", id)
end

----------------------------------------------------------

Cache.Business = {}

function Cache.Business.Get(id)
    return Cache.Get("Businesses", id)
end

function Cache.Business.Set(id, value)
    return Cache.Set("Businesses", id, value)
end

function Cache.Business.Remove(id)
    return Cache.Remove("Businesses", id)
end

----------------------------------------------------------

Cache.Property = {}

function Cache.Property.Get(id)
    return Cache.Get("Properties", id)
end

function Cache.Property.Set(id, value)
    return Cache.Set("Properties", id, value)
end

function Cache.Property.Remove(id)
    return Cache.Remove("Properties", id)
end

---------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------

GS.Logger.Info("CACHE", "Smart Cache Initialized")