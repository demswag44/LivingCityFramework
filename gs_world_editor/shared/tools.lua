---------------------------------------------------------------------
-- GS World Editor
--
-- File: tools.lua
-- Purpose:
--     Shared editor tool registry API
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}

GSWorldEditor.Tools = GSWorldEditor.Tools or {}

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end

    local copied = {}

    for key, item in pairs(value) do
        copied[key] = Copy(item)
    end

    return copied
end

local function NormalizeTool(tool)
    if type(tool) ~= "table" then
        return nil, "Tool must be a table."
    end

    if type(tool.id) ~= "string" or tool.id == "" then
        return nil, "Tool id is required."
    end

    if type(tool.label) ~= "string" or tool.label == "" then
        return nil, "Tool label is required."
    end

    local normalized = Copy(tool)
    normalized.resource = normalized.resource or GetCurrentResourceName()
    normalized.category = normalized.category or "World"
    normalized.actions = normalized.actions or {}

    return normalized
end

function GSWorldEditor.RegisterTool(tool)
    local normalized, errorMessage = NormalizeTool(tool)

    if not normalized then
        return false, errorMessage
    end

    GSWorldEditor.Tools[normalized.id] = normalized

    return true, Copy(normalized)
end

function GSWorldEditor.GetTool(id)
    if type(id) ~= "string" then
        return nil
    end

    return Copy(GSWorldEditor.Tools[id])
end

function GSWorldEditor.GetTools()
    local tools = {}

    for _, tool in pairs(GSWorldEditor.Tools) do
        tools[#tools + 1] = Copy(tool)
    end

    table.sort(tools, function(left, right)
        return tostring(left.label) < tostring(right.label)
    end)

    return tools
end
