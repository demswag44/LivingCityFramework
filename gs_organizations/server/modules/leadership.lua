---------------------------------------------------------------------
-- GS Organizations
--
-- File: leadership.lua
-- Purpose:
--     Organization Leadership Management
---------------------------------------------------------------------

---------------------------------------------------------------------
-- GS Core
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

local Organization = GSOrganizations.Manager

---------------------------------------------------------------------
-- Set Leader
---------------------------------------------------------------------

function Organization.SetLeader(id, memberId)

    local organization = Organization.Get(id)

    if not organization then
        return false, "Organization not found."
    end

    local member = Organization.GetMember(id, memberId)

    if not member then
        return false, "Member not found."
    end

    local success, reason = Organization.SetRank(
        id,
        memberId,
        "Leader"
    )

    if not success then
        return false, reason
    end

    organization.Leader = memberId

    organization.LastUpdated = os.time()

    Logger.Info(
        "ORGANIZATIONS",
        ("Leader of %s set to %s")
            :format(
                organization.Name,
                memberId
            )
    )

    return true

end

---------------------------------------------------------------------
-- Transfer Leadership
---------------------------------------------------------------------

function Organization.TransferLeadership(id, fromMemberId, toMemberId)

    local organization = Organization.Get(id)

    if not organization then
        return false, "Organization not found."
    end

    if organization.Leader ~= fromMemberId then
        return false, "Only the current leader may transfer leadership."
    end

    local success, reason = Organization.SetLeader(
        id,
        toMemberId
    )

    if not success then
        return false, reason
    end

    Organization.SetRank(
        id,
        fromMemberId,
        "Member"
    )

    Logger.Info(
        "ORGANIZATIONS",
        ("Leadership transferred from %s to %s in %s")
            :format(
                fromMemberId,
                toMemberId,
                organization.Name
            )
    )

    return true

end

---------------------------------------------------------------------
-- Is Leader
---------------------------------------------------------------------

function Organization.IsLeader(id, memberId)

    local organization = Organization.Get(id)

    if not organization then
        return false
    end

    return organization.Leader == memberId

end

---------------------------------------------------------------------
-- Export
---------------------------------------------------------------------

return Organization