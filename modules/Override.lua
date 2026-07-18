local addonName, ns = ...

-- The override pipeline — PrettyChat's one feature module. Owns the enable-cascade
-- predicates, the ApplyStrings engine that rewrites _G[GLOBALNAME], the reset paths, and
-- the sample-render / Test engine. Methods hang off the shared PrettyChat AceAddon object
-- created in core/PrettyChat.lua; ns.RenderSample is published for the panel's Preview row.

local PrettyChat = LibStub("AceAddon-3.0"):GetAddon("PrettyChat")

local Color  = ns.Const.Color
local note   = ns.Util.note

function PrettyChat:GetStringValue(category, globalName)
    local catDB = self.db.profile.categories[category]
    if catDB and catDB.strings and catDB.strings[globalName] ~= nil then
        return catDB.strings[globalName]
    end
    return ns.Defaults[category].strings[globalName].default
end

function PrettyChat:IsAddonEnabled()
    if not (self.db and self.db.profile) then return true end
    if self.db.profile.enabled == nil then return true end
    return self.db.profile.enabled
end

function PrettyChat:IsCategoryEnabled(category)
    local catDB = self.db.profile.categories[category]
    if catDB and catDB.enabled ~= nil then
        return catDB.enabled
    end
    return ns.Defaults[category].enabled
end

function PrettyChat:IsStringEnabled(category, globalName)
    local catDB = self.db.profile.categories[category]
    if catDB and catDB.disabledStrings and catDB.disabledStrings[globalName] then
        return false
    end
    return true
end

function PrettyChat:EnsureCategoryDB(category)
    if not self.db.profile.categories[category] then
        self.db.profile.categories[category] = {}
    end
    return self.db.profile.categories[category]
end

