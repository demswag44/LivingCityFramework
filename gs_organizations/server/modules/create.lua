---------------------------------------------------------------------
-- GS Organizations
--
-- File: create.lua
-- Purpose:
--     Organization Creation
---------------------------------------------------------------------

---------------------------------------------------------------------
-- GS Core
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

local Config = GS.OrganizationConfig

local Organization = GSOrganizations.Manager

---------------------------------------------------------------------
-- Create Organization
---------------------------------------------------------------------

function Organization.Create(data)

    --------------------------------------------------
    -- Validate
    --------------------------------------------------

    local valid, reason = Organization.Validate(data)

    if not valid then
        return nil, reason
    end

    local founderId = data.Founder

    if not founderId or founderId == "" then
        return nil, "Organization founder is required."
    end

    local createdAt = os.time()

    --------------------------------------------------
    -- Temporary Runtime ID
    --
    -- This will eventually be removed once
    -- MySQL becomes the single source of IDs.
    --------------------------------------------------

    local id = Organization.NextId

    Organization.NextId = Organization.NextId + 1

    --------------------------------------------------
    -- Organization Object
    --------------------------------------------------

    local organization = {

        --------------------------------------------------
        -- Identity
        --------------------------------------------------

        Id = id,

        Name = data.Name,

        Tag = data.Tag or "",

        Type = data.Type,

        Description = data.Description or "",

        --------------------------------------------------
        -- Leadership
        --------------------------------------------------

        Founder = founderId,

        Leader = founderId,

        --------------------------------------------------
        -- Members
        --------------------------------------------------

        Members = {

            [founderId] = {

                Id = founderId,

                Rank = "Leader",

                RankData = Config.DefaultRanks.Leader,

                Joined = createdAt,

                LastUpdated = createdAt

            }

        },

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

        Treasury = 0,

        Income = 0,

        Expenses = 0,

        --------------------------------------------------
        -- Reputation
        --------------------------------------------------

        Reputation = 0,

        Influence = 0,

        Heat = 0,

        --------------------------------------------------
        -- AI
        --------------------------------------------------

        AIControlled = false,

        --------------------------------------------------
        -- Relationships
        --------------------------------------------------

        Allies = {},

        Rivals = {},

        Neutral = {},

        --------------------------------------------------
        -- Metadata
        --------------------------------------------------

        Created = createdAt,

        LastUpdated = createdAt

    }

    --------------------------------------------------
    -- Register Runtime
    --------------------------------------------------

    Organization.Register(
        organization
    )

    --------------------------------------------------
    -- Persist Database
    --------------------------------------------------

    GSOrganizations.Database.Create(

        organization,

        function(insertId)

            if insertId then

                --------------------------------------------------
                -- Replace Temporary Runtime ID
                --------------------------------------------------

                Organization.Unregister(
                    organization.Id
                )

                organization.Id = insertId

                Organization.Register(
                    organization
                )

                if insertId >= Organization.NextId then

                    Organization.NextId = insertId + 1

                end

                Logger.Success(

                    "ORGANIZATIONS",

                    ("Organization persisted (#%d)")
                        :format(insertId)

                )

            else

                Logger.Error(

                    "ORGANIZATIONS",

                    ("Failed to persist organization: %s")
                        :format(organization.Name)

                )

            end

        end

    )

    --------------------------------------------------
    -- Event
    --------------------------------------------------

    if GSOrganizations.Events
    and GSOrganizations.Events.OrganizationCreated then

        GSOrganizations.Events.OrganizationCreated(
            organization
        )

    end

    --------------------------------------------------
    -- Log
    --------------------------------------------------

    Logger.Info(

        "ORGANIZATIONS",

        ("Organization Created: %s")
            :format(
                organization.Name
            )

    )

    return organization

end

---------------------------------------------------------------------
-- Export
---------------------------------------------------------------------

return Organization
