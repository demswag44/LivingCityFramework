---------------------------------------------------------------------
-- GS Organizations
--
-- File: delete.lua
-- Purpose:
--     Organization Deletion & Disbanding
---------------------------------------------------------------------

---------------------------------------------------------------------
-- GS Core
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

local Organization = GSOrganizations.Manager

---------------------------------------------------------------------
-- Delete
---------------------------------------------------------------------

function Organization.Delete(id)

    local organization = Organization.Get(id)

    if not organization then
        return false, "Organization not found."
    end

    --------------------------------------------------
    -- Remove from Runtime
    --------------------------------------------------

    Organization.Unregister(id)

    --------------------------------------------------
    -- Remove from Database
    --------------------------------------------------

    GSOrganizations.Database.Delete(

        id,

        function()

            Logger.Success(

                "ORGANIZATIONS",

                ("Organization deleted from database (#%d)")
                    :format(id)

            )

        end

    )

    --------------------------------------------------
    -- Log
    --------------------------------------------------

    Logger.Info(

        "ORGANIZATIONS",

        ("Organization Deleted: %s (#%d)")
            :format(
                organization.Name,
                id
            )

    )

    return true

end

---------------------------------------------------------------------
-- Disband
---------------------------------------------------------------------

function Organization.Disband(id)

    local organization = Organization.Get(id)

    if not organization then
        return false, "Organization not found."
    end

    --------------------------------------------------
    -- Future Hooks
    --------------------------------------------------

    -- Territory cleanup
    -- Business cleanup
    -- NPC cleanup
    -- Relationship cleanup
    -- Event notifications

    return Organization.Delete(id)

end

---------------------------------------------------------------------
-- Delete All
---------------------------------------------------------------------

function Organization.DeleteAll()

    local count = 0

    for id in pairs(Organization.GetAll()) do

        Organization.Delete(id)

        count = count + 1

    end

    Logger.Warning(

        "ORGANIZATIONS",

        ("Deleted %d organization(s)")
            :format(count)

    )

    return count

end

---------------------------------------------------------------------
-- Export
---------------------------------------------------------------------

return Organization