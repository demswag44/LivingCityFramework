---------------------------------------------------------------------
-- GS Organizations
--
-- File: history.lua
-- Purpose:
--     Organization history repository persistence access
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Repository = GSOrganizations.Repository or {}
GSOrganizations.Repository.History =
    GSOrganizations.Repository.History or {}

local Repository = GSOrganizations.Repository.History

function Repository.AddEntry(data)
    local id = MySQL.insert.await(
        [[
            INSERT INTO gs_organization_history
            (
                organization_id,
                action,
                actor_id,
                target_id,
                data_json
            )
            VALUES
            (
                ?, ?, ?, ?, ?
            )
        ]],
        {
            data.organization_id,
            data.action,
            data.actor_id,
            data.target_id,
            data.data_json,
        }
    )

    return {
        id = id,
    }
end

function Repository.GetHistory(organizationId)
    return MySQL.query.await(
        [[
            SELECT *
            FROM gs_organization_history
            WHERE organization_id = ?
            ORDER BY created_at DESC
        ]],
        {
            organizationId,
        }
    ) or {}
end
