---------------------------------------------------------------------
-- GS Organizations
--
-- File: organization.lua
-- Purpose:
--     Public Organization API
---------------------------------------------------------------------

local Organization = GSOrganizations.Manager

---------------------------------------------------------------------
-- Create Organization
---------------------------------------------------------------------

exports("CreateOrganization", function(data)

    return Organization.Create(data)

end)

---------------------------------------------------------------------
-- Delete Organization
---------------------------------------------------------------------

exports("DeleteOrganization", function(id)

    return Organization.Delete(id)

end)

---------------------------------------------------------------------
-- Get Organization
---------------------------------------------------------------------

exports("GetOrganization", function(id)

    return Organization.Get(id)

end)

---------------------------------------------------------------------
-- Get Organizations
---------------------------------------------------------------------

exports("GetOrganizations", function()

    return Organization.GetAll()

end)

---------------------------------------------------------------------
-- Organization Exists
---------------------------------------------------------------------

exports("OrganizationExists", function(id)

    return Organization.Exists(id)

end)

---------------------------------------------------------------------
-- Count Organizations
---------------------------------------------------------------------

exports("GetOrganizationCount", function()

    return Organization.Count()

end)

---------------------------------------------------------------------
-- Member Management
---------------------------------------------------------------------

exports("AddOrganizationMember", function(id, actorId, memberId)

    return Organization.AddMember(id, actorId, memberId)

end)

exports("RemoveOrganizationMember", function(id, actorId, memberId)

    return Organization.RemoveMember(id, actorId, memberId)

end)

---------------------------------------------------------------------
-- Leadership
---------------------------------------------------------------------

exports("SetOrganizationLeader", function(id, memberId)

    return Organization.SetLeader(id, memberId)

end)

---------------------------------------------------------------------
-- Invites
---------------------------------------------------------------------

exports("InviteOrganizationMember", function(id, memberId)

    return Organization.InviteMember(id, memberId)

end)

exports("AcceptOrganizationInvite", function(id, actorId, memberId)

    return Organization.AcceptInvite(id, actorId, memberId)

end)

exports("DeclineOrganizationInvite", function(id, memberId)

    return Organization.DeclineInvite(id, memberId)

end)
