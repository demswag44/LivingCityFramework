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

local function EncodePermissions(value)
    if type(value) == "string" then
        return value
    end

    return json.encode(value or {})
end

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
            data.label or data.name,
            data.weight,
            EncodePermissions(data.permissions_json or data.permissions),
            data.salary or 0,
            data.color,
            data.icon,
        }
    )

    return {
        id = id,
    }
end

function Repository.GetRank(organizationId, name)
    return MySQL.single.await(
        [[
            SELECT *
            FROM gs_organization_ranks
            WHERE organization_id = ?
              AND name = ?
        ]],
        {
            organizationId,
            name,
        }
    )
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

function Repository.DeleteOrganizationRanks(organizationId)
    local affectedRows = MySQL.update.await(
        [[
            DELETE
            FROM gs_organization_ranks
            WHERE organization_id = ?
        ]],
        {
            organizationId,
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
                name = ?,
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
            data.name or name,
            data.label or data.name or name,
            data.weight,
            EncodePermissions(data.permissions_json or data.permissions),
            data.salary or 0,
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
