---------------------------------------------------------------------
-- GS Organizations
--
-- File: manager.lua
-- Purpose:
--     Dynamic organization rank runtime manager
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

GSOrganizations = GSOrganizations or {}
GSOrganizations.Ranks = GSOrganizations.Ranks or {}

local Ranks = GSOrganizations.Ranks
local Repository = GSOrganizations.Repository.Ranks

Ranks.List = Ranks.List or {}
Ranks.Ready = false
Ranks.Version = "2.0.0"

local OWNER_PERMISSIONS = {
    GS.OrganizationPermissions.SET_LEADER,
    GS.OrganizationPermissions.DELETE_ORGANIZATION,
}

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end

    local copied = {}

    for key, item in pairs(value) do
        copied[key] = Copy(item)
    end

    return copied
end

local function DecodePermissions(value)
    if type(value) == "table" then
        return value
    end

    if type(value) ~= "string" or value == "" then
        return {}
    end

    local ok, decoded = pcall(json.decode, value)

    if ok and type(decoded) == "table" then
        return decoded
    end

    return {}
end

local function IsValidPermission(permission)
    for _, known in pairs(GS.OrganizationPermissions) do
        if known == permission then
            return true
        end
    end

    return false
end

local function NormalizePermissions(permissions)
    local normalized = {}

    if type(permissions) ~= "table" then
        return normalized
    end

    for key, value in pairs(permissions) do
        local permission = value == true and key or value

        if value ~= false
        and type(permission) == "string"
        and IsValidPermission(permission) then
            normalized[permission] = true
        end
    end

    return normalized
end

local function ValidatePermissionNames(permissions)
    if type(permissions) ~= "table" then
        return true
    end

    for key, value in pairs(permissions) do
        local permission = value == true and key or value

        if value ~= false then
            if type(permission) ~= "string"
            or not IsValidPermission(permission) then
                return false, ("Unknown permission '%s'.")
                    :format(tostring(permission))
            end
        end
    end

    return true
end

local function NormalizeName(name)
    if type(name) ~= "string" then
        return nil
    end

    local trimmed = name:match("^%s*(.-)%s*$")

    if trimmed == "" then
        return nil
    end

    return trimmed
end

local function IsHexColor(value)
    return value == nil
        or value == ""
        or (
            type(value) == "string"
            and value:match("^#%x%x%x%x%x%x$") ~= nil
        )
end

local function NormalizeRank(data)
    local name = NormalizeName(data and data.Name or data and data.name)

    if not name then
        return nil, "Rank name is required."
    end

    local weight = tonumber(data.Weight or data.weight)

    if not weight then
        return nil, "Rank weight is required."
    end

    weight = math.floor(weight)

    local salary = tonumber(data.Salary or data.salary or 0)

    if not salary or salary < 0 then
        return nil, "Rank salary must be zero or greater."
    end

    local color = data.Color or data.color

    if not IsHexColor(color) then
        return nil, "Rank color must be a valid HEX color."
    end

    local rawPermissions =
        data.Permissions
        or data.permissions
        or data.permissions_json

    local permissionsValid, permissionsReason =
        ValidatePermissionNames(
            rawPermissions
        )

    if not permissionsValid then
        return nil, permissionsReason
    end

    local permissions =
        NormalizePermissions(
            rawPermissions
        )

    return {
        Name = name,
        Label = data.Label or data.label or name,
        Weight = weight,
        Permissions = permissions,
        Salary = math.floor(salary),
        Color = color or "",
        Icon = data.Icon or data.icon or "",
    }
end

local function FromRow(row)
    return NormalizeRank({
        Name = row.name,
        Label = row.label,
        Weight = row.weight,
        Permissions = DecodePermissions(row.permissions_json),
        Salary = row.salary,
        Color = row.color,
        Icon = row.icon,
    })
end

local function ToRepositoryData(organizationId, rank)
    return {
        organization_id = organizationId,
        name = rank.Name,
        label = rank.Label,
        weight = rank.Weight,
        permissions = rank.Permissions,
        salary = rank.Salary,
        color = rank.Color,
        icon = rank.Icon,
    }
end

local function GetBucket(organizationId)
    Ranks.List[organizationId] = Ranks.List[organizationId] or {}
    return Ranks.List[organizationId]
end

local function HasLeaderPermissions(rank)
    if rank.Name ~= "Leader" then
        return true
    end

    for _, permission in ipairs(OWNER_PERMISSIONS) do
        if rank.Permissions[permission] ~= true then
            return false
        end
    end

    return true
end

