---------------------------------------------------------------------
-- GS Organizations
--
-- File: members.lua
-- Purpose:
--     Organization member repository persistence access
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Repository = GSOrganizations.Repository or {}
GSOrganizations.Repository.Members =
    GSOrganizations.Repository.Members or {}

local Repository = GSOrganizations.Repository.Members

function Repository.AddMember(data)
    local id = MySQL.insert.await(
        [[
            INSERT INTO gs_organization_members
            (
                organization_id,
                member_id,
                rank
            )
            VALUES
            (
                ?, ?, ?
            )
        ]],
        {
            data.organization_id,
            data.member_id,
            data.rank,
        }
    )

    return {
        id = id,
    }
end

function Repository.RemoveMember(organizationId, memberId)
    local affectedRows = MySQL.update.await(
        [[
            DELETE
            FROM gs_organization_members
            WHERE organization_id = ?
              AND member_id = ?
        ]],
        {
            organizationId,
            memberId,
        }
    )

    return {
        affectedRows = affectedRows or 0,
    }
end

function Repository.UpdateMemberRank(organizationId, memberId, rank)
    local affectedRows = MySQL.update.await(
        [[
            UPDATE gs_organization_members
            SET rank = ?
            WHERE organization_id = ?
              AND member_id = ?
        ]],
        {
            rank,
            organizationId,
            memberId,
        }
    )

    return {
        affectedRows = affectedRows or 0,
    }
end

function Repository.GetMember(organizationId, memberId)
    return MySQL.single.await(
        [[
            SELECT *
            FROM gs_organization_members
            WHERE organization_id = ?
              AND member_id = ?
        ]],
        {
            organizationId,
            memberId,
        }
    )
end

function Repository.GetMembers(organizationId)
    return MySQL.query.await(
        [[
            SELECT *
            FROM gs_organization_members
            WHERE organization_id = ?
            ORDER BY joined_at ASC
        ]],
        {
            organizationId,
        }
    ) or {}
end
