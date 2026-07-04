---------------------------------------------------------------------
-- GS Organizations
--
-- File: hierarchy.lua
-- Purpose:
--     Rank Hierarchy Engine
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------

local Security = GSOrganizations.Security

local Organization = GSOrganizations.Manager

local Logger = exports["gs_core"]:Logger()

---------------------------------------------------------------------
-- Get Weight
---------------------------------------------------------------------

function Security.GetRankWeight(
    organizationId,
    memberId
)

    local member =
        Organization.GetMember(
            organizationId,
            memberId
        )

    if not member then
        return 0
    end

    if not member.RankData then
        return 0
    end

    return member.RankData.Weight or 0

end

---------------------------------------------------------------------
-- Compare Ranks
---------------------------------------------------------------------

function Security.CompareRanks(
    organizationId,
    actorId,
    targetId
)

    local actorWeight =
        Security.GetRankWeight(
            organizationId,
            actorId
        )

    local targetWeight =
        Security.GetRankWeight(
            organizationId,
            targetId
        )

    if actorWeight > targetWeight then
        return 1
    end

    if actorWeight < targetWeight then
        return -1
    end

    return 0

end

---------------------------------------------------------------------
-- Higher Than
---------------------------------------------------------------------

function Security.IsHigher(
    organizationId,
    actorId,
    targetId
)

    return Security.CompareRanks(
        organizationId,
        actorId,
        targetId
    ) == 1

end

---------------------------------------------------------------------
-- Lower Than
---------------------------------------------------------------------

function Security.IsLower(
    organizationId,
    actorId,
    targetId
)

    return Security.CompareRanks(
        organizationId,
        actorId,
        targetId
    ) == -1

end

---------------------------------------------------------------------
-- Equal Rank
---------------------------------------------------------------------

function Security.IsEqual(
    organizationId,
    actorId,
    targetId
)

    return Security.CompareRanks(
        organizationId,
        actorId,
        targetId
    ) == 0

end

---------------------------------------------------------------------
-- Can Manage Member
---------------------------------------------------------------------

function Security.CanManageMember(
    organizationId,
    actorId,
    targetId
)

    if not Security.IsHigher(
        organizationId,
        actorId,
        targetId
    ) then

        return false,
            "You cannot manage a member of equal or higher rank."

    end

    return true

end

---------------------------------------------------------------------
-- Can Promote
---------------------------------------------------------------------

function Security.CanPromote(
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

---------------------------------------------------------------------
-- Can Demote
---------------------------------------------------------------------

function Security.CanDemote(
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

---------------------------------------------------------------------
-- Can Kick
---------------------------------------------------------------------

function Security.CanKick(
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

---------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------

function Security.PrintHierarchy(
    organizationId,
    actorId,
    targetId
)

    Logger.Info(
        "SECURITY",
        ("Actor Weight: %d")
            :format(
                Security.GetRankWeight(
                    organizationId,
                    actorId
                )
            )
    )

    Logger.Info(
        "SECURITY",
        ("Target Weight: %d")
            :format(
                Security.GetRankWeight(
                    organizationId,
                    targetId
                )
            )
    )

end