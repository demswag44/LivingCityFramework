---------------------------------------------------------------------
-- GS Organizations
--
-- File: callbacks.lua
-- Purpose:
--     Server callbacks for Organization UI
---------------------------------------------------------------------

local UI = GSOrganizations.UI
local Organization = GSOrganizations.Manager

local function Trim(value)
    if type(value) ~= "string" then
        return value
    end

    return value:match("^%s*(.-)%s*$")
end

local function Error(message)
    return {
        success = false,
        message = message,
    }
end

local function GetFounderId(source)
    return tostring(source)
end

local function GetPlayerId(source)
    return tostring(source)
end

local function GetPlayerOrganization(playerId)
    local organizationId, organization =
        Organization.FindMember(
            playerId
        )

    return organizationId, organization
end

local function GetOldestPendingInvite(playerId)
    local oldestInvite = nil
    local oldestOrganizationId = nil

    for organizationId, organization in pairs(
        Organization.GetAll()
    ) do

        local invite =
            organization.Invites
            and organization.Invites[playerId]

        if invite then

            if not oldestInvite
            or tostring(invite.Invited) < tostring(oldestInvite.Invited) then
                oldestInvite = invite
                oldestOrganizationId = organizationId
            end

        end

    end

    return oldestOrganizationId, oldestInvite
end

lib.callback.register(UI.Callbacks.CreateOrganization, function(source, data)
    if type(data) ~= "table" then
        return Error("Invalid organization data.")
    end

    local name = Trim(data.Name)

    if not name or name == "" then
        return Error("Organization Name is required.")
    end

    if name:len() > UI.Config.MaxNameLength then
        return Error(
            ("Organization Name must be %d characters or fewer.")
                :format(UI.Config.MaxNameLength)
        )
    end

    if not data.Type or data.Type == "" then
        return Error("Organization Type is required.")
    end

    if not UI.IsHexColor(data.PrimaryColor) then
        return Error("Primary Color is required.")
    end

    if not UI.IsHexColor(data.SecondaryColor) then
        return Error("Secondary Color is required.")
    end

    if Organization.NameExists(name) then
        return Error("Organization name already exists.")
    end

    local organization, reason = Organization.Create({
        Name = name,
        Type = data.Type,
        Description = Trim(data.Description) or "",
        Founder = GetFounderId(source),
        Tag = "",
        PrimaryColor = data.PrimaryColor,
        SecondaryColor = data.SecondaryColor,
        Icon = Trim(data.Icon) or "",
    })

    if not organization then
        return Error(reason or "Unable to create organization.")
    end

    TriggerClientEvent(
        UI.Events.OrganizationCreated,
        source,
        organization.Id
    )

    return {
        success = true,
        organizationId = organization.Id,
    }
end)

lib.callback.register(UI.Callbacks.InvitePlayer, function(source, data)
    if type(data) ~= "table" then
        return Error("Invalid invite data.")
    end

    local targetId =
        tostring(data.TargetId or "")

    if targetId == "" then
        return Error("Player Server ID is required.")
    end

    local actorId =
        GetPlayerId(source)

    local organizationId =
        GetPlayerOrganization(actorId)

    if not organizationId then
        return Error("You are not a member of an organization.")
    end

    local success, reason =
        Organization.InviteMember(
            organizationId,
            actorId,
            targetId
        )

    if not success then
        return Error(reason or "Unable to invite player.")
    end

    return {
        success = true,
        message = "Invitation sent.",
    }
end)

lib.callback.register(UI.Callbacks.AcceptInvite, function(source)
    local memberId =
        GetPlayerId(source)

    local organizationId =
        GetOldestPendingInvite(memberId)

    if not organizationId then
        return Error("No pending invitation found.")
    end

    local success, reason =
        Organization.AcceptInvite(
            organizationId,
            memberId,
            memberId
        )

    if not success then
        return Error(reason or "Unable to accept invitation.")
    end

    return {
        success = true,
        message = "Invitation accepted.",
    }
end)

lib.callback.register(UI.Callbacks.DeclineInvite, function(source)
    local memberId =
        GetPlayerId(source)

    local organizationId =
        GetOldestPendingInvite(memberId)

    if not organizationId then
        return Error("No pending invitation found.")
    end

    local success, reason =
        Organization.DeclineInvite(
            organizationId,
            memberId
        )

    if not success then
        return Error(reason or "Unable to decline invitation.")
    end

    return {
        success = true,
        message = "Invitation declined.",
    }
end)
