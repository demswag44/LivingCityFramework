---------------------------------------------------------------------
-- GS Organizations
--
-- File: invites.lua
-- Purpose:
--     Organization invite repository persistence access
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Repository = GSOrganizations.Repository or {}
GSOrganizations.Repository.Invites =
    GSOrganizations.Repository.Invites or {}

local Repository = GSOrganizations.Repository.Invites

function Repository.CreateInvite(data)
    local id = MySQL.insert.await(
        [[
            INSERT INTO gs_organization_invites
            (
                organization_id,
                sender_id,
                receiver_id,
                status,
                expires_at
            )
            VALUES
            (
                ?, ?, ?, ?, ?
            )
        ]],
        {
            data.organization_id,
            data.sender_id,
            data.receiver_id,
            data.status or "pending",
            data.expires_at,
        }
    )

    return {
        id = id,
    }
end

function Repository.AcceptInvite(id)
    local affectedRows = MySQL.update.await(
        [[
            UPDATE gs_organization_invites
            SET status = 'accepted'
            WHERE id = ?
        ]],
        {
            id,
        }
    )

    return {
        affectedRows = affectedRows or 0,
    }
end

function Repository.DeclineInvite(id)
    local affectedRows = MySQL.update.await(
        [[
            UPDATE gs_organization_invites
            SET status = 'declined'
            WHERE id = ?
        ]],
        {
            id,
        }
    )

    return {
        affectedRows = affectedRows or 0,
    }
end

function Repository.RevokeInvite(id)
    local affectedRows = MySQL.update.await(
        [[
            UPDATE gs_organization_invites
            SET status = 'revoked'
            WHERE id = ?
        ]],
        {
            id,
        }
    )

    return {
        affectedRows = affectedRows or 0,
    }
end

function Repository.GetInvites(organizationId)
    return MySQL.query.await(
        [[
            SELECT *
            FROM gs_organization_invites
            WHERE organization_id = ?
            ORDER BY created_at DESC
        ]],
        {
            organizationId,
        }
    ) or {}
end

function Repository.GetPendingInvites(organizationId)
    return MySQL.query.await(
        [[
            SELECT *
            FROM gs_organization_invites
            WHERE organization_id = ?
              AND status = 'pending'
            ORDER BY created_at DESC
        ]],
        {
            organizationId,
        }
    ) or {}
end
