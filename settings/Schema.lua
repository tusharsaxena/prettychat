local addonName, ns = ...

local PrettyChat = LibStub("AceAddon-3.0"):GetAddon("PrettyChat")

local Schema = {}
ns.Schema = Schema

-- Display order shared with Config.lua. Iterating ns.Defaults via
-- pairs() would give a non-deterministic order; this keeps `/pc list`
-- and the addon-list left rail in sync. "General" is a virtual category
-- (no entry in ns.Defaults) that hosts addon-wide settings —
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

-- Row `set` closures are pure DB writes — they do NOT call
-- PrettyChat:ApplyStrings() or Schema.NotifyPanelChange(). Both side
-- effects live in Schema.Set so a future Schema.SetMany / preset-load
-- can apply once per batch instead of once per row. Callers must go
-- through Schema.Set; never invoke row.set(value) directly.

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
        default  = (ns.Defaults[category] and ns.Defaults[category].enabled) and true or false,
        get      = function() return PrettyChat:IsCategoryEnabled(category) end,
        set      = function(v)
            PrettyChat:EnsureCategoryDB(category).enabled = v and true or false
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
            if v == ns.Defaults[category].strings[globalName].default then
                catDB.strings[globalName] = nil
            else
                catDB.strings[globalName] = v
            end
        end,
    })
end

-- Build the schema once at file load. ns.Defaults is populated by
-- Defaults.lua (loaded earlier by the TOC) and the addon object exists
-- (PrettyChat.lua's :NewAddon call ran), so closures bind to live values.
buildAddonEnabledRow()

for _, category in ipairs(CATEGORY_ORDER) do
    local catData = ns.Defaults[category]
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

-- Globals that ns.Defaults registers under more than one category
-- (today: LOOT_ITEM_CREATED_SELF and LOOT_ITEM_CREATED_SELF_MULTIPLE
-- under both Loot and Tradeskill). Each registration produces a separate
-- string_format row, both writing the same _G[GLOBALNAME] in
-- ApplyStrings — the last category to iterate wins on /reload, and
-- pairs() order is non-deterministic. The panel reads this map to
-- decorate the per-string enable checkbox tooltip so the user can see
-- the conflict in-page rather than discovering it via lost edits.
Schema.crossRegisteredGlobals = {}
do
    local seen = {}
    for _, r in ipairs(rows) do
        if r.kind == "string_format" then
            seen[r.globalName] = seen[r.globalName] or {}
            seen[r.globalName][#seen[r.globalName] + 1] = r.category
        end
    end
    for globalName, cats in pairs(seen) do
        if #cats > 1 then
            Schema.crossRegisteredGlobals[globalName] = cats
        end
    end
end

-- ---------------------------------------------------------------------
-- Load-time integrity check (§4.5 / PC-15). Every row's path must
-- resolve to a backing default in ns.Defaults, so drift between the
-- schema and the defaults surfaces loudly at load instead of as a silent
-- nil at runtime. The checked/failed counts are stashed on Schema for
-- the test harness to assert.
-- ---------------------------------------------------------------------

local function resolveBackingDefault(row)
    if row.kind == "addon_enabled" then
        return true                        -- General virtual master toggle
    end
    if row.kind == "category_enabled" then
        return ns.Defaults[row.category] ~= nil
    end
    -- string_enabled / string_format both back onto a per-string default.
    local cat = ns.Defaults[row.category]
    return (cat and cat.strings and cat.strings[row.globalName] ~= nil) and true or false
end

Schema.validation = { checked = 0, failed = 0, misses = {} }
for _, r in ipairs(rows) do
    Schema.validation.checked = Schema.validation.checked + 1
    if not resolveBackingDefault(r) then
        Schema.validation.failed = Schema.validation.failed + 1
        Schema.validation.misses[#Schema.validation.misses + 1] = r.path
        if ns.Print then
            ns.Print("|cffff5050[schema]|r unresolved path (no backing default): "
                     .. tostring(r.path))
        end
    end
end

-- ---------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------

function Schema.FindByPath(path)
    return byPath[path]
end

function Schema.Get(path)
    local row = byPath[path]
    if not row then return nil end
    return row.get()
end

-- Single, type-aware, schema-driven value formatter (Ka0s standard, slash-commands-§5).
-- Shared by `/pc list` rows and the `/pc get` / `/pc set` echo so the two surfaces can
-- never diverge. PrettyChat has two row types: bool → `true`/`false`; string → the raw
-- format string with `|` doubled to `||` so its embedded colour escapes render as literal
-- text (the same `||`-for-literal-pipe convention `/pc set` accepts as input) instead of
-- colouring the chat line.
function Schema.FormatValue(row, v)
    if v == nil then return "nil" end
    local vtype = row and row.type or type(v)
    if vtype == "bool" or type(v) == "boolean" then
        return tostring(v)
    end
    if type(v) == "string" then
        return (v:gsub("|", "||"))
    end
    return tostring(v)
end

-- Refresher dispatch. Config.lua registers a closure per sub-page on
-- first OnShow via Schema.RegisterRefresher; NotifyPanelChange invokes
-- the matching closure (or every closure when the master toggle moves —
-- per-string disabled state depends on the master). Sub-pages that have
-- never been opened have no entry, which is correct: their first OnShow
-- builds widgets seeded from the live DB, so they cannot show stale state.
Schema.refreshers = {}

function Schema.RegisterRefresher(category, fn)
    Schema.refreshers[category] = fn
end

function Schema.NotifyPanelChange(category)
    if category == "General" or category == nil then
        for _, fn in pairs(Schema.refreshers) do pcall(fn) end
        return
    end
    local fn = Schema.refreshers[category]
    if fn then pcall(fn) end
end

-- Set is the single write path for all schema-backed values. Both the
-- panel widgets and the /pc set slash command go through here, so
-- a value change in either surface notifies the other. Owns the two
-- post-write side effects (ApplyStrings + NotifyPanelChange) so row
-- closures can stay pure DB writes.
function Schema.Set(path, value)
    local row = byPath[path]
    if not row then return false end
    row.set(value)
    PrettyChat:ApplyStrings()
    Schema.NotifyPanelChange(row.category)
    -- The single settings-change trace (debug-logging-§10): logged once here, at the write
    -- seam, as `[Set] <path> = <value>` (shared value formatter, so it reads like /pc get).
    -- ApplyStrings' re-apply is an implied consequence and is deliberately not re-echoed.
    ns.Debug("Set", "%s = %s", path, Schema.FormatValue(row, value))
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
-- Falls back to an unambiguous case-insensitive prefix match (e.g.
-- `Loo` → `Loot`); ambiguous prefixes return nil so the caller surfaces
-- the same "unknown category" error rather than guessing.
function Schema.ResolveCategory(name)
    if type(name) ~= "string" or name == "" then return nil end
    local lower = name:lower()
    for _, c in ipairs(CATEGORY_ORDER) do
        if c:lower() == lower then return c end
    end
    local matched
    for _, c in ipairs(CATEGORY_ORDER) do
        if c:lower():find(lower, 1, true) == 1 then
            if matched then return nil end
            matched = c
        end
    end
    return matched
end
