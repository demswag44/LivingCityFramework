---------------------------------------------------------------------
-- GS Organizations
--
-- File: config.lua
-- Purpose:
--     Organization Configuration
---------------------------------------------------------------------

GS = GS or {}

GS.OrganizationConfig = {}

----------------------------------------------------------
-- General
----------------------------------------------------------

GS.OrganizationConfig.MaxOrganizations = 1000

GS.OrganizationConfig.MaxMembers = 500

GS.OrganizationConfig.DefaultType = "Gang"

GS.OrganizationConfig.AllowNPCOrganizations = true

GS.OrganizationConfig.AllowPlayerOrganizations = true

GS.OrganizationConfig.AllowMemberTreasuryDeposits = true

----------------------------------------------------------
-- Organization Types
----------------------------------------------------------

GS.OrganizationConfig.Types = {

    Gang = true,

    Cartel = true,

    Mafia = true,

    MotorcycleClub = true,

    Corporation = true,

    Police = true,

    Government = true,

    Security = true

}

----------------------------------------------------------
-- Default Ranks
----------------------------------------------------------

GS.OrganizationConfig.DefaultRanks = {

    -----------------------------------------------------------------
    -- Leader
    -----------------------------------------------------------------

    Leader = {

        Label = "Leader",

        Weight = 100,

        Permissions = {

            [GS.OrganizationPermissions.INVITE_MEMBER]       = true,
            [GS.OrganizationPermissions.REMOVE_MEMBER]       = true,
            [GS.OrganizationPermissions.KICK_MEMBER]         = true,

            [GS.OrganizationPermissions.PROMOTE_MEMBER]      = true,
            [GS.OrganizationPermissions.DEMOTE_MEMBER]       = true,

            [GS.OrganizationPermissions.SET_LEADER]          = true,

            [GS.OrganizationPermissions.VIEW_TREASURY]       = true,
            [GS.OrganizationPermissions.MANAGE_TREASURY]     = true,

            [GS.OrganizationPermissions.CAPTURE_TERRITORY]   = true,
            [GS.OrganizationPermissions.RELEASE_TERRITORY]   = true,

            [GS.OrganizationPermissions.MANAGE_BUSINESS]     = true,

            [GS.OrganizationPermissions.DECLARE_WAR]         = true,
            [GS.OrganizationPermissions.MAKE_ALLIANCE]       = true,

            [GS.OrganizationPermissions.RECRUIT_AI]          = true,

            [GS.OrganizationPermissions.DELETE_ORGANIZATION] = true

        }

    },

    -----------------------------------------------------------------
    -- Co-Leader
    -----------------------------------------------------------------

    CoLeader = {

        Label = "Co-Leader",

        Weight = 90,

        Permissions = {

            [GS.OrganizationPermissions.INVITE_MEMBER]     = true,
            [GS.OrganizationPermissions.REMOVE_MEMBER]     = true,
            [GS.OrganizationPermissions.KICK_MEMBER]       = true,

            [GS.OrganizationPermissions.PROMOTE_MEMBER]    = true,
            [GS.OrganizationPermissions.DEMOTE_MEMBER]     = true,

            [GS.OrganizationPermissions.VIEW_TREASURY]     = true,
            [GS.OrganizationPermissions.MANAGE_TREASURY]   = true,

            [GS.OrganizationPermissions.CAPTURE_TERRITORY] = true,
            [GS.OrganizationPermissions.RELEASE_TERRITORY] = true,

            [GS.OrganizationPermissions.MANAGE_BUSINESS]   = true,

            [GS.OrganizationPermissions.RECRUIT_AI]        = true

        }

    },

    -----------------------------------------------------------------
    -- Officer
    -----------------------------------------------------------------

    Officer = {

        Label = "Officer",

        Weight = 70,

        Permissions = {

            [GS.OrganizationPermissions.INVITE_MEMBER] = true,
            [GS.OrganizationPermissions.KICK_MEMBER]   = true

        }

    },

    -----------------------------------------------------------------
    -- Member
    -----------------------------------------------------------------

    Member = {

        Label = "Member",

        Weight = 50,

        Permissions = {

        }

    },

    -----------------------------------------------------------------
    -- Recruit
    -----------------------------------------------------------------

    Recruit = {

        Label = "Recruit",

        Weight = 10,

        Permissions = {

        }

    }

}
