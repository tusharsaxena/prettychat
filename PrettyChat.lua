local addonName, ns = ...

local PrettyChat = LibStub("AceAddon-3.0"):NewAddon("PrettyChat", "AceConsole-3.0")

local Color  = ns.Const.Color
local PREFIX = ns.PREFIX
local L      = ns.L
local VERSION = ns.Compat.GetAddOnMetadata(addonName, "Version") or "?"

local cmd  = function(s) return Color.yellow .. s .. Color.reset end
local note = function(s) return Color.white  .. s .. Color.reset end

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

-- Session-only runtime flags — never persisted to SavedVariables.
ns.State = ns.State or { debug = false }

-- ns.Debug(tag, fmt, ...) — gated developer log. Returns on the first
-- line when off so the caller pays no formatting/allocation cost in the
-- common (disabled) case. Tier-1 addons have no debug window, so output
-- routes through ns.Print with a grey [tag] per §12.7. Toggle with
-- `/pc debug`.
function ns.Debug(tag, fmt, ...)
    if not ns.State.debug then return end
    local msg = fmt
    if select("#", ...) > 0 and type(fmt) == "string" then
        msg = fmt:format(...)
    end
    ns.Print(Color.grey .. "[" .. tostring(tag) .. "] " .. Color.reset .. tostring(msg))
end

local defaults = {
    profile = {
        -- Addon-wide and per-category `enabled` flags are intentionally
        -- absent. IsAddonEnabled / IsCategoryEnabled treat `nil` as
        -- default-true (see docs/schema.md), which keeps SavedVariables
        -- empty until the user disables something. The empty
        -- `categories` table is documentation-only — AceDB never merges
        -- {} into user-keyed sub-tables, so removing this line would be
        -- semantically identical.
        categories = {},
    },
}

function PrettyChat:OnInitialize()
    -- Merge Database's `global` defaults (schemaVersion) with the profile
    -- defaults above so AceDB provisions both namespaces.
    if ns.Database and ns.Database.defaults then
        for k, v in pairs(ns.Database.defaults) do
            defaults[k] = defaults[k] or v
        end
    end

    self.db = LibStub("AceDB-3.0"):New("PrettyChatDB", defaults, true)

    if ns.Database and ns.Database.RunMigrations then
        ns.Database.RunMigrations(self.db)
    end

    self:RegisterChatCommand("pc", "OnSlashCommand")
    self:RegisterChatCommand("prettychat", "OnSlashCommand")
end

function PrettyChat:OnEnable()
    self.originalStrings = {}
    for _, catData in pairs(ns.Defaults) do
        for globalName in pairs(catData.strings) do
            self.originalStrings[globalName] = _G[globalName]
        end
    end
    self:ApplyStrings()

    -- Settings.RegisterCanvasLayoutCategory is allowed in OnEnable for a
    -- non-LoD addon (OnEnable fires after the Settings API is live and
    -- after PLAYER_LOGIN). Folding panel registration into the AceAddon
    -- lifecycle removes Config.lua's parallel PLAYER_LOGIN bootstrap.
    if ns.Config and ns.Config.RegisterPanels then
        ns.Config.RegisterPanels()
    end
end

-- Expand the parent category in the Blizzard Settings left tree so
-- every sub-page is visible. Wrapped in pcall: SettingsPanel internals
-- (CategoryList, GetCategoryEntry, SetExpanded) are private API and
-- could shift between patches; if any call goes missing we return false
-- so OpenConfig can surface a one-time grey notice rather than silently
-- absorbing the regression.
local function expandMainCategory(cat)
    if not (cat and SettingsPanel) then return false end
    local ok, expanded = pcall(function()
        local list = SettingsPanel.GetCategoryList
            and SettingsPanel:GetCategoryList()
            or SettingsPanel.CategoryList
        if not (list and list.GetCategoryEntry) then return false end
        local entry = list:GetCategoryEntry(cat)
        if entry and entry.SetExpanded then
            entry:SetExpanded(true)
            return true
        end
        return false
    end)
    return ok and expanded
end

