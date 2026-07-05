---------------------------------------------------------------------
-- GS Organizations
--
-- File: territory_editor.lua
-- Purpose:
--     Territory editor persistence access
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Repository = GSOrganizations.Repository or {}
GSOrganizations.Repository.TerritoryEditor =
    GSOrganizations.Repository.TerritoryEditor or {}

local Repository =
    GSOrganizations.Repository.TerritoryEditor

local function Encode(value)
    if type(value) == "string" then
        return value
    end

    return json.encode(value or {})
end

local function DatabaseError(errorMessage)
    errorMessage =
        tostring(errorMessage or "database error.")

    if errorMessage:find("Duplicate entry", 1, true)
    or errorMessage:find("ER_DUP_ENTRY", 1, true) then
        return "Territory name already exists."
    end

    return "Territory database operation failed."
end

function Repository.CreateTerritory(data)
    local ok, id =
        pcall(function()
            return MySQL.insert.await(
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
                    Encode(data.polygon),
                    data.center_x,
                    data.center_y,
                    data.center_z,
                    data.influence,
                    data.heat,
                    data.income,
                    data.population,
                }
            )
        end)

    if not ok then
        return {
            error = DatabaseError(id),
        }
    end

    return {
        id = id,
    }
end

function Repository.UpdateTerritory(id, data)
    local ok, affectedRows =
        pcall(function()
            return MySQL.update.await(
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
                    Encode(data.polygon),
                    data.center_x,
                    data.center_y,
                    data.center_z,
                    data.influence,
                    data.heat,
                    data.income,
                    data.population,
                    id,
                }
            )
        end)

    if not ok then
        return {
            id = id,
            affectedRows = 0,
            error = DatabaseError(affectedRows),
        }
    end

    return {
        id = id,
        affectedRows = affectedRows or 0,
    }
end

function Repository.DeleteTerritory(id)
    local ok, affectedRows =
        pcall(function()
            return MySQL.update.await(
                [[
                    DELETE FROM organization_territories
                    WHERE id = ?
                ]],
                {
                    id,
                }
            )
        end)

    if not ok then
        return {
            affectedRows = 0,
            error = DatabaseError(affectedRows),
        }
    end

    return {
        affectedRows = affectedRows or 0,
    }
end

return Repository
