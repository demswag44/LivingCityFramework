---------------------------------------------------------------------
-- GS Organizations
--
-- File: tests.lua
-- Purpose:
--     Security Runtime Validation
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

local Security = GSOrganizations.Security

---------------------------------------------------------------------
-- Runtime Validation
---------------------------------------------------------------------

CreateThread(function()

    --------------------------------------------------
    -- Wait for resource startup
    --------------------------------------------------

    Wait(1000)

    Logger.Info(

        "SECURITY",

        "Running Security Runtime Tests..."

    )

    --------------------------------------------------
    -- Manager
    --------------------------------------------------

    assert(

        Security,

        "Security module missing."

    )

    assert(

        Security.IsReady,

        "Security.IsReady missing."

    )

    --------------------------------------------------
    -- Permission Engine
    --------------------------------------------------

    assert(

        Security.HasPermission,

        "HasPermission missing."

    )

    assert(

        Security.Require,

        "Require missing."

    )

    assert(

        Security.HasAny,

        "HasAny missing."

    )

    assert(

        Security.HasAll,

        "HasAll missing."

    )

    --------------------------------------------------
    -- Hierarchy
    --------------------------------------------------

    assert(

        Security.CompareRanks,

        "CompareRanks missing."

    )

    assert(

        Security.CanManageMember,

        "CanManageMember missing."

    )

    --------------------------------------------------
    -- Validator
    --------------------------------------------------

    assert(

        Security.ValidateOrganization,

        "ValidateOrganization missing."

    )

    assert(

        Security.ValidateMember,

        "ValidateMember missing."

    )

    assert(

        Security.ValidateRank,

        "ValidateRank missing."

    )

    assert(

        Security.ValidatePermission,

        "ValidatePermission missing."

    )

    --------------------------------------------------
    -- Audit
    --------------------------------------------------

    assert(

        Security.Audit,

        "Audit module missing."

    )

    assert(

        Security.Audit.Write,

        "Audit.Write missing."

    )

    --------------------------------------------------
    -- Success
    --------------------------------------------------

    Logger.Success(

        "SECURITY",

        "Security Runtime Tests Passed"

    )

end)