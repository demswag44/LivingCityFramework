---------------------------------------------------------------------
-- GS World Editor
--
-- File: permissions.lua
-- Purpose:
--     ACE permission helpers for editor access
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}

local Config = GSWorldEditor.Config

function GSWorldEditor.HasEditorPermission(source, permission)
    local playerSource = tonumber(source)

    if playerSource == 0 then
        return true
    end

    if not playerSource then
        return false
    end

    if IsPlayerAceAllowed(playerSource, Config.Permissions.Admin) then
        return true
    end

    if IsPlayerAceAllowed(playerSource, "command") then
        return true
    end

    if permission then
        return IsPlayerAceAllowed(playerSource, permission)
    end

    return IsPlayerAceAllowed(playerSource, Config.Permissions.Use)
end

function GSWorldEditor.HasToolSavePermission(source, permission)
    local playerSource = tonumber(source)

    if playerSource == 0 then
        return true
    end

    if not playerSource then
        return false
    end

    local permissions = {
        Config.Permissions.Admin,
        permission,
        "gs_organizations.admin",
        "gs_organizations.territories",
        "command",
        "command.org",
    }

    for _, ace in ipairs(permissions) do
        if ace and IsPlayerAceAllowed(playerSource, ace) then
            return true
        end
    end

    return false
end

HasEditorPermission = GSWorldEditor.HasEditorPermission
HasToolSavePermission = GSWorldEditor.HasToolSavePermission

exports("HasEditorPermission", function(source, permission)
    return GSWorldEditor.HasEditorPermission(source, permission)
end)

exports("HasToolSavePermission", function(source, permission)
    return GSWorldEditor.HasToolSavePermission(source, permission)
end)
