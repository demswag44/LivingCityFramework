---------------------------------------------------------------------
-- GS Organizations
--
-- File: database.lua
-- Purpose:
--     Organization Database Manager
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Module
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Database = GSOrganizations.Database or {}

local Database = GSOrganizations.Database

---------------------------------------------------------------------
-- GS Core
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()
local CoreDatabase = exports["gs_core"]:Database()

---------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------

function Database.Initialize()

    Logger.Info(
        "ORGANIZATIONS",
        "Organization Database Initialized"
    )

    Logger.Success(
        "ORGANIZATIONS",
        "Database Ready"
    )

    return true

end

---------------------------------------------------------------------
-- Load All Organizations
---------------------------------------------------------------------

function Database.LoadAll(callback)

    CoreDatabase.Query(
        [[
            SELECT *
            FROM gs_organizations
            ORDER BY id
        ]],
        {},
        function(result)

            Logger.Info(
                "ORGANIZATIONS",
                ("Loaded %d organization(s) from database.")
                    :format(#result)
            )

            if callback then
                callback(result)
            end

        end
    )

end

---------------------------------------------------------------------
-- Create Organization
---------------------------------------------------------------------

function Database.Create(organization, callback)

    CoreDatabase.Insert(
        [[
            INSERT INTO gs_organizations
            (
                name,
                tag,
                type,
                description,
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
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
        ]],
        {
            organization.Name,
            organization.Tag,
            organization.Type,
            organization.Description,
            organization.Founder,
            organization.Leader,
            organization.Treasury,
            organization.Income,
            organization.Expenses,
            organization.Reputation,
            organization.Influence,
            organization.Heat,
            organization.AIControlled and 1 or 0
        },
        function(insertId)

            if insertId then

                Logger.Success(
                    "ORGANIZATIONS",
                    ("Organization saved (ID: %d)")
                        :format(insertId)
                )

            else

                Logger.Error(
                    "ORGANIZATIONS",
                    "Failed to save organization."
                )

            end

            if callback then
                callback(insertId)
            end

        end
    )

end

---------------------------------------------------------------------
-- Update Organization
---------------------------------------------------------------------

function Database.Update(organization, callback)

    CoreDatabase.Update(
        [[
            UPDATE gs_organizations
            SET
                name = ?,
                tag = ?,
                type = ?,
                description = ?,
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
            organization.Name,
            organization.Tag,
            organization.Type,
            organization.Description,
            organization.Founder,
            organization.Leader,
            organization.Treasury,
            organization.Income,
            organization.Expenses,
            organization.Reputation,
            organization.Influence,
            organization.Heat,
            organization.AIControlled and 1 or 0,
            organization.Id
        },
        function(rows)

            if callback then
                callback(rows)
            end

        end
    )

end

---------------------------------------------------------------------
-- Delete Organization
---------------------------------------------------------------------

function Database.Delete(id, callback)

    CoreDatabase.Execute(
        [[
            DELETE
            FROM gs_organizations
            WHERE id = ?
        ]],
        {
            id
        },
        function(result)

            if callback then
                callback(result)
            end

        end
    )

end

---------------------------------------------------------------------
-- Export
---------------------------------------------------------------------

return Database