local function ValidateUnique(organizationId, rank, oldName)
    local bucket = GetBucket(organizationId)

    for name, existing in pairs(bucket) do
        if name ~= oldName then
            if name == rank.Name then
                return false, "Duplicate rank name."
            end

            if existing.Weight == rank.Weight then
                return false, "Rank weight must be unique."
            end
        end
    end

    return true
end

local function ApplyToMembers(organization)
    if not organization or not organization.Members then
        return
    end

    for _, member in pairs(organization.Members) do
        member.RankData =
            Ranks.GetRankData(
                organization.Id,
                member.Rank
            )
            or Ranks.GetDefaultRankData("Member")
    end
end

function Ranks.Initialize()
    if Ranks.Ready then
        return
    end

    Ranks.Ready = true

    Logger.Success(
        "RANKS",
        "Rank Manager Initialized"
    )
end

function Ranks.Shutdown()
    Ranks.Ready = false

    Logger.Warning(
        "RANKS",
        "Rank Manager Shutdown"
    )
end

function Ranks.IsReady()
    return Ranks.Ready
end

function Ranks.GetVersion()
    return Ranks.Version
end

function Ranks.Count(organizationId)
    local count = 0
    local source = organizationId and GetBucket(organizationId) or Ranks.List

    for _ in pairs(source) do
        count = count + 1
    end

    return count
end

function Ranks.GetDefaultRankData(name)
    local template =
        GS.OrganizationConfig.DefaultRanks[name]
        or GS.OrganizationConfig.DefaultRanks.Member

    local rank = {
        Name = name,
        Label = template.Label or name,
        Weight = template.Weight or 0,
        Permissions = Copy(template.Permissions or {}),
        Salary = template.Salary or 0,
        Color = template.Color or "",
        Icon = template.Icon or "",
    }

    return rank
end

