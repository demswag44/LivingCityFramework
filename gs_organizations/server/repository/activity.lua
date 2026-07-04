---------------------------------------------------------------------
-- GS Organizations
--
-- File: activity.lua
-- Purpose:
--     Organization activity feed repository persistence access
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Repository = GSOrganizations.Repository or {}
GSOrganizations.Repository.Activity =
    GSOrganizations.Repository.Activity or {}

local Repository = GSOrganizations.Repository.Activity

local function EncodeMetadata(metadata)
    if type(metadata) == "string" then
        return metadata
    end

    return json.encode(metadata or {})
end

function Repository.AddActivity(data)
    local id = MySQL.insert.await(
        [[
            INSERT INTO organization_activity
            (
                organization_id,
                actor_identifier,
                actor_name,
                type,
                title,
                description,
                metadata
            )
            VALUES
            (
                ?, ?, ?, ?, ?, ?, ?
            )
        ]],
        {
            data.organization_id,
            data.actor_identifier,
            data.actor_name,
            data.type,
            data.title,
            data.description,
            EncodeMetadata(data.metadata),
        }
    )

    return {
        id = id,
    }
end

function Repository.GetActivities(organizationId, limit)
    return MySQL.query.await(
        [[
            SELECT *
            FROM organization_activity
            WHERE organization_id = ?
            ORDER BY created_at DESC, id DESC
            LIMIT ?
        ]],
        {
            organizationId,
            tonumber(limit) or 20,
        }
    ) or {}
end

return Repository
