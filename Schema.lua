local addonName, ns = ...

local PrettyChat = LibStub("AceAddon-3.0"):GetAddon("PrettyChat")

local Schema = {}
ns.Schema = Schema

-- Display order shared with Config.lua. Iterating PrettyChatDefaults via
-- pairs() would give a non-deterministic order; this keeps `/pc list`
-- and the addon-list left rail in sync. "General" is a virtual category
-- (no entry in PrettyChatDefaults) that hosts addon-wide settings —
-- listed first so it sits at the top of the addon list.
local CATEGORY_ORDER = {
    "General",
    "Loot", "Currency", "Money", "Reputation",
    "Experience", "Honor", "Tradeskill", "Misc",
}
Schema.CATEGORY_ORDER = CATEGORY_ORDER

-- Four row kinds. Path scheme:
--   General.enabled                     → addon-wide master toggle (bool)
--   <Category>.enabled                  → category master toggle (bool)
--   <Category>.<GLOBALNAME>.enabled     → per-string enable toggle (bool)
--   <Category>.<GLOBALNAME>.format      → per-string format string
-- The dot path doesn't map 1:1 onto db.profile.categories[...], so each
-- row carries its own get/set closures rather than relying on a generic
-- dot-walker.

local rows = {}        -- ordered, used by /pc list
local byPath = {}      -- O(1) lookup by path string

local function addRow(row)
    rows[#rows + 1] = row
    byPath[row.path] = row
end

-- The single addon-wide row. Lives under the "General" virtual
-- category. When false, ApplyStrings restores every Blizzard original
-- regardless of per-category / per-string toggles.
local function buildAddonEnabledRow()
    addRow({
        path     = "General.enabled",
        category = "General",
        kind     = "addon_enabled",
        type     = "bool",
        label    = "Enable PrettyChat",
        default  = true,
        get      = function() return PrettyChat:IsAddonEnabled() end,
        set      = function(v)
            PrettyChat.db.profile.enabled = v and true or false
            PrettyChat:ApplyStrings()
        end,
    })
end

local function buildCategoryRow(category)
    addRow({
        path     = category .. ".enabled",
        category = category,
        kind     = "category_enabled",
        type     = "bool",
        label    = category .. " category",
        default  = (PrettyChatDefaults[category] and PrettyChatDefaults[category].enabled) and true or false,
        get      = function() return PrettyChat:IsCategoryEnabled(category) end,
        set      = function(v)
            PrettyChat:EnsureCategoryDB(category).enabled = v and true or false
            PrettyChat:ApplyStrings()
        end,
    })
end

local function buildStringRows(category, globalName, strData)
    addRow({
        path       = category .. "." .. globalName .. ".enabled",
        category   = category,
        globalName = globalName,
        kind       = "string_enabled",
        type       = "bool",
        label      = strData.label,
        default    = true,
        get        = function() return PrettyChat:IsStringEnabled(category, globalName) end,
        set        = function(v)
            local catDB = PrettyChat:EnsureCategoryDB(category)
            if not catDB.disabledStrings then catDB.disabledStrings = {} end
            catDB.disabledStrings[globalName] = (not v) or nil
            PrettyChat:ApplyStrings()
        end,
    })

    addRow({
        path       = category .. "." .. globalName .. ".format",
        category   = category,
        globalName = globalName,
        kind       = "string_format",
        type       = "string",
        label      = strData.label,
        default    = strData.default,
        get        = function() return PrettyChat:GetStringValue(category, globalName) end,
        set        = function(v)
            local catDB = PrettyChat:EnsureCategoryDB(category)
            if not catDB.strings then catDB.strings = {} end
            if v == PrettyChatDefaults[category].strings[globalName].default then
                catDB.strings[globalName] = nil
            else
                catDB.strings[globalName] = v
            end
            PrettyChat:ApplyStrings()
        end,
    })
end

-- Build the schema once at file load. PrettyChatDefaults is populated by
-- Defaults.lua (loaded earlier by the TOC) and the addon object exists
-- (PrettyChat.lua's :NewAddon call ran), so closures bind to live values.
buildAddonEnabledRow()

for _, category in ipairs(CATEGORY_ORDER) do
    local catData = PrettyChatDefaults[category]
    if catData then
        buildCategoryRow(category)

        local sortedNames = {}
        for globalName in pairs(catData.strings) do
            sortedNames[#sortedNames + 1] = globalName
        end
        table.sort(sortedNames)

        for _, globalName in ipairs(sortedNames) do
            buildStringRows(category, globalName, catData.strings[globalName])
        end
    end
end

-- ---------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------

function Schema.AllRows()
    return rows
end

function Schema.FindByPath(path)
    return byPath[path]
end

function Schema.Get(path)
    local row = byPath[path]
    if not row then return nil end
    return row.get()
end

-- NotifyPanelChange invalidates the AceConfigDialog cache for one
-- category (or every category if `category` is nil). An open panel
-- re-renders immediately; a closed panel re-renders next time it's
-- opened. Safe to call when the registry isn't loaded yet — no-op.
function Schema.NotifyPanelChange(category)
    local registry = LibStub("AceConfigRegistry-3.0", true)
    if not registry then return end
    if category then
        registry:NotifyChange("PrettyChat_" .. category)
    else
        for _, c in ipairs(CATEGORY_ORDER) do
            registry:NotifyChange("PrettyChat_" .. c)
        end
    end
end

-- Set is the single write path for all schema-backed values. Both the
-- AceConfig widgets and the /pc set slash command go through here, so
-- a value change in either surface notifies the other.
function Schema.Set(path, value)
    local row = byPath[path]
    if not row then return false end
    row.set(value)
    Schema.NotifyPanelChange(row.category)
    return true
end

function Schema.RowsByCategory(category)
    local out = {}
    for _, r in ipairs(rows) do
        if r.category == category then out[#out + 1] = r end
    end
    return out
end

-- Case-insensitive category lookup. Returns the canonical PascalCase
-- name from CATEGORY_ORDER if found, nil otherwise. Used by slash
-- commands so `/pc reset loot` works the same as `/pc reset Loot`.
function Schema.ResolveCategory(name)
    if type(name) ~= "string" or name == "" then return nil end
    local lower = name:lower()
    for _, c in ipairs(CATEGORY_ORDER) do
        if c:lower() == lower then return c end
    end
    return nil
end
