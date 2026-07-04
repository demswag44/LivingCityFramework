---------------------------------------------------------------------
-- GS Organizations
--
-- File: permissions.lua
-- Purpose:
--     Role Based Access Control (RBAC)
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Module
---------------------------------------------------------------------

local Security = GSOrganizations.Security

local Organization = GSOrganizations.Manager

local Logger = exports["gs_core"]:Logger()

---------------------------------------------------------------------
-- Has Permission
---------------------------------------------------------------------

function Security.HasPermission(
    organizationId,
    memberId,
    permission
)

    local member =
        Organization.GetMember(
            organizationId,
            memberId
        )

    if not member then
        return false
    end

    if not member.RankData then
        return false
    end

    if not member.RankData.Permissions then
        return false
    end

    return member.RankData.Permissions[permission] == true

end

---------------------------------------------------------------------
-- Require
---------------------------------------------------------------------

function Security.Require(
    organizationId,
    memberId,
    permission
)

    if Security.HasPermission(
        organizationId,
        memberId,
        permission
    ) then

        return true

    end

    return false, "Insufficient permissions."

end

---------------------------------------------------------------------
-- Has Any
---------------------------------------------------------------------

function Security.HasAny(
    organizationId,
    memberId,
    permissions
)

    for _, permission in ipairs(permissions) do

        if Security.HasPermission(
            organizationId,
            memberId,
            permission
        ) then

            return true

        end

    end

    return false

end

---------------------------------------------------------------------
-- Has All
---------------------------------------------------------------------

function Security.HasAll(
    organizationId,
    memberId,
    permissions
)

    for _, permission in ipairs(permissions) do

        if not Security.HasPermission(
            organizationId,
            memberId,
            permission
        ) then

            return false

        end

    end

    return true

end

---------------------------------------------------------------------
-- Get Permissions
---------------------------------------------------------------------

function Security.GetPermissions(
    organizationId,
    memberId
)

    local member =
        Organization.GetMember(
            organizationId,
            memberId
        )

    if not member then
        return {}
    end

    return member.RankData.Permissions or {}

end

---------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------

function Security.PrintPermissions(
    organizationId,
    memberId
)

    local permissions =
        Security.GetPermissions(
            organizationId,
            memberId
        )

    Logger.Info(
        "SECURITY",
        "Permissions:"
    )

    for permission in pairs(permissions) do

        Logger.Info(
            "SECURITY",
            permission
        )

    end

end