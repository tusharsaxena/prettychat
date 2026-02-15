local addonName, ns = ...

local GlobalStringSearch = {}
ns.GlobalStringSearch = GlobalStringSearch

local loaded = false

--- Load the PrettyChat_GlobalStrings addon if not already loaded.
-- @return boolean true if data is available, false otherwise
function GlobalStringSearch:EnsureLoaded()
    if loaded then
        return true
    end
    local isLoaded, reason = C_AddOns.LoadAddOn("GlobalStrings")
    if not isLoaded then
        print("|cffff0000PrettyChat:|r Failed to load GlobalStrings data: " .. (reason or "unknown"))
        return false
    end
    loaded = true
    return true
end

local function Search(predicate, limit)
    if not GlobalStringSearch:EnsureLoaded() then return {} end
    limit = limit or 50
    local results = {}
    for key, value in pairs(PrettyChatGlobalStrings) do
        if predicate(key, value) then
            results[#results + 1] = { key = key, value = value }
            if #results >= limit then break end
        end
    end
    table.sort(results, function(a, b) return a.key < b.key end)
    return results
end

--- Search global string keys matching a pattern (case-insensitive).
-- @param pattern string Lua pattern to match against keys
-- @param limit number Maximum results to return (default 50)
-- @return table Array of {key, value} pairs
function GlobalStringSearch:FindByKey(pattern, limit)
    local lp = pattern:lower()
    return Search(function(k, _) return k:lower():find(lp, 1, true) end, limit)
end

--- Search global string values matching a pattern (case-insensitive).
-- @param pattern string Lua pattern to match against values
-- @param limit number Maximum results to return (default 50)
-- @return table Array of {key, value} pairs
function GlobalStringSearch:FindByValue(pattern, limit)
    local lp = pattern:lower()
    return Search(function(_, v) return v:lower():find(lp, 1, true) end, limit)
end

--- Search both keys and values matching a pattern (case-insensitive).
-- @param pattern string Lua pattern to match against keys and values
-- @param limit number Maximum results to return (default 50)
-- @return table Array of {key, value} pairs
function GlobalStringSearch:Find(pattern, limit)
    local lp = pattern:lower()
    return Search(function(k, v)
        return k:lower():find(lp, 1, true) or v:lower():find(lp, 1, true)
    end, limit)
end