function PrettyChat:OpenConfig()
    -- Combat guard lives here (not just in the slash dispatcher) so any
    -- programmatic caller — other addons, a /run script, future internal
    -- code paths — is also gated. Settings.OpenToCategory triggers the
    -- protected category-switch code; calling it under combat lockdown
    -- taints the panel for the rest of the session.
    if InCombatLockdown and InCombatLockdown() then
        ns.Print(Color.grey .. "cannot open settings during combat — Blizzard's category-switch is protected" .. Color.reset)
        return
    end
    if not (Settings and Settings.OpenToCategory) then return end
    if not self.optionsCategoryID then return end
    local opened = Settings.OpenToCategory(self.optionsCategoryID)
    if opened == false then
        ns.Print(Color.grey .. "could not open settings panel — category not registered" .. Color.reset)
        return
    end
    if not expandMainCategory(self.optionsCategory) and not self._expandWarned then
        self._expandWarned = true
        ns.Print(Color.grey .. "(could not auto-expand the Pretty Chat sub-tree — click the parent row to expand)" .. Color.reset)
    end
end

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
                elseif self.originalStrings and self.originalStrings[globalName] then
                    _G[globalName] = self.originalStrings[globalName]
                end
            end
        end
    end
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
    self:ApplyStrings()
    if ns.Schema and ns.Schema.NotifyPanelChange then
        ns.Schema.NotifyPanelChange(category)
    end
end

function PrettyChat:ResetAll()
    self.db.profile.enabled    = nil
    self.db.profile.categories = {}
    self:ApplyStrings()
    if ns.Schema and ns.Schema.NotifyPanelChange then
        ns.Schema.NotifyPanelChange()  -- nil → all categories
    end
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
-- Every line carries the [PC] prefix so the report stays visually
-- distinct from real chat traffic interleaved with it.
function PrettyChat:Test(filter)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. note("sample of every format string (preview ignores enable toggles):"))
    if not self:IsAddonEnabled() then
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. note("(addon is currently disabled — these formats aren't being applied to live chat)"))
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
                    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. Color.gold .. "Category: " .. category .. Color.reset)
                    DEFAULT_CHAT_FRAME:AddMessage(PREFIX)

                    for _, globalName in ipairs(sortedNames) do
                        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. labelName .. globalName)

                        local origFmt = (self.originalStrings and self.originalStrings[globalName]) or _G[globalName]
                        local origLine, origErr = renderOrError(origFmt)
                        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. labelOriginal .. origLine)

                        local newFmt = self:GetStringValue(category, globalName)
                        local newLine, newErr = renderOrError(newFmt)
                        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. labelFormatted .. newLine)

                        DEFAULT_CHAT_FRAME:AddMessage(PREFIX)

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
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. note("(no matching strings)"))
        return
    end

    local footer = ("end of test output (%d %s shown"):format(
        printed, printed == 1 and "string" or "strings")
    if errored > 0 then
        footer = footer .. (", %d errored"):format(errored)
    end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. note(footer .. ")"))
end

-- ---------------------------------------------------------------------
-- Slash command dispatch — KickCD-style ordered command table
-- ---------------------------------------------------------------------
--
-- Each entry is {name, description, fn(self, rest)}. Help text is
-- generated from this same table so adding a new command means adding
-- one row. The schema-driven get/set/list go through ns.Schema so the
-- panel widgets and slash commands share a single write path.

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function formatValue(v)
    if v == nil then return "nil" end
    if type(v) == "boolean" then return tostring(v) end
    if type(v) == "string" then return ('%q'):format(v) end
    return tostring(v)
end

local function schemaReady()
    if not (ns.Schema and ns.Schema.RowsByCategory) then
        ns.Print("schema not ready yet")
        return false
    end
    return true
end

local printHelp, listSettings, getSetting, setSetting, runReset, runResetAll, runTest, runDebug

local COMMANDS = {
    {"help",     L["List available commands"],
        function(self) printHelp(self) end},
    {"config",   L["Open the settings panel"],
        function(self) self:OpenConfig() end},
    {"list",     L["List settings — `/pc list [<Category> | category | formatstring]`"],
        function(self, rest) listSettings(self, rest) end},
    {"get",      L["Print a setting's current value — `/pc get <path>`"],
        function(self, rest) getSetting(self, rest) end},
    {"set",      L["Set a setting — `/pc set <path> <value>` (try /pc list)"],
        function(self, rest) setSetting(self, rest) end},
    {"reset",    L["Reset a category to defaults — `/pc reset <Category>`"],
        function(self, rest) runReset(self, rest) end},
    {"resetall", L["Reset every category to addon defaults"],
        function(self) runResetAll(self) end},
    {"test",     L["Print sample chat lines — `/pc test [all | category <name> | formatstring <NAME>]`"],
        function(self, rest) runTest(self, rest) end},
    {"debug",    L["Toggle debug logging — `/pc debug [on | off | toggle]`"],
        function(self, rest) runDebug(self, rest) end},
}

