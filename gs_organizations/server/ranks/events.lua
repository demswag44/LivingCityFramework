---------------------------------------------------------------------
-- GS Organizations
--
-- File: events.lua
-- Purpose:
--     Dynamic rank event dispatch
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Events = GSOrganizations.Events or {}

local Events = GSOrganizations.Events

function Events.RankCreated(organizationId, rank)
    TriggerEvent(
        "gs:organization:rankCreated",
        organizationId,
        rank
    )
end

function Events.RankDeleted(organizationId, rankName)
    TriggerEvent(
        "gs:organization:rankDeleted",
        organizationId,
        rankName
    )
end

function Events.RankUpdated(organizationId, rank)
    TriggerEvent(
        "gs:organization:rankUpdated",
        organizationId,
        rank
    )
end

function Events.RankPermissionChanged(organizationId, rank)
    TriggerEvent(
        "gs:organization:rankPermissionChanged",
        organizationId,
        rank
    )
end

function Events.RankSalaryChanged(organizationId, rank)
    TriggerEvent(
        "gs:organization:rankSalaryChanged",
        organizationId,
        rank
    )
end

return Events
