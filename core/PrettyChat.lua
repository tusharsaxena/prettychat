local addonName, ns = ...

-- Core AceAddon object + lifecycle. The override engine (snapshot / ApplyStrings / Test)
-- lives in modules/Override.lua; the /pc dispatcher in settings/Slash.lua. This file owns
-- registration, OnInitialize/OnEnable, the shared chat printer, and the combat-gated
-- panel open. Methods defined in the other files hang off this same PrettyChat object.

local PrettyChat = LibStub("AceAddon-3.0"):NewAddon("PrettyChat", "AceConsole-3.0")

local Color  = ns.Const.Color
local PREFIX = ns.PREFIX

-- Cyan [PC] chat printer — the single seam every module prints through (no raw print()).
function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
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
    local snapshot = 0
    for _ in pairs(self.originalStrings) do snapshot = snapshot + 1 end
    local applied, restored = self:ApplyStrings()

    -- Settings.RegisterCanvasLayoutCategory is allowed in OnEnable for a
    -- non-LoD addon (OnEnable fires after the Settings API is live and
    -- after PLAYER_LOGIN). Folding panel registration into the AceAddon
    -- lifecycle removes Panel.lua's parallel PLAYER_LOGIN bootstrap.
    local panels = false
    if ns.Config and ns.Config.RegisterPanels then
        ns.Config.RegisterPanels()
        panels = true
    end

    -- One-line boot summary (debug-logging-§8 lifecycle): schema version, unique globals
    -- captured, the initial apply result, and whether the options panels registered.
    local ver = (self.db and self.db.global and self.db.global.schemaVersion)
        or (ns.Database and ns.Database.SCHEMA_VERSION) or 0
    ns.Debug("Boot", "schema v%d · %d globals · applied %d restored %d · panels %s",
        ver, snapshot, applied, restored, panels and "ok" or "skipped")
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
    -- taints the panel for the rest of the session, so we refuse with a
    -- grey notice rather than deferring (Ka0s standard, options-ui-§2).
    if InCombatLockdown and InCombatLockdown() then
        ns.Print(Color.grey .. "cannot open settings during combat — Blizzard's category-switch is protected" .. Color.reset)
        ns.Debug("Config", "refused (in combat)")
        return
    end
    if not (Settings and Settings.OpenToCategory) or not self.optionsCategoryID then
        ns.Debug("Config", "unavailable (Settings API / category not ready)")
        return
    end
    local opened = Settings.OpenToCategory(self.optionsCategoryID)
    if opened == false then
        ns.Print(Color.grey .. "could not open settings panel — category not registered" .. Color.reset)
        ns.Debug("Config", "blocked (category not registered)")
        return
    end
    ns.Debug("Config", "opened")
    if not expandMainCategory(self.optionsCategory) and not self._expandWarned then
        self._expandWarned = true
        ns.Print(Color.grey .. "(could not auto-expand the Pretty Chat sub-tree — click the parent row to expand)" .. Color.reset)
    end
end
