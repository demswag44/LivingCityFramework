---------------------------------------------------------------------
-- GS Organizations
--
-- File: load.lua
-- Purpose:
--     Organization Runtime Loader
---------------------------------------------------------------------

---------------------------------------------------------------------
-- GS Core
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

local Organization = GSOrganizations.Manager

---------------------------------------------------------------------
-- Load Organization
---------------------------------------------------------------------

function Organization.Load(row)

    --------------------------------------------------
    -- Validate
    --------------------------------------------------

    if not row then

        Logger.Error(
            "ORGANIZATIONS",
            "Attempted to load a nil organization row."
        )

        return nil

    end

    --------------------------------------------------
    -- Organization Object
    --------------------------------------------------

    local organization = {

        --------------------------------------------------
        -- Identity
        --------------------------------------------------

        Id = row.id,

        Name = row.name,

        Tag = row.tag or "",

        Type = row.type,

        Description = row.description or "",

        --------------------------------------------------
        -- Leadership
        --------------------------------------------------

        Founder = row.founder,

        Leader = row.leader,

        --------------------------------------------------
        -- Members
        --------------------------------------------------

        Members = {},

        Invites = {},

        --------------------------------------------------
        -- Territory
        --------------------------------------------------

        Territories = {},

        --------------------------------------------------
        -- Businesses
        --------------------------------------------------

        Businesses = {},

        --------------------------------------------------
        -- Economy
        --------------------------------------------------

        Treasury = row.treasury or 0,

        Income = row.income or 0,

        Expenses = row.expenses or 0,

        --------------------------------------------------
        -- Reputation
        --------------------------------------------------

        Reputation = row.reputation or 0,

        Influence = row.influence or 0,

        Heat = row.heat or 0,

        --------------------------------------------------
        -- AI
        --------------------------------------------------

        AIControlled = row.ai_controlled == 1,

        --------------------------------------------------
        -- Relationships
        --------------------------------------------------

        Allies = {},

        Rivals = {},

        Neutral = {},

        --------------------------------------------------
        -- Metadata
        --------------------------------------------------

        Created = row.created_at,

        LastUpdated = row.updated_at

    }

    --------------------------------------------------
    -- Register Runtime
    --------------------------------------------------

    Organization.Register(
        organization
    )

    --------------------------------------------------
    -- Synchronize Runtime ID Counter
    --------------------------------------------------

    if organization.Id >= Organization.NextId then

        Organization.NextId = organization.Id + 1

    end

    --------------------------------------------------
    -- Fire Event
    --------------------------------------------------

    if GSOrganizations.Events
    and GSOrganizations.Events.OrganizationLoaded then

        GSOrganizations.Events.OrganizationLoaded(
            organization
        )

    end

    --------------------------------------------------
    -- Log
    --------------------------------------------------

    Logger.Info(

        "ORGANIZATIONS",

        ("Loaded Organization: %s (#%d)")
            :format(
                organization.Name,
                organization.Id
            )

    )

    return organization

end

---------------------------------------------------------------------
-- Load All Organizations
---------------------------------------------------------------------

function Organization.LoadAll(rows)

    if not rows then
        return 0
    end

    local loaded = 0

    for _, row in ipairs(rows) do

        if Organization.Load(row) then

            loaded = loaded + 1

        end

    end

    Logger.Success(

        "ORGANIZATIONS",

        ("%d organization(s) loaded into runtime.")
            :format(loaded)

    )

    return loaded

end

---------------------------------------------------------------------
-- Export
---------------------------------------------------------------------

return Organization