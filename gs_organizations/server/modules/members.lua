---------------------------------------------------------------------
-- GS Organizations
--
-- File: members.lua
-- Purpose:
--     Organization Member Management
---------------------------------------------------------------------

---------------------------------------------------------------------
-- GS Core
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

local Config = GS.OrganizationConfig

local Organization = GSOrganizations.Manager

local Security = GSOrganizations.Security

local Events = GSOrganizations.Events

local MembersRepository = GSOrganizations.Repository.Members
local Ranks = GSOrganizations.Ranks

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------

local function ValidateOrganization(organizationId)

    return Security.ValidateOrganization(
        organizationId
    )

end

local function RequirePermission(
    organizationId,
    actorId,
    permission
)

    return Security.Require(

        organizationId,

        actorId,

        permission

    )

end

local function CanManage(
    organizationId,
    actorId,
    targetId
)

    return Security.CanManageMember(

        organizationId,

        actorId,

        targetId

    )

end

local function Audit(
    action,
    data
)

    Security.Audit.Write(
        action,
        data
    )

end

---------------------------------------------------------------------
-- Add Member
---------------------------------------------------------------------

function Organization.AddMember(

    organizationId,

    actorId,

    memberId

)

    --------------------------------------------------
    -- Validation
    --------------------------------------------------

    local success, organization =
        ValidateOrganization(
            organizationId
        )

    if not success then
        return false, organization
    end

    --------------------------------------------------
    -- Permission
    --------------------------------------------------

    success, reason =
        RequirePermission(

            organizationId,

            actorId,

            GS.OrganizationPermissions.INVITE_MEMBER

        )

    if not success then
        return false, reason
    end

    --------------------------------------------------
    -- Duplicate Check
    --------------------------------------------------

    if organization.Members[memberId] then
        return false,
            "Member already exists."
    end

    --------------------------------------------------
    -- Persist
    --------------------------------------------------

    local joinRank =
        Ranks.GetJoinRankName(
            organizationId
        )

    local result =
        MembersRepository.AddMember(
            {
                organization_id = organizationId,
                member_id = memberId,
                rank = joinRank
            }
        )

    if not result
    or not result.id then
        return false,
            "Failed to persist member."
    end

    --------------------------------------------------
    -- Create Member
    --------------------------------------------------

    organization.Members[memberId] = {

        Id = memberId,

        Rank = joinRank,

        RankData =
            Ranks.GetRankData(
                organizationId,
                joinRank
            )
            or Ranks.GetDefaultRankData(joinRank),

        Joined = os.time(),

        LastUpdated = os.time()

    }

    organization.LastUpdated = os.time()

    --------------------------------------------------
    -- Audit
    --------------------------------------------------

    Audit(

        "Member Added",

        {

            Organization = organizationId,

            Actor = actorId,

            Target = memberId

        }

    )

    --------------------------------------------------
    -- Event
    --------------------------------------------------

    if Events
    and Events.MemberAdded then

        Events.MemberAdded(

            organizationId,

            memberId

        )

    end

    --------------------------------------------------
    -- Log
    --------------------------------------------------

    Logger.Info(

        "ORGANIZATIONS",

        ("Member %s joined %s")

            :format(

                memberId,

                organization.Name

            )

    )

    return true

end

---------------------------------------------------------------------
-- Remove Member
---------------------------------------------------------------------

function Organization.RemoveMember(

    organizationId,

    actorId,

    memberId

)

    --------------------------------------------------
    -- Validation
    --------------------------------------------------

    local success, organization =
        ValidateOrganization(
            organizationId
        )

    if not success then
        return false, organization
    end

    --------------------------------------------------
    -- Permission
    --------------------------------------------------

    local success, reason =
        RequirePermission(

            organizationId,

            actorId,

            GS.OrganizationPermissions.REMOVE_MEMBER

        )

    if not success then
        return false, reason
    end

    --------------------------------------------------
    -- Hierarchy
    --------------------------------------------------

    success, reason =
        CanManage(

            organizationId,

            actorId,

            memberId

        )

    if not success then
        return false, reason
    end

    --------------------------------------------------
    -- Exists
    --------------------------------------------------

    if not organization.Members[memberId] then
        return false,
            "Member not found."
    end

    Organization.AddActivity(
        organizationId,
        memberId,
        memberId,
        "join",
        "Member joined",
        ("Player %s joined the organization."):format(tostring(memberId)),
        {
            Actor = actorId,
            Target = memberId,
            Rank = joinRank,
        }
    )

    --------------------------------------------------
    -- Persist
    --------------------------------------------------

    MembersRepository.RemoveMember(
        organizationId,
        memberId
    )

    --------------------------------------------------
    -- Remove
    --------------------------------------------------

    organization.Members[memberId] = nil

    organization.LastUpdated = os.time()

    --------------------------------------------------
    -- Audit
    --------------------------------------------------

    Audit(

        "Member Removed",

        {

            Organization = organizationId,

            Actor = actorId,

            Target = memberId

        }

    )

    --------------------------------------------------
    -- Event
    --------------------------------------------------

    if Events
    and Events.MemberRemoved then

        Events.MemberRemoved(

            organizationId,

            memberId

        )

    end

    --------------------------------------------------
    -- Log
    --------------------------------------------------

    Logger.Info(

        "ORGANIZATIONS",

        ("Member %s removed from %s")

            :format(

                memberId,

                organization.Name

            )

    )

    return true

end

---------------------------------------------------------------------
-- Kick Member
---------------------------------------------------------------------

