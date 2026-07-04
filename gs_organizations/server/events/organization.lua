---------------------------------------------------------------------
-- GS Organizations
--
-- File: organization.lua
-- Purpose:
--     Organization Events
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Events = GSOrganizations.Events or {}

local Events = GSOrganizations.Events

---------------------------------------------------------------------
-- Organization Created
---------------------------------------------------------------------

function Events.OrganizationCreated(organization)

    TriggerEvent(
        "gs:organization:created",
        organization
    )

end

---------------------------------------------------------------------
-- Organization Deleted
---------------------------------------------------------------------

function Events.OrganizationDeleted(id)

    TriggerEvent(
        "gs:organization:deleted",
        id
    )

end

---------------------------------------------------------------------
-- Organization Loaded
---------------------------------------------------------------------

function Events.OrganizationLoaded(organization)

    TriggerEvent(
        "gs:organization:loaded",
        organization
    )

end

---------------------------------------------------------------------
-- Member Added
---------------------------------------------------------------------

function Events.MemberAdded(id, memberId)

    TriggerEvent(
        "gs:organization:memberAdded",
        id,
        memberId
    )

end

---------------------------------------------------------------------
-- Member Removed
---------------------------------------------------------------------

function Events.MemberRemoved(id, memberId)

    TriggerEvent(
        "gs:organization:memberRemoved",
        id,
        memberId
    )

end

---------------------------------------------------------------------
-- Member Rank Changed
---------------------------------------------------------------------

function Events.MemberRankChanged(id, memberId, rank)

    TriggerEvent(
        "gs:organization:memberRankChanged",
        id,
        memberId,
        rank
    )

end

---------------------------------------------------------------------
-- Leader Changed
---------------------------------------------------------------------

function Events.LeaderChanged(id, memberId)

    TriggerEvent(
        "gs:organization:leaderChanged",
        id,
        memberId
    )

end

---------------------------------------------------------------------
-- Invite Sent
---------------------------------------------------------------------

function Events.InviteSent(id, memberId)

    TriggerEvent(
        "gs:organization:inviteSent",
        id,
        memberId
    )

end

---------------------------------------------------------------------
-- Invite Accepted
---------------------------------------------------------------------

function Events.InviteAccepted(id, memberId)

    TriggerEvent(
        "gs:organization:inviteAccepted",
        id,
        memberId
    )

end

---------------------------------------------------------------------
-- Invite Declined
---------------------------------------------------------------------

function Events.InviteDeclined(id, memberId)

    TriggerEvent(
        "gs:organization:inviteDeclined",
        id,
        memberId
    )

end

function Events.TreasuryDeposited(id, actorId, amount, balance)

    TriggerEvent(
        "gs:organization:treasuryDeposited",
        id,
        actorId,
        amount,
        balance
    )

end

function Events.TreasuryWithdrawn(id, actorId, amount, balance)

    TriggerEvent(
        "gs:organization:treasuryWithdrawn",
        id,
        actorId,
        amount,
        balance
    )

end

function Events.TreasuryTransferred(
    fromId,
    toId,
    actorId,
    amount,
    fromBalance,
    toBalance
)

    TriggerEvent(
        "gs:organization:treasuryTransferred",
        fromId,
        toId,
        actorId,
        amount,
        fromBalance,
        toBalance
    )

end

function Events.TreasuryBalanceChanged(id, balance)

    TriggerEvent(
        "gs:organization:treasuryBalanceChanged",
        id,
        balance
    )

end

return Events
