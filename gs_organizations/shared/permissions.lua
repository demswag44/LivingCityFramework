---------------------------------------------------------------------
-- GS Organizations
--
-- File: permissions.lua
-- Purpose:
--     Organization Permission Definitions
---------------------------------------------------------------------

GS = GS or {}

GS.OrganizationPermissions = {

    --------------------------------------------------
    -- Members
    --------------------------------------------------

    INVITE_MEMBER      = "INVITE_MEMBER",
    REMOVE_MEMBER      = "REMOVE_MEMBER",
    KICK_MEMBER        = "KICK_MEMBER",

    --------------------------------------------------
    -- Ranks
    --------------------------------------------------

    PROMOTE_MEMBER     = "PROMOTE_MEMBER",
    DEMOTE_MEMBER      = "DEMOTE_MEMBER",

    --------------------------------------------------
    -- Leadership
    --------------------------------------------------

    SET_LEADER         = "SET_LEADER",

    --------------------------------------------------
    -- Treasury
    --------------------------------------------------

    VIEW_TREASURY      = "VIEW_TREASURY",
    MANAGE_TREASURY    = "MANAGE_TREASURY",

    --------------------------------------------------
    -- Territory
    --------------------------------------------------

    CAPTURE_TERRITORY  = "CAPTURE_TERRITORY",
    RELEASE_TERRITORY  = "RELEASE_TERRITORY",

    --------------------------------------------------
    -- Businesses
    --------------------------------------------------

    MANAGE_BUSINESS    = "MANAGE_BUSINESS",

    --------------------------------------------------
    -- Diplomacy
    --------------------------------------------------

    DECLARE_WAR        = "DECLARE_WAR",
    MAKE_ALLIANCE      = "MAKE_ALLIANCE",

    --------------------------------------------------
    -- AI
    --------------------------------------------------

    RECRUIT_AI         = "RECRUIT_AI",

    --------------------------------------------------
    -- Administration
    --------------------------------------------------

    DELETE_ORGANIZATION = "DELETE_ORGANIZATION"

}

