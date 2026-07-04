---------------------------------------------------------------------
-- GS Organizations
--
-- File: exports.lua
-- Purpose:
--     Security Public API
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------

local Security = GSOrganizations.Security

---------------------------------------------------------------------
-- Ready
---------------------------------------------------------------------

exports("SecurityReady", function()

    return Security.IsReady()

end)

---------------------------------------------------------------------
-- Permission
---------------------------------------------------------------------

exports("HasPermission", function(
    organizationId,
    memberId,
    permission
)

    return Security.HasPermission(
        organizationId,
        memberId,
        permission
    )

end)

exports("RequirePermission", function(
    organizationId,
    memberId,
    permission
)

    return Security.Require(
        organizationId,
        memberId,
        permission
    )

end)

---------------------------------------------------------------------
-- Hierarchy
---------------------------------------------------------------------

exports("CanManageMember", function(
    organizationId,
    actorId,
    targetId
)

    return Security.CanManageMember(
        organizationId,
        actorId,
        targetId
    )

end)

exports("CompareRanks", function(
    organizationId,
    actorId,
    targetId
)

    return Security.CompareRanks(
        organizationId,
        actorId,
        targetId
    )

end)

---------------------------------------------------------------------
-- Validation
---------------------------------------------------------------------

exports("ValidateAction", function(
    organizationId,
    actorId,
    permission
)

    return Security.ValidateAction(
        organizationId,
        actorId,
        permission
    )

end)

---------------------------------------------------------------------
-- Audit
---------------------------------------------------------------------

exports("AuditLog", function(
    action,
    data
)

    return Security.Audit.Write(
        action,
        data
    )

end)

---------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------

exports("PrintPermissions", function(
    organizationId,
    memberId
)

    Security.PrintPermissions(
        organizationId,
        memberId
    )

end)

exports("PrintHierarchy", function(
    organizationId,
    actorId,
    targetId
)

    Security.PrintHierarchy(
        organizationId,
        actorId,
        targetId
    )

end)