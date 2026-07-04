---------------------------------------------------------------------
-- GS Organizations
--
-- File: treasury.lua
-- Purpose:
--     Organization treasury repository persistence access
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Repository = GSOrganizations.Repository or {}
GSOrganizations.Repository.Treasury =
    GSOrganizations.Repository.Treasury or {}

local Repository = GSOrganizations.Repository.Treasury

local function RecordTransaction(data)
    local id = MySQL.insert.await(
        [[
            INSERT INTO gs_organization_transactions
            (
                organization_id,
                type,
                actor_id,
                target_id,
                amount,
                balance_before,
                balance_after,
                note
            )
            VALUES
            (
                ?, ?, ?, ?, ?, ?, ?, ?
            )
        ]],
        {
            data.organization_id,
            data.type,
            data.actor_id,
            data.target_id,
            data.amount,
            data.balance_before,
            data.balance_after,
            data.note,
        }
    )

    return {
        id = id,
    }
end

function Repository.GetBalance(organizationId)
    local row = MySQL.single.await(
        [[
            SELECT treasury
            FROM gs_organizations
            WHERE id = ?
        ]],
        {
            organizationId,
        }
    )

    return row and tonumber(row.treasury) or nil
end

function Repository.SetBalance(organizationId, amount)
    local affectedRows = MySQL.update.await(
        [[
            UPDATE gs_organizations
            SET treasury = ?
            WHERE id = ?
        ]],
        {
            amount,
            organizationId,
        }
    )

    return {
        affectedRows = affectedRows or 0,
    }
end

function Repository.Deposit(organizationId, actorId, amount, note)
    local balanceBefore =
        Repository.GetBalance(organizationId)

    if balanceBefore == nil then
        return nil, "Organization not found."
    end

    local balanceAfter =
        balanceBefore + amount

    Repository.SetBalance(
        organizationId,
        balanceAfter
    )

    return RecordTransaction({
        organization_id = organizationId,
        type = "deposit",
        actor_id = actorId,
        amount = amount,
        balance_before = balanceBefore,
        balance_after = balanceAfter,
        note = note,
    }), balanceAfter, balanceBefore
end

function Repository.Withdraw(organizationId, actorId, amount, note)
    local balanceBefore =
        Repository.GetBalance(organizationId)

    if balanceBefore == nil then
        return nil, "Organization not found."
    end

    local balanceAfter =
        balanceBefore - amount

    Repository.SetBalance(
        organizationId,
        balanceAfter
    )

    return RecordTransaction({
        organization_id = organizationId,
        type = "withdraw",
        actor_id = actorId,
        amount = amount,
        balance_before = balanceBefore,
        balance_after = balanceAfter,
        note = note,
    }), balanceAfter, balanceBefore
end

function Repository.Transfer(
    fromOrganizationId,
    toOrganizationId,
    actorId,
    amount,
    note
)
    local fromBefore =
        Repository.GetBalance(fromOrganizationId)

    local toBefore =
        Repository.GetBalance(toOrganizationId)

    if fromBefore == nil or toBefore == nil then
        return nil, "Organization not found."
    end

    local fromAfter =
        fromBefore - amount

    local toAfter =
        toBefore + amount

    Repository.SetBalance(
        fromOrganizationId,
        fromAfter
    )

    Repository.SetBalance(
        toOrganizationId,
        toAfter
    )

    local outgoing =
        RecordTransaction({
            organization_id = fromOrganizationId,
            type = "transfer_out",
            actor_id = actorId,
            target_id = tostring(toOrganizationId),
            amount = amount,
            balance_before = fromBefore,
            balance_after = fromAfter,
            note = note,
        })

    local incoming =
        RecordTransaction({
            organization_id = toOrganizationId,
            type = "transfer_in",
            actor_id = actorId,
            target_id = tostring(fromOrganizationId),
            amount = amount,
            balance_before = toBefore,
            balance_after = toAfter,
            note = note,
        })

    return {
        outgoing = outgoing,
        incoming = incoming,
    }, fromAfter, toAfter, fromBefore, toBefore
end

function Repository.GetTransactions(organizationId, limit)
    return MySQL.query.await(
        [[
            SELECT *
            FROM gs_organization_transactions
            WHERE organization_id = ?
            ORDER BY created_at DESC, id DESC
            LIMIT ?
        ]],
        {
            organizationId,
            tonumber(limit) or 20,
        }
    ) or {}
end

return Repository
