---------------------------------------------------------------------
-- GS Organizations
--
-- File: treasury.lua
-- Purpose:
--     Organization treasury runtime operations
---------------------------------------------------------------------

local Organization = GSOrganizations.Manager
local Security = GSOrganizations.Security
local Events = GSOrganizations.Events
local TreasuryRepository = GSOrganizations.Repository.Treasury

local function ValidateAmount(amount)
    amount = tonumber(amount)

    if not amount or amount <= 0 then
        return nil, "Amount must be positive."
    end

    return math.floor(amount)
end

local function ValidateOrganization(organizationId)
    local success, organization =
        Security.ValidateOrganization(
            organizationId
        )

    if not success then
        return nil, organization
    end

    return organization
end

local function ValidateMember(organizationId, actorId)
    local success, reason =
        Security.ValidateMember(
            organizationId,
            actorId
        )

    if not success then
        return false, reason
    end

    return true
end

local function RequirePermission(organizationId, actorId, permission)
    return Security.Require(
        organizationId,
        actorId,
        permission
    )
end

local function Audit(action, data)
    Security.Audit.Write(
        action,
        data
    )
end

local function SyncBalance(organization, amount)
    organization.Treasury = amount
    organization.LastUpdated = os.time()

    if Events and Events.TreasuryBalanceChanged then
        Events.TreasuryBalanceChanged(
            organization.Id,
            amount
        )
    end
end

function Organization.GetTreasury(organizationId)
    local organization, reason =
        ValidateOrganization(
            organizationId
        )

    if not organization then
        return nil, reason
    end

    return organization.Treasury or 0
end

function Organization.DepositTreasury(organizationId, actorId, amount, note)
    local organization, reason =
        ValidateOrganization(
            organizationId
        )

    if not organization then
        return false, reason
    end

    local success
    success, reason =
        ValidateMember(
            organizationId,
            actorId
        )

    if not success then
        return false, reason
    end

    if GS.OrganizationConfig.AllowMemberTreasuryDeposits == false then
        success, reason =
            RequirePermission(
                organizationId,
                actorId,
                GS.OrganizationPermissions.MANAGE_TREASURY
            )

        if not success then
            return false, reason
        end
    end

    amount, reason =
        ValidateAmount(amount)

    if not amount then
        return false, reason
    end

    local result, balanceAfter, balanceBefore =
        TreasuryRepository.Deposit(
            organizationId,
            actorId,
            amount,
            note
        )

    if not result then
        return false, balanceAfter or "Failed to deposit treasury funds."
    end

    SyncBalance(
        organization,
        balanceAfter
    )

    Audit("Treasury Deposit", {
        Organization = organizationId,
        Actor = actorId,
        Amount = amount,
        BalanceBefore = balanceBefore,
        BalanceAfter = balanceAfter,
        Note = note,
    })

    if Events and Events.TreasuryDeposited then
        Events.TreasuryDeposited(
            organizationId,
            actorId,
            amount,
            balanceAfter
        )
    end

    return true, balanceAfter
end

function Organization.WithdrawTreasury(organizationId, actorId, amount, note)
    local organization, reason =
        ValidateOrganization(
            organizationId
        )

    if not organization then
        return false, reason
    end

    local success
    success, reason =
        RequirePermission(
            organizationId,
            actorId,
            GS.OrganizationPermissions.MANAGE_TREASURY
        )

    if not success then
        return false, reason
    end

    amount, reason =
        ValidateAmount(amount)

    if not amount then
        return false, reason
    end

    if (organization.Treasury or 0) < amount then
        return false, "Insufficient treasury balance."
    end

    local result, balanceAfter, balanceBefore =
        TreasuryRepository.Withdraw(
            organizationId,
            actorId,
            amount,
            note
        )

    if not result then
        return false, balanceAfter or "Failed to withdraw treasury funds."
    end

    SyncBalance(
        organization,
        balanceAfter
    )

    Audit("Treasury Withdrawal", {
        Organization = organizationId,
        Actor = actorId,
        Amount = amount,
        BalanceBefore = balanceBefore,
        BalanceAfter = balanceAfter,
        Note = note,
    })

    if Events and Events.TreasuryWithdrawn then
        Events.TreasuryWithdrawn(
            organizationId,
            actorId,
            amount,
            balanceAfter
        )
    end

    return true, balanceAfter
end

function Organization.TransferTreasury(
    fromOrganizationId,
    toOrganizationId,
    actorId,
    amount,
    note
)
    if not toOrganizationId then
        return false, "Target organization is required."
    end

    if tonumber(fromOrganizationId) == tonumber(toOrganizationId) then
        return false, "Cannot transfer treasury funds to the same organization."
    end

    local fromOrganization, reason =
        ValidateOrganization(
            fromOrganizationId
        )

    if not fromOrganization then
        return false, reason
    end

    local toOrganization
    toOrganization, reason =
        ValidateOrganization(
            toOrganizationId
        )

    if not toOrganization then
        return false, reason
    end

    local success
    success, reason =
        RequirePermission(
            fromOrganizationId,
            actorId,
            GS.OrganizationPermissions.MANAGE_TREASURY
        )

    if not success then
        return false, reason
    end

    amount, reason =
        ValidateAmount(amount)

    if not amount then
        return false, reason
    end

    if (fromOrganization.Treasury or 0) < amount then
        return false, "Insufficient treasury balance."
    end

    local result, fromAfter, toAfter, fromBefore, toBefore =
        TreasuryRepository.Transfer(
            fromOrganizationId,
            toOrganizationId,
            actorId,
            amount,
            note
        )

    if not result then
        return false, fromAfter or "Failed to transfer treasury funds."
    end

    SyncBalance(
        fromOrganization,
        fromAfter
    )

    SyncBalance(
        toOrganization,
        toAfter
    )

    Audit("Treasury Transfer", {
        FromOrganization = fromOrganizationId,
        ToOrganization = toOrganizationId,
        Actor = actorId,
        Amount = amount,
        FromBalanceBefore = fromBefore,
        FromBalanceAfter = fromAfter,
        ToBalanceBefore = toBefore,
        ToBalanceAfter = toAfter,
        Note = note,
    })

    if Events and Events.TreasuryTransferred then
        Events.TreasuryTransferred(
            fromOrganizationId,
            toOrganizationId,
            actorId,
            amount,
            fromAfter,
            toAfter
        )
    end

    return true, fromAfter, toAfter
end

function Organization.GetTreasuryTransactions(organizationId, actorId, limit)
    local _, reason =
        ValidateOrganization(
            organizationId
        )

    if reason then
        return nil, reason
    end

    local success
    success, reason =
        RequirePermission(
            organizationId,
            actorId,
            GS.OrganizationPermissions.VIEW_TREASURY
        )

    if not success then
        return nil, reason
    end

    return TreasuryRepository.GetTransactions(
        organizationId,
        limit or 20
    )
end

return Organization
