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

---------------------------------------------------------------------
-- Invite Member
---------------------------------------------------------------------

function Organization.InviteMember(id, memberId)

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

    organization.Invites[memberId] = {

        Id = memberId,

        Invited = os.time()

    }

    organization.LastUpdated = os.time()

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
