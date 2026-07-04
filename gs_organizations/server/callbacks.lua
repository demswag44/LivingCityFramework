---------------------------------------------------------------------
-- GS Organizations
--
-- File: callbacks.lua
-- Purpose:
--     Server callbacks for Organization UI
---------------------------------------------------------------------

local UI = GSOrganizations.UI
local Organization = GSOrganizations.Manager
local Ranks = GSOrganizations.Ranks
local Security = GSOrganizations.Security

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

local function GetPermissionOptions()
    local permissions = {}

    for _, permission in pairs(GS.OrganizationPermissions) do
        permissions[#permissions + 1] = permission
    end

    table.sort(permissions)

    return permissions
end

local function RequireRankManagement(source)
    local actorId = GetPlayerId(source)
    local organizationId = GetPlayerOrganization(actorId)

    if not organizationId then
        return nil, nil, Error("You are not a member of an organization.")
    end

    local success, reason =
        Security.Require(
            organizationId,
            actorId,
            GS.OrganizationPermissions.SET_LEADER
        )

    if not success then
        return nil, nil, Error(reason or "You cannot manage ranks.")
    end

    return organizationId, actorId
end

local function CountTable(value)
    local count = 0

    if type(value) ~= "table" then
        return count
    end

    for _ in pairs(value) do
        count = count + 1
    end

    return count
end

local function CountPendingInvites(invites)
    local count = 0

    if type(invites) ~= "table" then
        return count
    end

    for _, invite in pairs(invites) do
        if not invite.Status
        or invite.Status == "pending" then
            count = count + 1
        end
    end

    return count
end

local function IsAdmin(source)
    return source == 0
        or IsPlayerAceAllowed(source, "command")
        or IsPlayerAceAllowed(source, "command.org")
        or IsPlayerAceAllowed(source, "gs_organizations.admin")
end

local function GetTerritoriesModule()
    if not GSOrganizations.Territories then
        return nil, Error("Territory module is not loaded.")
    end

    return GSOrganizations.Territories
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
        Template =
            data.Template
            or data.Type
            or "Custom",
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

lib.callback.register(UI.Callbacks.GetOrganizationDashboard, function(source)
    local playerId =
        GetPlayerId(source)

    local organizationId, organization =
        GetPlayerOrganization(playerId)

    if not organizationId or not organization then
        return Error("You are not a member of an organization.")
    end

    local ranks =
        Ranks.GetRanks(organizationId)

    local territories = {}

    if GSOrganizations.Territories
    and GSOrganizations.Territories.GetByOrganization then
        territories =
            GSOrganizations.Territories.GetByOrganization(
                organizationId
            )
    end

    return {
        success = true,
        dashboard = {
            Id = organization.Id,
            Name = organization.Name,
            Type = organization.Type,
            Description = organization.Description,
            PrimaryColor = organization.PrimaryColor,
            SecondaryColor = organization.SecondaryColor,
            Icon = organization.Icon,
            Founder = organization.Founder,
            Leader = organization.Leader,
            MemberCount = CountTable(organization.Members),
            Treasury = organization.Treasury or 0,
            Reputation = organization.Reputation or 0,
            Influence = organization.Influence or 0,
            Heat = organization.Heat or 0,
            RankCount = #ranks,
            PendingInviteCount = CountPendingInvites(organization.Invites),
            TerritoryCount = #territories,
            Territories = territories,
        },
    }
end)

lib.callback.register(UI.Callbacks.GetTerritories, function()
    local Territories, errorResponse =
        GetTerritoriesModule()

    if errorResponse then
        return errorResponse
    end

    local territories = {}

    for _, territory in pairs(Territories.GetAll() or {}) do
        territories[#territories + 1] = territory
    end

    table.sort(territories, function(left, right)
        return tostring(left.Name) < tostring(right.Name)
    end)

    return {
        success = true,
        territories = territories,
    }
end)

lib.callback.register(UI.Callbacks.GetTerritory, function(_, data)
    local Territories, errorResponse =
        GetTerritoriesModule()

    if errorResponse then
        return errorResponse
    end

    local territory =
        Territories.Get(data and data.Id)

    if not territory then
        return Error("Territory not found.")
    end

    return {
        success = true,
        territory = territory,
    }
end)

lib.callback.register(UI.Callbacks.ReloadTerritories, function(source)
    if not IsAdmin(source) then
        return Error("You are not allowed to reload territories.")
    end

    local Territories, errorResponse =
        GetTerritoriesModule()

    if errorResponse then
        return errorResponse
    end

    local success =
        Territories.Initialize()

    if not success then
        return Error("Unable to reload territories.")
    end

    return {
        success = true,
        count = CountTable(Territories.GetAll()),
    }
end)

lib.callback.register(UI.Callbacks.GetActivityFeed, function(source, data)
    local playerId =
        GetPlayerId(source)

    local organizationId =
        GetPlayerOrganization(playerId)

    if not organizationId then
        return Error("You are not a member of an organization.")
    end

    return {
        success = true,
        activities =
            Organization.GetRecentActivities(
                organizationId,
                data and data.Limit or 10
            ),
    }
end)

lib.callback.register(UI.Callbacks.GetTreasury, function(source)
    local actorId =
        GetPlayerId(source)

    local organizationId =
        GetPlayerOrganization(actorId)

    if not organizationId then
        return Error("You are not a member of an organization.")
    end

    local balance, reason =
        Organization.GetTreasury(
            organizationId
        )

    if balance == nil then
        return Error(reason or "Unable to load treasury.")
    end

    return {
        success = true,
        organizationId = organizationId,
        balance = balance,
    }
end)

lib.callback.register(UI.Callbacks.DepositTreasury, function(source, data)
    local actorId =
        GetPlayerId(source)

    local organizationId =
        GetPlayerOrganization(actorId)

    if not organizationId then
        return Error("You are not a member of an organization.")
    end

    local success, balance =
        Organization.DepositTreasury(
            organizationId,
            actorId,
            data and data.Amount,
            data and Trim(data.Note)
        )

    if not success then
        return Error(balance or "Unable to deposit treasury funds.")
    end

    return {
        success = true,
        balance = balance,
    }
end)

lib.callback.register(UI.Callbacks.WithdrawTreasury, function(source, data)
    local actorId =
        GetPlayerId(source)

    local organizationId =
        GetPlayerOrganization(actorId)

    if not organizationId then
        return Error("You are not a member of an organization.")
    end

    local success, balance =
        Organization.WithdrawTreasury(
            organizationId,
            actorId,
            data and data.Amount,
            data and Trim(data.Note)
        )

    if not success then
        return Error(balance or "Unable to withdraw treasury funds.")
    end

    return {
        success = true,
        balance = balance,
    }
end)

lib.callback.register(UI.Callbacks.TransferTreasury, function(source, data)
    local actorId =
        GetPlayerId(source)

    local organizationId =
        GetPlayerOrganization(actorId)

    if not organizationId then
        return Error("You are not a member of an organization.")
    end

    local success, balance =
        Organization.TransferTreasury(
            organizationId,
            data and tonumber(data.TargetOrganizationId),
            actorId,
            data and data.Amount,
            data and Trim(data.Note)
        )

    if not success then
        return Error(balance or "Unable to transfer treasury funds.")
    end

    return {
        success = true,
        balance = balance,
    }
end)

lib.callback.register(UI.Callbacks.GetTreasuryTransactions, function(source, data)
    local actorId =
        GetPlayerId(source)

    local organizationId =
        GetPlayerOrganization(actorId)

    if not organizationId then
        return Error("You are not a member of an organization.")
    end

    local transactions, reason =
        Organization.GetTreasuryTransactions(
            organizationId,
            actorId,
            data and data.Limit or 10
        )

    if not transactions then
        return Error(reason or "Unable to load treasury transactions.")
    end

    return {
        success = true,
        transactions = transactions,
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

lib.callback.register(UI.Callbacks.GetRanks, function(source)
    local actorId =
        GetPlayerId(source)

    local organizationId =
        GetPlayerOrganization(actorId)

    if not organizationId then
        return Error("You are not a member of an organization.")
    end

    return {
        success = true,
        ranks = Ranks.GetRanks(organizationId),
        permissions = GetPermissionOptions(),
    }
end)

lib.callback.register(UI.Callbacks.CreateRank, function(source, data)
    local organizationId, _, errorResponse =
        RequireRankManagement(source)

    if errorResponse then
        return errorResponse
    end

    local success, result =
        Ranks.CreateRank(
            organizationId,
            data or {}
        )

    if not success then
        return Error(result or "Unable to create rank.")
    end

    return {
        success = true,
        rank = result,
    }
end)

lib.callback.register(UI.Callbacks.UpdateRank, function(source, data)
    local organizationId, _, errorResponse =
        RequireRankManagement(source)

    if errorResponse then
        return errorResponse
    end

    if type(data) ~= "table" or not data.OldName then
        return Error("Invalid rank update.")
    end

    local success, result =
        Ranks.UpdateRank(
            organizationId,
            data.OldName,
            data
        )

    if not success then
        return Error(result or "Unable to update rank.")
    end

    return {
        success = true,
        rank = result,
    }
end)

lib.callback.register(UI.Callbacks.DeleteRank, function(source, data)
    local organizationId, _, errorResponse =
        RequireRankManagement(source)

    if errorResponse then
        return errorResponse
    end

    local rankName =
        data and data.Name

    local success, reason =
        Ranks.DeleteRank(
            organizationId,
            rankName
        )

    if not success then
        return Error(reason or "Unable to delete rank.")
    end

    return {
        success = true,
    }
end)

lib.callback.register(UI.Callbacks.CloneRank, function(source, data)
    local organizationId, _, errorResponse =
        RequireRankManagement(source)

    if errorResponse then
        return errorResponse
    end

    local success, result =
        Ranks.CloneRank(
            organizationId,
            data and data.SourceName,
            data and data.Name
        )

    if not success then
        return Error(result or "Unable to clone rank.")
    end

    return {
        success = true,
        rank = result,
    }
end)

lib.callback.register(UI.Callbacks.ResetRanks, function(source)
    local organizationId, actorId, errorResponse =
        RequireRankManagement(source)

    if errorResponse then
        return errorResponse
    end

    Ranks.ResetToDefaults(organizationId)

    Organization.AddActivity(
        organizationId,
        actorId,
        GetPlayerName(source) or actorId,
        "rank_template",
        "Rank template applied",
        "Ranks were reset to the default template.",
        {
            Template = "Custom",
        }
    )

    local organization =
        Organization.Get(organizationId)

    if organization then
        organization.Ranks =
            Ranks.List[organizationId] or {}
    end

    return {
        success = true,
        ranks = Ranks.GetRanks(organizationId),
    }
end)
