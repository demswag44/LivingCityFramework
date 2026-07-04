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
local Repository = GSOrganizations.Repository.Organizations

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

    local result = Repository.GetAll()

    Logger.Info(
        "ORGANIZATIONS",
        ("Loaded %d organization(s) from database.")
            :format(#result)
    )

    if callback then
        callback(result)
    end


end

---------------------------------------------------------------------
-- Create Organization
---------------------------------------------------------------------

function Database.Create(organization, callback)

    local result = Repository.Create({
        name = organization.Name,
        tag = organization.Tag,
        type = organization.Type,
        description = organization.Description,
        primary_color = organization.PrimaryColor,
        secondary_color = organization.SecondaryColor,
        icon = organization.Icon,
        founder = organization.Founder,
        leader = organization.Leader,
        treasury = organization.Treasury,
        income = organization.Income,
        expenses = organization.Expenses,
        reputation = organization.Reputation,
        influence = organization.Influence,
        heat = organization.Heat,
        ai_controlled = organization.AIControlled
    })

    if result and result.id then

        Logger.Success(
            "ORGANIZATIONS",
            ("Organization saved (ID: %d)")
                :format(result.id)
        )

    else

        Logger.Error(
            "ORGANIZATIONS",
            "Failed to save organization."
        )

    end

    if callback then
        callback(result and result.id or nil)
    end

end

---------------------------------------------------------------------
-- Update Organization
---------------------------------------------------------------------

function Database.Update(organization, callback)

    local result = Repository.Update(organization.Id, {
        name = organization.Name,
        tag = organization.Tag,
        type = organization.Type,
        description = organization.Description,
        primary_color = organization.PrimaryColor,
        secondary_color = organization.SecondaryColor,
        icon = organization.Icon,
        founder = organization.Founder,
        leader = organization.Leader,
        treasury = organization.Treasury,
        income = organization.Income,
        expenses = organization.Expenses,
        reputation = organization.Reputation,
        influence = organization.Influence,
        heat = organization.Heat,
        ai_controlled = organization.AIControlled
    })

    if callback then
        callback(result.affectedRows)
    end

end

---------------------------------------------------------------------
-- Delete Organization
---------------------------------------------------------------------

function Database.Delete(id, callback)

    local result = Repository.Delete(id)

    if callback then
        callback(result.affectedRows)
    end


end

---------------------------------------------------------------------
-- Export
---------------------------------------------------------------------

return Database
