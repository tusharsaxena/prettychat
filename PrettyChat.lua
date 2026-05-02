local addonName, ns = ...

local PrettyChat = LibStub("AceAddon-3.0"):NewAddon("PrettyChat", "AceConsole-3.0")

local PREFIX = "|cff00ffff[PC]|r "
local VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata
                 and C_AddOns.GetAddOnMetadata(addonName, "Version")) or "?"

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

local defaults = {
    profile = {
        enabled    = true,   -- addon-wide master toggle (General.enabled in Schema)
        categories = {},
    },
}

function PrettyChat:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("PrettyChatDB", defaults, true)

    self:RegisterChatCommand("pc", "OnSlashCommand")
    self:RegisterChatCommand("prettychat", "OnSlashCommand")
end

function PrettyChat:OnEnable()
    self.originalStrings = {}
    for cat, catData in pairs(PrettyChatDefaults) do
        for globalName in pairs(catData.strings) do
            self.originalStrings[globalName] = _G[globalName]
        end
    end
    self:ApplyStrings()
end

function PrettyChat:OpenConfig()
    Settings.OpenToCategory(self.optionsFrame.name)
end

function PrettyChat:GetStringValue(category, globalName)
    local catDB = self.db.profile.categories[category]
    if catDB and catDB.strings and catDB.strings[globalName] ~= nil then
        return catDB.strings[globalName]
    end
    return PrettyChatDefaults[category].strings[globalName].default
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
    return PrettyChatDefaults[category].enabled
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
    local addonEnabled = self:IsAddonEnabled()
    for category, catData in pairs(PrettyChatDefaults) do
        for globalName in pairs(catData.strings) do
            if addonEnabled
               and self:IsCategoryEnabled(category)
               and self:IsStringEnabled(category, globalName) then
                _G[globalName] = self:GetStringValue(category, globalName)
            elseif self.originalStrings and self.originalStrings[globalName] then
                _G[globalName] = self.originalStrings[globalName]
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
-- Walks the format string for printf-style conversions (%[flags][width]
-- [.precision]type) and returns a list of placeholder values typed to
-- match each conversion. `%%` escapes are stripped first so they don't
-- confuse the gmatch.
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
    for ftype in clean:gmatch("%%[%-+ #0]*%d*%.?%d*([%a])") do
        args[#args + 1] = sampleArg(ftype)
    end
    return args
end

-- Print one synthesized line per format string the user has configured,
-- regardless of the master / per-category / per-string toggles — so the
-- preview works as a "what do my formats look like?" check even when
-- the addon is disabled. The state of the toggles ONLY affects what
-- ApplyStrings writes to live chat; this preview is for the user.
--
-- Output goes to DEFAULT_CHAT_FRAME WITHOUT the [PC] prefix so each
-- sample line looks exactly like the real loot/currency/XP message
-- would. Header and footer ARE prefixed, so the test block is
-- bracketed visually.
function PrettyChat:Test()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PC]|r |cffffffffsample of every format string (preview ignores enable toggles):|r")
    if not self:IsAddonEnabled() then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PC]|r |cffffffff(addon is currently disabled — these formats aren't being applied to live chat)|r")
    end

    local printed = 0
    for _, category in ipairs(ns.Schema.CATEGORY_ORDER) do
        local catData = PrettyChatDefaults[category]
        if catData then
            local sortedNames = {}
            for globalName in pairs(catData.strings) do
                sortedNames[#sortedNames + 1] = globalName
            end
            table.sort(sortedNames)
            for _, globalName in ipairs(sortedNames) do
                local fmt = self:GetStringValue(category, globalName)
                local args = buildSampleArgs(fmt)
                local ok, result = pcall(string.format, fmt, unpack(args))
                if ok then
                    DEFAULT_CHAT_FRAME:AddMessage(result)
                    printed = printed + 1
                end
            end
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage(("|cff00ffff[PC]|r |cffffffffend of test output (%d %s shown)|r")
        :format(printed, printed == 1 and "string" or "strings"))
end

-- ---------------------------------------------------------------------
-- Slash command dispatch — KickCD-style ordered command table
-- ---------------------------------------------------------------------
--
-- Each entry is {name, description, fn(self, rest)}. Help text is
-- generated from this same table so adding a new command means adding
-- one row. The schema-driven get/set/list go through ns.Schema so the
-- panel widgets and slash commands share a single write path.

local cmd  = function(s) return "|cffffff00" .. s .. "|r" end
local note = function(s) return "|cffffffff" .. s .. "|r" end

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function formatValue(v)
    if v == nil then return "nil" end
    if type(v) == "boolean" then return tostring(v) end
    if type(v) == "string" then return ('"%s"'):format(v) end
    return tostring(v)
end

local function schemaReady()
    if not (ns.Schema and ns.Schema.AllRows) then
        ns.Print("schema not ready yet")
        return false
    end
    return true
end

local printHelp, listSettings, getSetting, setSetting, runReset, runResetAll

local COMMANDS = {
    {"help",     "List available commands",
        function(self) printHelp(self) end},
    {"config",   "Open the settings panel",
        function(self)
            if InCombatLockdown and InCombatLockdown() then
                ns.Print(note("cannot open settings during combat"))
                return
            end
            self:OpenConfig()
        end},
    {"list",     "List every setting and its current value — try `/pc list <Category>` to filter",
        function(self, rest) listSettings(self, rest) end},
    {"get",      "Print a setting's current value — `/pc get <path>`",
        function(self, rest) getSetting(self, rest) end},
    {"set",      "Set a setting — `/pc set <path> <value>` (try /pc list)",
        function(self, rest) setSetting(self, rest) end},
    {"reset",    "Reset a category to defaults — `/pc reset <Category>`",
        function(self, rest) runReset(self, rest) end},
    {"resetall", "Reset every category to addon defaults",
        function(self) runResetAll(self) end},
    {"test",     "Print a sample of every active format string to chat",
        function(self) self:Test() end},
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

function listSettings(self, rest)
    if not schemaReady() then return end
    local arg = trim(rest)

    -- No arg → dump every row across every category, matching KickCD's
    -- /kcd list. With ~170 rows the output is long, but it's the only
    -- way the slash UI reaches parity with the panel (which exposes a
    -- toggle and a format edit-box per string). To filter, pass one
    -- category name as an argument.
    if arg == "" then
        ns.Print(note("Available settings (try ") .. cmd("/pc list <Category>")
                 .. note(" to filter):"))
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
