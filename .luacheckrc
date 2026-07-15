-- Luacheck configuration for Ka0s Pretty Chat.
-- Run:  luacheck .

std = "lua51"
max_line_length = false
codes = true

-- Vendored libraries, the dated audit/review bundles, the headless test
-- harness, and the generated GlobalStrings data are not linted:
--   * libs/ (Libs kept too, defensively) — vendored Ace3.
--   * GlobalStrings/ — machine-generated data + the ~1.6MB source dump.
--   * docs/audits/, docs/reviews/ — frozen process bundles (no Lua).
--   * tests/ — runs under stock Lua 5.1, not the WoW std set.
exclude_files = {
    "Libs",
    "libs",
    "GlobalStrings",
    "docs/audits",
    "docs/reviews",
    "tests",
}

-- Ace3 methods take self/event params the addon does not always use;
-- `addonName` is the standard `local addonName, ns = ...` idiom, kept for
-- consistency even in files that only use `ns`.
ignore = { "212/self", "212/event", "211/addonName" }

-- Writable globals the addon owns.
--   PrettyChatDB       — SavedVariables.
--   StaticPopupDialogs — Blizzard table the addon registers a dialog on.
globals = {
    "PrettyChatDB",
    "StaticPopupDialogs",
    -- The debug console appends its window names to this Blizzard table.
    "UISpecialFrames",
}

-- Blizzard / WoW API surface the addon reads.
read_globals = {
    "LibStub",
    "C_AddOns",
    "C_Timer",
    "CreateFrame",
    "date",
    "wipe",
    "Settings",
    "SettingsPanel",
    "StaticPopup_Show",
    "DEFAULT_CHAT_FRAME",
    "GameTooltip",
    "InCombatLockdown",
    "GetAddOnMetadata",
    "UIParent",
    "YES",
    "NO",
    -- Font objects referenced by name.
    "GameFontNormal",
    "GameFontNormalLarge",
    "GameFontNormalHuge",
    "GameFontHighlight",
    "GameFontDisable",
}
