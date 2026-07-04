---------------------------------------------------------------------
-- GS Organizations
--
-- File: invites.lua
-- Purpose:
--     Organization Invitation Management
---------------------------------------------------------------------

---------------------------------------------------------------------
-- GS Core
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

local Organization = GSOrganizations.Manager
local InvitesRepository = GSOrganizations.Repository.Invites

---------------------------------------------------------------------
-- Invite Member
---------------------------------------------------------------------

function Organization.InviteMember(id, actorId, memberId)

    if not memberId then
        memberId = actorId
        actorId = nil
    end

    local organization = Organization.Get(id)

    if not organization then
        return false, "Organization not found."
    end

    if Organization.IsMember(id, memberId) then
        return false, "Player is already a member."
    end

    if organization.Invites[memberId] then
        return false, "Player already has a pending invitation."
    end

    local result =
        InvitesRepository.CreateInvite(
            {
                organization_id = id,
                sender_id = actorId,
                receiver_id = memberId,
                status = "pending",
                expires_at = nil
            }
        )

    if not result
    or not result.id then
        return false,
            "Failed to persist invitation."
    end

    organization.Invites[memberId] = {

        Id = result.id,

        MemberId = memberId,

        SenderId = actorId,

        Status = "pending",

        Invited = os.time()

    }

    organization.LastUpdated = os.time()

    Organization.AddActivity(
        id,
        actorId,
        actorId,
        "invite",
        "Member invited",
        ("Player %s was invited."):format(tostring(memberId)),
        {
            Target = memberId,
        }
    )

    Logger.Info(
        "ORGANIZATIONS",
        ("Player %s invited to %s")
            :format(memberId, organization.Name)
    )

    return true

end

---------------------------------------------------------------------
-- Accept Invite
---------------------------------------------------------------------

function Organization.AcceptInvite(id, actorId, memberId)

    local organization = Organization.Get(id)

    if not organization then
        return false, "Organization not found."
    end

    if not organization.Invites[memberId] then
        return false, "Invitation not found."
    end

    local invite =
        organization.Invites[memberId]

    InvitesRepository.AcceptInvite(
        invite.Id
    )

    organization.Invites[memberId] = nil

    local success, reason = Organization.AddMember(
        id,
        actorId,
        memberId
    )

    if not success then
        return false, reason
    end

    organization.LastUpdated = os.time()

    Logger.Info(
        "ORGANIZATIONS",
        ("Player %s accepted invitation to %s")
            :format(memberId, organization.Name)
    )

    return true

end

---------------------------------------------------------------------
-- Decline Invite
---------------------------------------------------------------------

function Organization.DeclineInvite(id, memberId)

    local organization = Organization.Get(id)

    if not organization then
        return false, "Organization not found."
    end

    if not organization.Invites[memberId] then
        return false, "Invitation not found."
    end

    local invite =
        organization.Invites[memberId]

    InvitesRepository.DeclineInvite(
        invite.Id
    )

    organization.Invites[memberId] = nil

    organization.LastUpdated = os.time()

    Logger.Info(
        "ORGANIZATIONS",
        ("Player %s declined invitation to %s")
            :format(memberId, organization.Name)
    )

    return true

end

---------------------------------------------------------------------
-- Revoke Invite
---------------------------------------------------------------------

function Organization.RevokeInvite(id, memberId)

    local organization = Organization.Get(id)

    if not organization then
        return false, "Organization not found."
    end

    if not organization.Invites[memberId] then
        return false, "Invitation not found."
    end

    local invite =
        organization.Invites[memberId]

    InvitesRepository.RevokeInvite(
        invite.Id
    )

    organization.Invites[memberId] = nil

    organization.LastUpdated = os.time()

    Logger.Info(
        "ORGANIZATIONS",
        ("Invitation revoked for %s in %s")
            :format(memberId, organization.Name)
    )

    return true

end

---------------------------------------------------------------------
-- Has Invite
---------------------------------------------------------------------

function Organization.HasInvite(id, memberId)

    local organization = Organization.Get(id)

    if not organization then
        return false
    end

    return organization.Invites[memberId] ~= nil

end

---------------------------------------------------------------------
-- Get Invites
---------------------------------------------------------------------

function Organization.GetInvites(id)

    local organization = Organization.Get(id)

    if not organization then
        return nil
    end

    return organization.Invites

end

---------------------------------------------------------------------
-- Export
---------------------------------------------------------------------

return Organization
