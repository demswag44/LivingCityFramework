---------------------------------------------------------------------
-- GS Organizations
--
-- File: territories.lua
-- Purpose:
--     Territory repository persistence access
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Repository = GSOrganizations.Repository or {}
GSOrganizations.Repository.Territories =
    GSOrganizations.Repository.Territories or {}

local Repository = GSOrganizations.Repository.Territories
local Logger = exports["gs_core"]:Logger()

Logger.Info(
    "TERRITORIES",
    "Repository Loaded"
)

local function EncodePolygon(polygon)
    if type(polygon) == "string" then
        return polygon
    end

    return json.encode(polygon or {})
end

function Repository.LoadTerritories()
    return MySQL.query.await(
        [[
            SELECT *
            FROM organization_territories
            ORDER BY name ASC
        ]],
        {}
    ) or {}
end

function Repository.GetTerritory(id)
    return MySQL.single.await(
        [[
            SELECT *
            FROM organization_territories
            WHERE id = ?
        ]],
        {
            id,
        }
    )
end

function Repository.GetTerritoryByName(name)
    return MySQL.single.await(
        [[
            SELECT *
            FROM organization_territories
            WHERE name = ?
        ]],
        {
            name,
        }
    )
end

function Repository.GetTerritoriesByOrganization(orgId)
    return MySQL.query.await(
        [[
            SELECT *
            FROM organization_territories
            WHERE owner_organization_id = ?
            ORDER BY name ASC
        ]],
        {
            orgId,
        }
    ) or {}
end

function Repository.SaveTerritory(data)
    if data.id then
        local affectedRows = MySQL.update.await(
            [[
                UPDATE organization_territories
                SET
                    name = ?,
                    description = ?,
                    owner_organization_id = ?,
                    color = ?,
                    polygon = ?,
                    center_x = ?,
                    center_y = ?,
                    center_z = ?,
                    influence = ?,
                    heat = ?,
                    income = ?,
                    population = ?
                WHERE id = ?
            ]],
            {
                data.name,
                data.description,
                data.owner_organization_id,
                data.color,
                EncodePolygon(data.polygon),
                data.center_x,
                data.center_y,
                data.center_z,
                data.influence,
                data.heat,
                data.income,
                data.population,
                data.id,
            }
        )

        return {
            id = data.id,
            affectedRows = affectedRows or 0,
        }
    end

    local id = MySQL.insert.await(
        [[
            INSERT INTO organization_territories
            (
                name,
                description,
                owner_organization_id,
                color,
                polygon,
                center_x,
                center_y,
                center_z,
                influence,
                heat,
                income,
                population
            )
            VALUES
            (
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
        ]],
        {
            data.name,
            data.description,
            data.owner_organization_id,
            data.color,
            EncodePolygon(data.polygon),
            data.center_x,
            data.center_y,
            data.center_z,
            data.influence,
            data.heat,
            data.income,
            data.population,
        }
    )

    return {
        id = id,
    }
end

function Repository.UpdateOwner(id, ownerOrganizationId)
    local affectedRows = MySQL.update.await(
        [[
            UPDATE organization_territories
            SET owner_organization_id = ?
            WHERE id = ?
        ]],
        {
            ownerOrganizationId,
            id,
        }
    )

    return {
        affectedRows = affectedRows or 0,
    }
end

function Repository.UpdateInfluence(id, influence)
    local affectedRows = MySQL.update.await(
        [[
            UPDATE organization_territories
            SET influence = ?
            WHERE id = ?
        ]],
        {
            influence,
            id,
        }
    )

    return {
        affectedRows = affectedRows or 0,
    }
end

function Repository.UpdateHeat(id, heat)
    local affectedRows = MySQL.update.await(
        [[
            UPDATE organization_territories
            SET heat = ?
            WHERE id = ?
        ]],
        {
            heat,
            id,
        }
    )

    return {
        affectedRows = affectedRows or 0,
    }
end

return Repository
