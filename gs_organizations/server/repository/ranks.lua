---------------------------------------------------------------------
-- GS Organizations
--
-- File: ranks.lua
-- Purpose:
--     Organization rank repository persistence access
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Repository = GSOrganizations.Repository or {}
GSOrganizations.Repository.Ranks =
    GSOrganizations.Repository.Ranks or {}

local Repository = GSOrganizations.Repository.Ranks

function Repository.CreateRank(data)
    local id = MySQL.insert.await(
        [[
            INSERT INTO gs_organization_ranks
            (
                organization_id,
                name,
                label,
                weight,
                permissions_json,
                salary,
                color,
                icon
            )
            VALUES
            (
                ?, ?, ?, ?, ?, ?, ?, ?
            )
        ]],
        {
            data.organization_id,
            data.name,
            data.label,
            data.weight,
            data.permissions_json,
            data.salary,
            data.color,
            data.icon,
        }
    )

    return {
        id = id,
    }
end

function Repository.DeleteRank(organizationId, name)
    local affectedRows = MySQL.update.await(
        [[
            DELETE
            FROM gs_organization_ranks
            WHERE organization_id = ?
              AND name = ?
        ]],
        {
            organizationId,
            name,
        }
    )

    return {
        affectedRows = affectedRows or 0,
    }
end

function Repository.GetRanks(organizationId)
    return MySQL.query.await(
        [[
            SELECT *
            FROM gs_organization_ranks
            WHERE organization_id = ?
            ORDER BY weight DESC, name ASC
        ]],
        {
            organizationId,
        }
    ) or {}
end

function Repository.UpdateRank(organizationId, name, data)
    local affectedRows = MySQL.update.await(
        [[
            UPDATE gs_organization_ranks
            SET
                label = ?,
                weight = ?,
                permissions_json = ?,
                salary = ?,
                color = ?,
                icon = ?
            WHERE organization_id = ?
              AND name = ?
        ]],
        {
            data.label,
            data.weight,
            data.permissions_json,
            data.salary,
            data.color,
            data.icon,
            organizationId,
            name,
        }
    )

    return {
        affectedRows = affectedRows or 0,
    }
end
