---------------------------------------------------------------------
-- GS Organizations
--
-- File: organizations.lua
-- Purpose:
--     Organization repository persistence access
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Repository = GSOrganizations.Repository or {}
GSOrganizations.Repository.Organizations =
    GSOrganizations.Repository.Organizations or {}

local Repository = GSOrganizations.Repository.Organizations

function Repository.Create(data)
    local id = MySQL.insert.await(
        [[
            INSERT INTO gs_organizations
            (
                name,
                tag,
                type,
                description,
                primary_color,
                secondary_color,
                icon,
                founder,
                leader,
                treasury,
                income,
                expenses,
                reputation,
                influence,
                heat,
                ai_controlled
            )
            VALUES
            (
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
        ]],
        {
            data.name,
            data.tag,
            data.type,
            data.description,
            data.primary_color,
            data.secondary_color,
            data.icon,
            data.founder,
            data.leader,
            data.treasury,
            data.income,
            data.expenses,
            data.reputation,
            data.influence,
            data.heat,
            data.ai_controlled and 1 or 0,
        }
    )

    return {
        id = id,
    }
end

function Repository.GetById(id)
    return MySQL.single.await(
        [[
            SELECT *
            FROM gs_organizations
            WHERE id = ?
        ]],
        {
            id,
        }
    )
end

function Repository.GetByName(name)
    return MySQL.single.await(
        [[
            SELECT *
            FROM gs_organizations
            WHERE name = ?
        ]],
        {
            name,
        }
    )
end

function Repository.GetAll()
    return MySQL.query.await(
        [[
            SELECT *
            FROM gs_organizations
            ORDER BY id
        ]],
        {}
    ) or {}
end

function Repository.Update(id, data)
    local affectedRows = MySQL.update.await(
        [[
            UPDATE gs_organizations
            SET
                name = ?,
                tag = ?,
                type = ?,
                description = ?,
                primary_color = ?,
                secondary_color = ?,
                icon = ?,
                founder = ?,
                leader = ?,
                treasury = ?,
                income = ?,
                expenses = ?,
                reputation = ?,
                influence = ?,
                heat = ?,
                ai_controlled = ?
            WHERE id = ?
        ]],
        {
            data.name,
            data.tag,
            data.type,
            data.description,
            data.primary_color,
            data.secondary_color,
            data.icon,
            data.founder,
            data.leader,
            data.treasury,
            data.income,
            data.expenses,
            data.reputation,
            data.influence,
            data.heat,
            data.ai_controlled and 1 or 0,
            id,
        }
    )

    return {
        affectedRows = affectedRows or 0,
    }
end

function Repository.Delete(id)
    local affectedRows = MySQL.update.await(
        [[
            DELETE
            FROM gs_organizations
            WHERE id = ?
        ]],
        {
            id,
        }
    )

    return {
        affectedRows = affectedRows or 0,
    }
end
