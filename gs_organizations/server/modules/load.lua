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

local Config = GS.OrganizationConfig

local Organization = GSOrganizations.Manager
local MembersRepository = GSOrganizations.Repository.Members
local InvitesRepository = GSOrganizations.Repository.Invites

local function GetRanks()
    return GSOrganizations.Ranks
end

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

        PrimaryColor = row.primary_color or "#D4AF37",

        SecondaryColor = row.secondary_color or "#111111",

        Icon = row.icon or "",

        --------------------------------------------------
        -- Leadership
        --------------------------------------------------

        Founder = row.founder,

        Leader = row.leader,

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
-- Load Members
---------------------------------------------------------------------

function Organization.LoadMembers(organization)

    if not organization
    or not organization.Id then
        return 0
    end

    local rows =
        MembersRepository.GetMembers(
            organization.Id
        )

    local loaded = 0

    organization.Members = {}

    for _, row in ipairs(rows) do

        local rank =
            row.rank or "Member"

        local Ranks =
            GetRanks()

        local rankData =
            Ranks.GetRankData(
                organization.Id,
                rank
            )

        if not rankData then
            rank =
                Ranks.GetJoinRankName(
                    organization.Id
                )

            rankData =
                Ranks.GetRankData(
                    organization.Id,
                    rank
                )
                or Ranks.GetDefaultRankData(rank)

            MembersRepository.UpdateMemberRank(
                organization.Id,
                row.member_id,
                rank
            )
        end

        organization.Members[row.member_id] = {

            Id = row.member_id,

            Rank = rank,

            RankData = rankData,

            Joined = row.joined_at,

            LastUpdated = row.updated_at

        }

        loaded = loaded + 1

    end

    return loaded

end

---------------------------------------------------------------------
-- Load Invites
---------------------------------------------------------------------

function Organization.LoadInvites(organization)

    if not organization
    or not organization.Id then
        return 0
    end

    local rows =
        InvitesRepository.GetPendingInvites(
            organization.Id
        )

    local loaded = 0

    organization.Invites = {}

    for _, row in ipairs(rows) do

        organization.Invites[row.receiver_id] = {

            Id = row.id,

            MemberId = row.receiver_id,

            SenderId = row.sender_id,

            Status = row.status,

            Invited = row.created_at,

            ExpiresAt = row.expires_at,

            LastUpdated = row.updated_at

        }

        loaded = loaded + 1

    end

    return loaded

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

        local organization =
            Organization.Load(row)

        if organization then

            local Ranks =
                GetRanks()

            Ranks.LoadForOrganization(
                organization
            )

            Organization.LoadMembers(
                organization
            )

            Organization.LoadInvites(
                organization
            )

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