function PrettyChat:ApplyStrings()
    -- The addon-wide toggle wins: when off, every Blizzard original is
    -- restored regardless of per-category / per-string state.
    --
    -- Iterate CATEGORY_ORDER (fixed order) and, within each category, a
    -- SORTED name list rather than pairs(ns.Defaults) (PC-16). A handful
    -- of globals are registered under more than one category (e.g.
    -- LOOT_ITEM_CREATED_SELF under Loot + Tradeskill); both write the same
    -- _G key, so the last category to run wins. Deterministic iteration
    -- makes that winner stable across /reload (documented last-writer:
    -- the later entry in CATEGORY_ORDER), instead of depending on
    -- non-deterministic hash order.
    local addonEnabled = self:IsAddonEnabled()
    local applied, restored = 0, 0
    for _, category in ipairs(ns.Schema.CATEGORY_ORDER) do
        local catData = ns.Defaults[category]
        if catData and catData.strings then
            local names = {}
            for globalName in pairs(catData.strings) do
                names[#names + 1] = globalName
            end
            table.sort(names)

            local catEnabled = addonEnabled and self:IsCategoryEnabled(category)
            for _, globalName in ipairs(names) do
                if catEnabled and self:IsStringEnabled(category, globalName) then
                    _G[globalName] = self:GetStringValue(category, globalName)
                    applied = applied + 1
                elseif self.originalStrings and self.originalStrings[globalName] then
                    _G[globalName] = self.originalStrings[globalName]
                    restored = restored + 1
                end
            end
        end
    end
    -- Return the pass counts so the caller (Schema.Set / a reset / boot) can fold them into
    -- its own single debug line — one summary per pass, never per string (debug-logging-§9).
    return applied, restored
end

function PrettyChat:ResetCategory(category)
    if category == "General" then
        -- The General virtual category owns only db.profile.enabled
        -- (no entry in db.profile.categories). Resetting it clears
        -- the addon-wide override back to default (true).
        self.db.profile.enabled = nil
    elseif self.db.profile.categories[category] then
        self.db.profile.categories[category] = nil
    end
    local applied, restored = self:ApplyStrings()
    if ns.Schema and ns.Schema.NotifyPanelChange then
        ns.Schema.NotifyPanelChange(category)
    end
    -- Bulk mutation (debug-logging-§8): a reset bypasses the Schema.Set `[Set]` seam, so it
    -- carries its own summary with the material effect (how many strings reverted).
    ns.Debug("Reset", "%s → applied %d restored %d", category, applied, restored)
end

function PrettyChat:ResetAll()
    self.db.profile.enabled    = nil
    self.db.profile.categories = {}
    local applied, restored = self:ApplyStrings()
    if ns.Schema and ns.Schema.NotifyPanelChange then
        ns.Schema.NotifyPanelChange()  -- nil → all categories
    end
    ns.Debug("Reset", "all → applied %d restored %d", applied, restored)
end

-- Restore ONE string to its untouched default. A per-string reset must
-- clear BOTH per-string dimensions — the custom format AND the disable
-- flag — so it matches the full-reset semantics of ResetCategory /
-- ResetAll (which wipe every dimension at once). Resetting only the
-- format would leave a previously-disabled string half-reset.
function PrettyChat:ResetString(category, globalName)
    local catDB = self.db.profile.categories[category]
    if catDB then
        if catDB.strings then catDB.strings[globalName] = nil end
        if catDB.disabledStrings then catDB.disabledStrings[globalName] = nil end
    end
    local applied, restored = self:ApplyStrings()
    if ns.Schema and ns.Schema.NotifyPanelChange then
        ns.Schema.NotifyPanelChange(category)
    end
    -- Bulk mutation (debug-logging-§8): bypasses the Schema.Set `[Set]` seam,
    -- so it carries its own summary with the material effect.
    ns.Debug("Reset", "%s.%s → applied %d restored %d", category, globalName, applied, restored)
end

-- ---------------------------------------------------------------------
-- Test — synthesize sample chat messages from each active format string
-- ---------------------------------------------------------------------
--
-- Walks the format string for printf-style conversions (%[n$][flags]
-- [width][.precision]type) and returns a list of placeholder values
-- typed to match each conversion. `%%` escapes are stripped first so
-- they don't confuse the gmatch. Positional `%n$type` is honored so
-- non-enUS locales (which use positional rearrangement freely) preview
-- correctly instead of failing string.format.
local function sampleArg(conversion)
    conversion = conversion:lower()
    if conversion == "s" then
        return "Sample"
    elseif conversion == "d" or conversion == "i" or conversion == "u"
        or conversion == "x" or conversion == "o" then
        return 42
    elseif conversion == "f" or conversion == "g" or conversion == "e" then
        return 1.5
    elseif conversion == "c" then
        return 65  -- 'A'
    end
    return "?"
end

local function buildSampleArgs(fmt)
    local clean = fmt:gsub("%%%%", "")
    local args = {}
    local appendIdx = 0
    local maxIdx    = 0
    for posCap, ftype in clean:gmatch("%%(%d*%$?)[%-+ #0]*%d*%.?%d*([%a])") do
        local val = sampleArg(ftype)
        if posCap:sub(-1) == "$" then
            local idx = tonumber(posCap:sub(1, -2))
            if idx and idx > 0 then
                args[idx] = val
                if idx > maxIdx then maxIdx = idx end
            end
        else
            appendIdx = appendIdx + 1
            args[appendIdx] = val
            if appendIdx > maxIdx then maxIdx = appendIdx end
        end
    end
    -- Fill positional gaps so unpack delivers a dense range. Without
    -- this, `%3$s only` would leave args[1] and args[2] nil and
    -- string.format would receive nils for those slots.
    for i = 1, maxIdx do
        if args[i] == nil then args[i] = "?" end
    end
    return args, maxIdx
end

-- Render a single format string with synthesized sample args, returning
-- the rendered line (or nil + error message on string.format failure).
-- Shared by `PrettyChat:Test()` and the per-string sample row in the
-- settings panel — keeps both in lockstep on placeholder choices and
-- positional-arg handling.
function ns.RenderSample(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil, "(empty format)" end
    local args, n = buildSampleArgs(fmt)
    local ok, result = pcall(string.format, fmt, unpack(args, 1, n))
    if ok then return result end
    return nil, result
end

-- Print every format string in a per-category block. For each string
-- show the global name, the rendered Blizzard original (from the
-- snapshot taken in OnEnable), and the rendered PrettyChat-configured
-- value — so the user can diff side by side regardless of the master
-- / per-category / per-string toggles. The toggles ONLY affect what
-- ApplyStrings writes to live chat; this preview is for the user.
--
-- `filter` is nil (= every string) or one of:
--   { kind = "category",     value = <canonical category name> }
--   { kind = "formatstring", value = <UPPERCASE_GLOBAL_NAME> }
-- The slash dispatch (runTest) is responsible for canonicalizing the
-- value before calling — Test only does an equality check.
--
-- Every line routes through ns.Print, so each carries the [PC] prefix and
-- the report stays visually distinct from real chat traffic interleaved with it.
function PrettyChat:Test(filter)
    ns.Print(note("sample of every format string (preview ignores enable toggles):"))
    if not self:IsAddonEnabled() then
        ns.Print(note("(addon is currently disabled — these formats aren't being applied to live chat)"))
    end

    local labelName      = Color.green .. "Name: "      .. Color.reset
    local labelOriginal  = Color.green .. "Original: "  .. Color.reset
    local labelFormatted = Color.green .. "Formatted: " .. Color.reset

    local function renderOrError(fmt)
        local rendered, err = ns.RenderSample(fmt)
        if rendered then return rendered, false end
        return Color.grey .. "(error: " .. tostring(err) .. ")" .. Color.reset, true
    end

    local printed, errored = 0, 0
    local emittedAny = false
    for _, category in ipairs(ns.Schema.CATEGORY_ORDER) do
        if not filter or filter.kind ~= "category" or filter.value == category then
            local catData = ns.Defaults[category]
            if catData and catData.strings and next(catData.strings) then
                local sortedNames = {}
                for globalName in pairs(catData.strings) do
                    if not filter or filter.kind ~= "formatstring" or filter.value == globalName then
                        sortedNames[#sortedNames + 1] = globalName
                    end
                end
                table.sort(sortedNames)

                if #sortedNames > 0 then
                    emittedAny = true
                    ns.Print(Color.gold .. "Category: " .. category .. Color.reset)
                    ns.Print("")

                    for _, globalName in ipairs(sortedNames) do
                        ns.Print(labelName .. globalName)

                        local origFmt = (self.originalStrings and self.originalStrings[globalName]) or _G[globalName]
                        local origLine, origErr = renderOrError(origFmt)
                        ns.Print(labelOriginal .. origLine)

                        local newFmt = self:GetStringValue(category, globalName)
                        local newLine, newErr = renderOrError(newFmt)
                        ns.Print(labelFormatted .. newLine)

                        ns.Print("")

                        if newErr or origErr then
                            errored = errored + 1
                        else
                            printed = printed + 1
                        end
                    end
                end
            end
        end
    end

    if not emittedAny then
        ns.Print(note("(no matching strings)"))
        return
    end

    local footer = ("end of test output (%d %s shown"):format(
        printed, printed == 1 and "string" or "strings")
    if errored > 0 then
        footer = footer .. (", %d errored"):format(errored)
    end
    ns.Print(note(footer .. ")"))
end
