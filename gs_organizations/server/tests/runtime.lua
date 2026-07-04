---------------------------------------------------------------------
-- GS Organizations
--
-- File: runtime.lua
-- Purpose:
--     Runtime Validation Tests
---------------------------------------------------------------------

---------------------------------------------------------------------
-- GS Core
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

---------------------------------------------------------------------
-- Runtime Validation
---------------------------------------------------------------------

CreateThread(function()

    --------------------------------------------------
    -- Wait for startup
    --------------------------------------------------

    Wait(1000)

    local Organization = GSOrganizations.Manager

    Logger.Info(

        "ORG TEST",

        "Running Runtime Validation..."

    )

    --------------------------------------------------
    -- Manager
    --------------------------------------------------

    assert(
        Organization,
        "Organization Manager Missing"
    )

    --------------------------------------------------
    -- Runtime
    --------------------------------------------------

    assert(
        Organization.Get,
        "Organization.Get Missing"
    )

    assert(
        Organization.GetAll,
        "Organization.GetAll Missing"
    )

    assert(
        Organization.Exists,
        "Organization.Exists Missing"
    )

    assert(
        Organization.Count,
        "Organization.Count Missing"
    )

    --------------------------------------------------
    -- Create / Load
    --------------------------------------------------

    assert(
        Organization.Create,
        "Organization.Create Missing"
    )

    assert(
        Organization.Load,
        "Organization.Load Missing"
    )

    --------------------------------------------------
    -- Members
    --------------------------------------------------

    assert(
        Organization.AddMember,
        "Organization.AddMember Missing"
    )

    assert(
        Organization.RemoveMember,
        "Organization.RemoveMember Missing"
    )

    assert(
        Organization.GetMember,
        "Organization.GetMember Missing"
    )

    assert(
        Organization.GetMembers,
        "Organization.GetMembers Missing"
    )

    --------------------------------------------------
    -- Ranks
    --------------------------------------------------

    assert(
        Organization.SetRank,
        "Organization.SetRank Missing"
    )

    assert(
        Organization.GetRank,
        "Organization.GetRank Missing"
    )

    --------------------------------------------------
    -- Leadership
    --------------------------------------------------

    assert(
        Organization.SetLeader,
        "Organization.SetLeader Missing"
    )

    --------------------------------------------------
    -- Invites
    --------------------------------------------------

    assert(
        Organization.InviteMember,
        "Organization.InviteMember Missing"
    )

    assert(
        Organization.AcceptInvite,
        "Organization.AcceptInvite Missing"
    )

    --------------------------------------------------
    -- Delete
    --------------------------------------------------

    assert(
        Organization.Delete,
        "Organization.Delete Missing"
    )

    --------------------------------------------------
    -- Success
    --------------------------------------------------

    Logger.Success(

        "ORG TEST",

        "Runtime Validation Passed"

    )

end)