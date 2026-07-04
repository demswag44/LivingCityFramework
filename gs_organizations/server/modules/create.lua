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
local Repository = GSOrganizations.Repository.Organizations
local MembersRepository = GSOrganizations.Repository.Members
local Ranks = GSOrganizations.Ranks

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
    local templateName =
        Ranks.ResolveTemplateName(
            data.Template
            or data.Type
            or "Custom"
        )

    --------------------------------------------------
    -- Organization Object
    --------------------------------------------------

    local organization = {

        --------------------------------------------------
        -- Identity
        --------------------------------------------------

        Id = nil,

        Name = data.Name,

        Tag = data.Tag or "",

        Type = data.Type,

        Description = data.Description or "",

        PrimaryColor = data.PrimaryColor or "#D4AF37",

        SecondaryColor = data.SecondaryColor or "#111111",

        Icon = data.Icon or "",

        Template = templateName,

        --------------------------------------------------
        -- Leadership
        --------------------------------------------------

        Founder = founderId,

        Leader = founderId,

        --------------------------------------------------
        -- Members
        --------------------------------------------------

        Members = {},

        Ranks = {},

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
    -- Persist Database
    --------------------------------------------------

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

    if not result or not result.id then

        Logger.Error(

            "ORGANIZATIONS",

            ("Failed to persist organization: %s")
                :format(organization.Name)

        )

        return nil, "Failed to persist organization."

    end

    organization.Id = result.id

    Ranks.ResetToTemplate(
        organization.Id,
        templateName
    )

    Organization.AddActivity(
        organization.Id,
        founderId,
        founderId,
        "rank_template",
        "Rank template applied",
        ("Applied %s rank template."):format(tostring(templateName)),
        {
            Template = templateName,
        }
    )

    organization.Ranks =
        Ranks.List[organization.Id] or {}

    local founderRank =
        Ranks.GetTopTemplateRankName(
            templateName
        )

    organization.Members[founderId] = {

        Id = founderId,

        Rank = founderRank,

        RankData =
            Ranks.GetRankData(
                organization.Id,
                founderRank
            )
            or Ranks.GetDefaultRankData(founderRank),

        Joined = createdAt,

        LastUpdated = createdAt

    }

    local founderMember = organization.Members[founderId]

    local memberResult = MembersRepository.AddMember({
        organization_id = organization.Id,
        member_id = founderMember.Id,
        rank = founderMember.Rank
    })

    if not memberResult or not memberResult.id then

        Logger.Error(

            "ORGANIZATIONS",

            ("Failed to persist founder member for organization: %s")
                :format(organization.Name)

        )

        return nil, "Failed to persist founder member."

    end

    --------------------------------------------------
    -- Register Runtime
    --------------------------------------------------

    Organization.Register(
        organization
    )

    if organization.Id >= Organization.NextId then

        Organization.NextId = organization.Id + 1

    end

    Logger.Success(

        "ORGANIZATIONS",

        ("Organization persisted (#%d)")
            :format(organization.Id)

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

    Organization.AddActivity(
        organization.Id,
        founderId,
        founderId,
        "created",
        "Organization created",
        ("%s was created."):format(organization.Name),
        {
            Type = organization.Type,
            Template = templateName,
        }
    )

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
