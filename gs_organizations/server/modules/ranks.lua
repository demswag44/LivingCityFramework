---------------------------------------------------------------------
-- GS Organizations
--
-- File: ranks.lua
-- Purpose:
--     Organization Rank Management
---------------------------------------------------------------------

---------------------------------------------------------------------
-- GS Core
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

local Config = GS.OrganizationConfig

local Organization = GSOrganizations.Manager
local Ranks = GSOrganizations.Ranks
local MembersRepository = GSOrganizations.Repository.Members

---------------------------------------------------------------------
-- Get Rank
---------------------------------------------------------------------

function Organization.GetRank(id, memberId)

    local member = Organization.GetMember(id, memberId)

    if not member then
        return nil
    end

    return member.Rank

end

---------------------------------------------------------------------
-- Get Rank Data
---------------------------------------------------------------------

function Organization.GetRankData(id, memberId)

    local member = Organization.GetMember(id, memberId)

    if not member then
        return nil
    end

    return member.RankData

end

---------------------------------------------------------------------
-- Set Rank
---------------------------------------------------------------------

function Organization.SetRank(id, memberId, rank)

    local organization = Organization.Get(id)

    if not organization then
        return false, "Organization not found."
    end

    local member = Organization.GetMember(id, memberId)

    if not member then
        return false, "Member not found."
    end

    local rankData =
        Ranks.GetRankData(
            id,
            rank
        )

    if not rankData then
        return false,
            ("Invalid rank '%s'")
                :format(tostring(rank))
    end

    --------------------------------------------------
    -- Persist
    --------------------------------------------------

    local result =
        MembersRepository.UpdateMemberRank(
            id,
            memberId,
            rank
        )

    if not result
    or result.affectedRows < 1 then
        return false, "Failed to persist member rank."
    end

    --------------------------------------------------
    -- Update Rank
    --------------------------------------------------

    member.Rank = rank
    member.RankData = rankData

    member.LastUpdated = os.time()

    organization.LastUpdated = os.time()

    --------------------------------------------------
    -- Event
    --------------------------------------------------

    if GSOrganizations.Events
    and GSOrganizations.Events.MemberRankChanged then

        GSOrganizations.Events.MemberRankChanged(
            id,
            memberId,
            rank
        )

    end

    --------------------------------------------------
    -- Log
    --------------------------------------------------

    Logger.Info(

        "ORGANIZATIONS",

        ("Member %s promoted to %s in %s")
            :format(
                memberId,
                rank,
                organization.Name
            )

    )

    return true

end

---------------------------------------------------------------------
-- Promote Member
---------------------------------------------------------------------

function Organization.PromoteMember(id, memberId, rank)

    return Organization.SetRank(
        id,
        memberId,
        rank
    )

end

---------------------------------------------------------------------
-- Demote Member
---------------------------------------------------------------------

function Organization.DemoteMember(id, memberId, rank)

    return Organization.SetRank(
        id,
        memberId,
        rank
    )

end

---------------------------------------------------------------------
-- Is Rank
---------------------------------------------------------------------

function Organization.IsRank(id, memberId, rank)

    local member = Organization.GetMember(id, memberId)

    if not member then
        return false
    end

    return member.Rank == rank

end

---------------------------------------------------------------------
-- Is Leader
---------------------------------------------------------------------

function Organization.IsLeader(id, memberId)

    return Organization.IsRank(
        id,
        memberId,
        "Leader"
    )

end

---------------------------------------------------------------------
-- Is CoLeader
---------------------------------------------------------------------

function Organization.IsCoLeader(id, memberId)

    return Organization.IsRank(
        id,
        memberId,
        "CoLeader"
    )

end

---------------------------------------------------------------------
-- Is Officer
---------------------------------------------------------------------

function Organization.IsOfficer(id, memberId)

    return Organization.IsRank(
        id,
        memberId,
        "Officer"
    )

end

---------------------------------------------------------------------
-- Export
---------------------------------------------------------------------

return Organization
