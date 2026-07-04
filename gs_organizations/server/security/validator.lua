---------------------------------------------------------------------
-- GS Organizations
--
-- File: validator.lua
-- Purpose:
--     Security Validation Engine
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------

local Security = GSOrganizations.Security

local Organization = GSOrganizations.Manager

local Logger = exports["gs_core"]:Logger()

---------------------------------------------------------------------
-- Validate Organization
---------------------------------------------------------------------

function Security.ValidateOrganization(organizationId)

    local organization = Organization.Get(organizationId)

    if not organization then
        return false, "Organization does not exist."
    end

    return true, organization

end

---------------------------------------------------------------------
-- Validate Member
---------------------------------------------------------------------

function Security.ValidateMember(
    organizationId,
    memberId
)

    local organization = Organization.Get(organizationId)

    if not organization then
        return false, "Organization does not exist."
    end

    local member = organization.Members[memberId]

    if not member then
        return false, "Member not found."
    end

    return true, member

end

---------------------------------------------------------------------
-- Validate Rank
---------------------------------------------------------------------

function Security.ValidateRank(rank, organizationId)

    if organizationId then

        if not GSOrganizations.Ranks.GetRankData(
            organizationId,
            rank
        ) then
            return false, "Invalid rank."
        end

        return true

    end

    for _, organization in pairs(Organization.GetAll()) do

        if GSOrganizations.Ranks.GetRankData(
            organization.Id,
            rank
        ) then
            return true
        end

    end

    if GS.OrganizationConfig.DefaultRanks[rank] then
        return true
    end

    return false, "Invalid rank."

end

---------------------------------------------------------------------
-- Validate Permission
---------------------------------------------------------------------

function Security.ValidatePermission(permission)

    for _, value in pairs(GS.OrganizationPermissions) do

        if value == permission then
            return true
        end

    end

    return false, "Unknown permission."

end

---------------------------------------------------------------------
-- Validate Action
---------------------------------------------------------------------

function Security.ValidateAction(
    organizationId,
    actorId,
    permission
)

    local ok, result =
        Security.ValidateOrganization(
            organizationId
        )

    if not ok then
        return false, result
    end

    ok, result =
        Security.ValidateMember(
            organizationId,
            actorId
        )

    if not ok then
        return false, result
    end

    ok, result =
        Security.ValidatePermission(
            permission
        )

    if not ok then
        return false, result
    end

    return true

end

---------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------

function Security.PrintValidation()

    Logger.Info(
        "SECURITY",
        "Validator Ready"
    )

end