function Organization.KickMember(

    organizationId,

    actorId,

    memberId

)

    --------------------------------------------------
    -- Validation
    --------------------------------------------------

    local success, organization =
        ValidateOrganization(
            organizationId
        )

    if not success then
        return false, organization
    end

    --------------------------------------------------
    -- Cannot Kick Leader
    --------------------------------------------------

    if organization.Leader == memberId then

        return false,
            "Cannot kick the organization leader."

    end

    --------------------------------------------------
    -- Permission
    --------------------------------------------------

    success, reason =
        RequirePermission(

            organizationId,

            actorId,

            GS.OrganizationPermissions.KICK_MEMBER

        )

    if not success then
        return false, reason
    end

    --------------------------------------------------
    -- Hierarchy
    --------------------------------------------------

    success, reason =
        CanManage(

            organizationId,

            actorId,

            memberId

        )

    if not success then
        return false, reason
    end

    --------------------------------------------------
    -- Remove Member
    --------------------------------------------------

    success, reason =
        Organization.RemoveMember(

            organizationId,

            actorId,

            memberId

        )

    if not success then
        return false, reason
    end

    --------------------------------------------------
    -- Audit
    --------------------------------------------------

    Audit(

        "Member Kicked",

        {

            Organization = organizationId,

            Actor = actorId,

            Target = memberId

        }

    )

    --------------------------------------------------
    -- Log
    --------------------------------------------------

    Logger.Warning(

        "ORGANIZATIONS",

        ("Member %s kicked from %s")

            :format(

                memberId,

                organization.Name

            )

    )

    Organization.AddActivity(
        organizationId,
        actorId,
        actorId,
        "kick",
        "Member kicked",
        ("Player %s was kicked."):format(tostring(memberId)),
        {
            Target = memberId,
        }
    )

    return true

end

---------------------------------------------------------------------
-- Leave Organization
---------------------------------------------------------------------

function Organization.LeaveOrganization(

    organizationId,

    memberId

)

    --------------------------------------------------
    -- Validation
    --------------------------------------------------

    local success, organization =
        ValidateOrganization(
            organizationId
        )

    if not success then
        return false, organization
    end

    --------------------------------------------------
    -- Leader Check
    --------------------------------------------------

    if organization.Leader == memberId then

        return false,
            "Leader must transfer leadership before leaving."

    end

    --------------------------------------------------
    -- Exists
    --------------------------------------------------

    if not organization.Members[memberId] then

        return false,
            "Member not found."

    end

    --------------------------------------------------
    -- Persist
    --------------------------------------------------

    MembersRepository.RemoveMember(
        organizationId,
        memberId
    )

    --------------------------------------------------
    -- Remove
    --------------------------------------------------

    organization.Members[memberId] = nil

    organization.LastUpdated = os.time()

    Organization.AddActivity(
        organizationId,
        memberId,
        memberId,
        "leave",
        "Member left",
        ("Player %s left the organization."):format(tostring(memberId)),
        {
            Target = memberId,
        }
    )

    --------------------------------------------------
    -- Audit
    --------------------------------------------------

    Audit(

        "Member Left",

        {

            Organization = organizationId,

            Target = memberId

        }

    )

    --------------------------------------------------
    -- Event
    --------------------------------------------------

    if Events
    and Events.MemberRemoved then

        Events.MemberRemoved(

            organizationId,

            memberId

        )

    end

    --------------------------------------------------
    -- Log
    --------------------------------------------------

    Logger.Info(

        "ORGANIZATIONS",

        ("Member %s left %s")

            :format(

                memberId,

                organization.Name

            )

    )

    return true

end

---------------------------------------------------------------------
-- Get Member
---------------------------------------------------------------------

function Organization.GetMember(

    organizationId,

    memberId

)

    local organization =
        Organization.Get(
            organizationId
        )

    if not organization then
        return nil
    end

    return organization.Members[memberId]

end

---------------------------------------------------------------------
-- Get Members
---------------------------------------------------------------------

function Organization.GetMembers(

    organizationId

)

    local organization =
        Organization.Get(
            organizationId
        )

    if not organization then
        return {}
    end

    return organization.Members

end

---------------------------------------------------------------------
-- Get Member Count
---------------------------------------------------------------------

function Organization.GetMemberCount(

    organizationId

)

    local organization =
        Organization.Get(
            organizationId
        )

    if not organization then
        return 0
    end

    local count = 0

    for _ in pairs(
        organization.Members
    ) do

        count = count + 1

    end

    return count

end

---------------------------------------------------------------------
-- Is Member
---------------------------------------------------------------------

function Organization.IsMember(

    organizationId,

    memberId

)

    local organization =
        Organization.Get(
            organizationId
        )

    if not organization then
        return false
    end

    return organization.Members[memberId] ~= nil

end

---------------------------------------------------------------------
-- Has Members
---------------------------------------------------------------------

function Organization.HasMembers(

    organizationId

)

    return Organization.GetMemberCount(
        organizationId
    ) > 0

end

---------------------------------------------------------------------
-- Find Member
---------------------------------------------------------------------

function Organization.FindMember(

    memberId

)

    for organizationId, organization in pairs(
        Organization.List
    ) do

        if organization.Members
        and organization.Members[memberId] then

            return organizationId,
                   organization

        end

    end

    return nil

end

---------------------------------------------------------------------
-- Member Rank
---------------------------------------------------------------------

function Organization.GetMemberRank(

    organizationId,

    memberId

)

    local member =
        Organization.GetMember(

            organizationId,

            memberId

        )

    if not member then
        return nil
    end

    return member.Rank

end

---------------------------------------------------------------------
-- Member Rank Data
---------------------------------------------------------------------

function Organization.GetMemberRankData(

    organizationId,

    memberId

)

    local member =
        Organization.GetMember(

            organizationId,

            memberId

        )

    if not member then
        return nil
    end

    return member.RankData

end

---------------------------------------------------------------------
-- Export
---------------------------------------------------------------------

return Organization
