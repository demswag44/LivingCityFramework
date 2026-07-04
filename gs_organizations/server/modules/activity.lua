---------------------------------------------------------------------
-- GS Organizations
--
-- File: activity.lua
-- Purpose:
--     Persistent organization activity feed
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

local Organization = GSOrganizations.Manager
local ActivityRepository = GSOrganizations.Repository.Activity

local ActivityTypes = {
    created = true,
    invite = true,
    join = true,
    leave = true,
    promote = true,
    demote = true,
    kick = true,
    deposit = true,
    withdraw = true,
    rank_template = true,
    treasury = true,
    announcement = true,
    system = true,
}

local function NormalizeActivityType(activityType)
    if type(activityType) ~= "string"
    or not ActivityTypes[activityType] then
        return "system"
    end

    return activityType
end

local function DecodeMetadata(value)
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

local function NormalizeRows(rows)
    for _, row in ipairs(rows or {}) do
        row.metadata = DecodeMetadata(row.metadata)
    end

    return rows or {}
end

function Organization.AddActivity(
    organizationId,
    actorIdentifier,
    actorName,
    activityType,
    title,
    description,
    metadata
)
    local result =
        ActivityRepository.AddActivity({
            organization_id = organizationId,
            actor_identifier = actorIdentifier,
            actor_name = actorName or actorIdentifier,
            type = NormalizeActivityType(activityType),
            title = title or "Organization Activity",
            description = description or "",
            metadata = metadata or {},
        })

    if not result or not result.id then
        return false, "Failed to persist activity."
    end

    if GSOrganizations.Events
    and GSOrganizations.Events.ActivityAdded then
        GSOrganizations.Events.ActivityAdded(
            organizationId,
            result.id
        )
    end

    Logger.Info(
        "ORGANIZATIONS",
        ("Activity recorded for organization %s: %s")
            :format(
                tostring(organizationId),
                tostring(title)
            )
    )

    return true, result.id
end

function Organization.GetActivities(organizationId, limit)
    return NormalizeRows(
        ActivityRepository.GetActivities(
            organizationId,
            limit or 20
        )
    )
end

function Organization.GetRecentActivities(organizationId, limit)
    return Organization.GetActivities(
        organizationId,
        limit or 10
    )
end

return Organization