function Ranks.GetDefaultRanks()
    local defaults = {}

    for name in pairs(GS.OrganizationConfig.DefaultRanks) do
        defaults[#defaults + 1] = Ranks.GetDefaultRankData(name)
    end

    table.sort(defaults, function(left, right)
        return left.Weight > right.Weight
    end)

    return defaults
end

function Ranks.GetRankData(organizationId, name)
    local rank = GetBucket(organizationId)[name]

    if not rank then
        return nil
    end

    return Copy(rank)
end

function Ranks.GetRanks(organizationId)
    local list = {}

    for _, rank in pairs(GetBucket(organizationId)) do
        list[#list + 1] = Copy(rank)
    end

    table.sort(list, function(left, right)
        if left.Weight == right.Weight then
            return left.Name < right.Name
        end

        return left.Weight > right.Weight
    end)

    return list
end

function Ranks.GetJoinRankName(organizationId)
    local bucket = GetBucket(organizationId)

    if bucket.Member then
        return "Member"
    end

    local selected = nil

    for _, rank in pairs(bucket) do
        if not selected
        or rank.Weight < selected.Weight then
            selected = rank
        end
    end

    return selected and selected.Name or "Member"
end

function Ranks.LoadForOrganization(organization)
    if not organization or not organization.Id then
        return 0
    end

    local rows = Repository.GetRanks(organization.Id)
    local bucket = GetBucket(organization.Id)

    for key in pairs(bucket) do
        bucket[key] = nil
    end

    if #rows == 0 then
        Ranks.ResetToDefaults(organization.Id)
        rows = Repository.GetRanks(organization.Id)
    end

    for _, row in ipairs(rows) do
        local rank = FromRow(row)

        if rank then
            bucket[rank.Name] = rank
        end
    end

    organization.Ranks = bucket

    ApplyToMembers(organization)

    return #rows
end

function Ranks.ResetToDefaults(organizationId)
    Repository.DeleteOrganizationRanks(organizationId)

    local bucket = GetBucket(organizationId)

    for key in pairs(bucket) do
        bucket[key] = nil
    end

    for _, rank in ipairs(Ranks.GetDefaultRanks()) do
        Repository.CreateRank(
            ToRepositoryData(
                organizationId,
                rank
            )
        )

        bucket[rank.Name] = Copy(rank)
    end

    local organization =
        GSOrganizations.Manager
        and GSOrganizations.Manager.Get(organizationId)

    if organization then
        organization.Ranks = bucket

        for _, member in pairs(organization.Members or {}) do
            if not bucket[member.Rank] then
                member.Rank = "Member"
                GSOrganizations.Repository.Members.UpdateMemberRank(
                    organizationId,
                    member.Id,
                    "Member"
                )
            end
        end

        ApplyToMembers(organization)
    end

    return true
end

function Ranks.CreateRank(organizationId, data)
    local rank, reason = NormalizeRank(data)

    if not rank then
        return false, reason
    end

    local success
    success, reason =
        ValidateUnique(
            organizationId,
            rank
        )

    if not success then
        return false, reason
    end

    if not HasLeaderPermissions(rank) then
        return false, "Leader cannot lose ownership permissions."
    end

    local result =
        Repository.CreateRank(
            ToRepositoryData(
                organizationId,
                rank
            )
        )

    if not result or not result.id then
        return false, "Failed to persist rank."
    end

    GetBucket(organizationId)[rank.Name] = rank

    if GSOrganizations.Events
    and GSOrganizations.Events.RankCreated then
        GSOrganizations.Events.RankCreated(organizationId, rank)
    end

    return true, Copy(rank)
end

function Ranks.UpdateRank(organizationId, oldName, data)
    local bucket = GetBucket(organizationId)
    local existing = bucket[oldName]

    if not existing then
        return false, "Rank not found."
    end

    local merged = Copy(existing)

    for key, value in pairs(data or {}) do
        merged[key] = value
    end

    local rank, reason = NormalizeRank(merged)

    if not rank then
        return false, reason
    end

    if oldName == "Leader" and rank.Name ~= "Leader" then
        return false, "Leader cannot be renamed."
    end

    if not HasLeaderPermissions(rank) then
        return false, "Leader cannot lose ownership permissions."
    end

    local success
    success, reason =
        ValidateUnique(
            organizationId,
            rank,
            oldName
        )

    if not success then
        return false, reason
    end

    local result =
        Repository.UpdateRank(
            organizationId,
            oldName,
            ToRepositoryData(
                organizationId,
                rank
            )
        )

    if not result or result.affectedRows < 1 then
        return false, "Failed to persist rank."
    end

    bucket[oldName] = nil
    bucket[rank.Name] = rank

    local organization =
        GSOrganizations.Manager
        and GSOrganizations.Manager.Get(organizationId)

    if organization then
        if oldName ~= rank.Name then
            for _, member in pairs(organization.Members or {}) do
                if member.Rank == oldName then
                    member.Rank = rank.Name
                    member.RankData = Copy(rank)
                    GSOrganizations.Repository.Members.UpdateMemberRank(
                        organizationId,
                        member.Id,
                        rank.Name
                    )
                end
            end
        end

        ApplyToMembers(organization)
    end

    if GSOrganizations.Events
    and GSOrganizations.Events.RankUpdated then
        GSOrganizations.Events.RankUpdated(organizationId, rank)
    end

    return true, Copy(rank)
end

function Ranks.RenameRank(organizationId, oldName, newName)
    return Ranks.UpdateRank(
        organizationId,
        oldName,
        {
            Name = newName,
        }
    )
end

function Ranks.DeleteRank(organizationId, name)
    if name == "Leader" then
        return false, "Leader cannot be deleted."
    end

    local bucket = GetBucket(organizationId)

    if not bucket[name] then
        return false, "Rank not found."
    end

    local count = 0

    for _ in pairs(bucket) do
        count = count + 1
    end

    if count <= 1 then
        return false, "Organization must always contain one top-level rank."
    end

    local organization =
        GSOrganizations.Manager
        and GSOrganizations.Manager.Get(organizationId)

    if organization then
        for _, member in pairs(organization.Members or {}) do
            if member.Rank == name then
                return false, "Cannot delete a rank assigned to members."
            end
        end
    end

    local result = Repository.DeleteRank(organizationId, name)

    if not result or result.affectedRows < 1 then
        return false, "Failed to delete rank."
    end

    bucket[name] = nil

    if GSOrganizations.Events
    and GSOrganizations.Events.RankDeleted then
        GSOrganizations.Events.RankDeleted(organizationId, name)
    end

    return true
end

function Ranks.CloneRank(organizationId, sourceName, newName)
    local source = Ranks.GetRankData(organizationId, sourceName)

    if not source then
        return false, "Source rank not found."
    end

    source.Name = newName
    source.Label = newName

    return Ranks.CreateRank(
        organizationId,
        source
    )
end

function Ranks.SetPermissions(organizationId, name, permissions)
    local success, result =
        Ranks.UpdateRank(
            organizationId,
            name,
            {
                Permissions = NormalizePermissions(permissions),
            }
        )

    if success
    and GSOrganizations.Events
    and GSOrganizations.Events.RankPermissionChanged then
        GSOrganizations.Events.RankPermissionChanged(organizationId, result)
    end

    return success, result
end

function Ranks.SetSalary(organizationId, name, salary)
    local success, result =
        Ranks.UpdateRank(
            organizationId,
            name,
            {
                Salary = salary,
            }
        )

    if success
    and GSOrganizations.Events
    and GSOrganizations.Events.RankSalaryChanged then
        GSOrganizations.Events.RankSalaryChanged(organizationId, result)
    end

    return success, result
end

return Ranks