-- Published so Config.lua's parent panel can render the slash-command list
-- from the same source the /pc help dispatcher uses, keeping the two surfaces
-- from drifting.
ns.COMMANDS = COMMANDS

function printHelp(self)
    ns.Print(note("v" .. VERSION .. " — slash commands (")
             .. cmd("/prettychat") .. note(" is an alias for ")
             .. cmd("/pc") .. note("):"))
    for _, entry in ipairs(COMMANDS) do
        ns.Print("  " .. cmd("/pc " .. entry[1]) .. " — " .. note(entry[2]))
    end
end

-- Two reserved sub-keywords intercepted before the category-name path:
--   `/pc list category`     → list every category name (alphabetical)
--   `/pc list formatstring` → list every Category.GLOBALNAME pair
-- Neither name is a valid category, so the existing ResolveCategory
-- branch could never have matched them — the keywords are unambiguous.

function listSettings(self, rest)
    if not schemaReady() then return end
    local arg = trim(rest)
    local lowered = arg:lower()

    if lowered == "category" then
        local sorted = {}
        for _, c in ipairs(ns.Schema.CATEGORY_ORDER) do sorted[#sorted + 1] = c end
        table.sort(sorted)
        ns.Print(note("Categories (" .. #sorted .. "):"))
        for _, c in ipairs(sorted) do ns.Print("  " .. c) end
        return
    end

    if lowered == "formatstring" then
        local pairs_ = {}
        for _, category in ipairs(ns.Schema.CATEGORY_ORDER) do
            local catData = ns.Defaults[category]
            if catData and catData.strings then
                for globalName in pairs(catData.strings) do
                    pairs_[#pairs_ + 1] = { category, globalName }
                end
            end
        end
        table.sort(pairs_, function(a, b)
            if a[1] == b[1] then return a[2] < b[2] end
            return a[1] < b[1]
        end)
        ns.Print(note("Format strings (" .. #pairs_ .. "):"))
        for _, p in ipairs(pairs_) do
            ns.Print(("  %s.%s"):format(p[1], p[2]))
        end
        return
    end

    -- No arg → dump every row across every category. With ~170 rows the
    -- output is long, but it's the only way the slash UI reaches parity
    -- with the panel (which exposes a toggle and a format edit-box per
    -- string). To filter, pass a category name (or one of the two
    -- reserved sub-keywords above).
    if arg == "" then
        ns.Print(note("Available settings (try ") .. cmd("/pc list <Category>")
                 .. note(", ") .. cmd("/pc list category")
                 .. note(", or ") .. cmd("/pc list formatstring") .. note("):"))
        for _, category in ipairs(ns.Schema.CATEGORY_ORDER) do
            ns.Print("  [" .. category .. "]")
            for _, row in ipairs(ns.Schema.RowsByCategory(category)) do
                ns.Print(("    %s = %s"):format(row.path, formatValue(ns.Schema.Get(row.path))))
            end
        end
        return
    end

    local matched = ns.Schema.ResolveCategory(arg)
    if not matched then
        ns.Print(note("unknown category '" .. arg .. "'. Valid: ")
                 .. table.concat(ns.Schema.CATEGORY_ORDER, ", "))
        return
    end
    ns.Print("[" .. matched .. "]")
    for _, row in ipairs(ns.Schema.RowsByCategory(matched)) do
        ns.Print(("  %s = %s"):format(row.path, formatValue(ns.Schema.Get(row.path))))
    end
end

function getSetting(self, rest)
    if not schemaReady() then return end
    local path = trim(rest):match("^(%S+)")
    if not path or path == "" then
        ns.Print("usage: " .. cmd("/pc get <path>"))
        return
    end
    local row = ns.Schema.FindByPath(path)
    if not row then
        ns.Print(note("setting not found: '" .. path .. "'"))
        return
    end
    ns.Print(("%s = %s"):format(path, formatValue(ns.Schema.Get(path))))
end

function setSetting(self, rest)
    if not schemaReady() then return end
    local path, value = trim(rest):match("^(%S+)%s*(.*)$")
    if not path or path == "" then
        ns.Print("usage: " .. cmd("/pc set <path> <value>"))
        return
    end
    local row = ns.Schema.FindByPath(path)
    if not row then
        ns.Print(note("setting not found: '" .. path .. "'"))
        return
    end

    local newVal
    if row.type == "bool" then
        local s = (value or ""):match("^(%S*)"):lower()
        if s == "true" or s == "1" or s == "on"  or s == "yes" then newVal = true
        elseif s == "false" or s == "0" or s == "off" or s == "no"  then newVal = false
        else
            ns.Print(note("invalid bool '" .. (value or "") .. "' (expected true/false/on/off/1/0/yes/no)"))
            return
        end
    elseif row.type == "string" then
        if value == nil or value == "" then
            ns.Print("usage: " .. cmd("/pc set " .. path .. " <value>"))
            return
        end
        newVal = value
    else
        ns.Print(note("unsupported type '" .. tostring(row.type) .. "'"))
        return
    end

    ns.Schema.Set(path, newVal)
    ns.Print(("%s = %s"):format(path, formatValue(ns.Schema.Get(path))))
end

function runReset(self, rest)
    local arg = trim(rest):match("^(%S+)")
    if not arg or arg == "" then
        ns.Print("usage: " .. cmd("/pc reset <Category>") .. note(". Valid: ")
                 .. table.concat(ns.Schema.CATEGORY_ORDER, ", "))
        return
    end
    local matched = ns.Schema.ResolveCategory(arg)
    if not matched then
        ns.Print(note("unknown category '" .. arg .. "'. Valid: ")
                 .. table.concat(ns.Schema.CATEGORY_ORDER, ", "))
        return
    end
    self:ResetCategory(matched)
    ns.Print(matched .. " reset to defaults")
end

function runResetAll(self)
    self:ResetAll()
    ns.Print(note("all settings reset to defaults"))
end

function runDebug(self, rest)
    local arg = trim(rest):lower()
    if arg == "on" then
        ns.State.debug = true
    elseif arg == "off" then
        ns.State.debug = false
    elseif arg == "" or arg == "toggle" then
        ns.State.debug = not ns.State.debug
    else
        ns.Print("usage: " .. cmd("/pc debug [on|off|toggle]"))
        return
    end
    ns.Print(note("debug logging " .. (ns.State.debug and "enabled" or "disabled")))
end

local function formatStringExists(globalName)
    for _, catData in pairs(ns.Defaults) do
        if catData.strings and catData.strings[globalName] then
            return true
        end
    end
    return false
end

function runTest(self, rest)
    local arg = trim(rest)
    if arg == "" or arg:lower() == "all" then
        self:Test()
        return
    end

    local kind, value = arg:match("^(%S+)%s*(.*)$")
    kind  = (kind or ""):lower()
    value = trim(value or "")

    if kind == "category" then
        if value == "" then
            ns.Print("usage: " .. cmd("/pc test category <name>") .. note(". Valid: ")
                     .. table.concat(ns.Schema.CATEGORY_ORDER, ", "))
            return
        end
        local matched = ns.Schema.ResolveCategory(value)
        if not matched then
            ns.Print(note("unknown category '" .. value .. "'. Valid: ")
                     .. table.concat(ns.Schema.CATEGORY_ORDER, ", "))
            return
        end
        self:Test({ kind = "category", value = matched })
        return
    end

    if kind == "formatstring" then
        if value == "" then
            ns.Print("usage: " .. cmd("/pc test formatstring <NAME>")
                     .. note(" — try ") .. cmd("/pc list formatstring"))
            return
        end
        local upper = value:upper()
        if not formatStringExists(upper) then
            ns.Print(note("unknown format string '" .. value .. "' — try ")
                     .. cmd("/pc list formatstring"))
            return
        end
        self:Test({ kind = "formatstring", value = upper })
        return
    end

    ns.Print("usage: " .. cmd("/pc test") .. note(", ")
             .. cmd("/pc test all") .. note(", ")
             .. cmd("/pc test category <name>") .. note(", or ")
             .. cmd("/pc test formatstring <NAME>"))
end

function PrettyChat:OnSlashCommand(input)
    local raw = trim(input)
    if raw == "" then return printHelp(self) end

    -- Lowercase the command name; preserve case in `rest` so dot paths
    -- like Loot.LOOT_ITEM_SELF.format survive intact through to set/get.
    local name, rest = raw:match("^(%S+)%s*(.*)$")
    name = (name or ""):lower()
    rest = rest or ""

    for _, entry in ipairs(COMMANDS) do
        if entry[1] == name then return entry[3](self, rest) end
    end

    ns.Print(note("unknown command '" .. name .. "'"))
    printHelp(self)
end
