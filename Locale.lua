local addonName, ns = ...

-- ns.L — localization table with English-key fallback. Keys ARE the
-- enUS strings, so a missing translation returns the key verbatim: any
-- unwrapped or untranslated string still renders in English (zero
-- behaviour change on enUS). Translators add locale files that assign
-- L["English source"] = "translated" under their own `GetLocale()` gate.
--
-- The seeded block below is the authoritative manifest of the addon's
-- user-facing string surface — every string wrapped in `L[...]` at a
-- call site appears here.

local L = setmetatable({}, {
    __index = function(_, k) return k end,
})
ns.L = L

-- enUS manifest (identity mappings — documents the translatable surface).
local enUS = {
    -- General sub-page
    "Addon-wide controls. The Enable toggle is the master switch — disable it and every Blizzard original is restored regardless of per-category settings.",
    "Enable PrettyChat",
    "Master switch for the addon. When off, all Blizzard originals are restored.",
    "Test",
    "Print a sample of every active format string to chat so you can see what real loot/currency/XP messages will look like.",
    "Reset all to defaults",
    "Reset every category and string to its default value.",
    "Reset every category and string to defaults?",
    "Defaults",
    -- Per-string row
    "Enable",
    "Use the rewritten format for this message. When unchecked, Blizzard's original is used.",
    "Original",
    "Original Format String",
    "Blizzard's original format. Read-only.",
    "(original not available)",
    "New",
    "New Format String",
    "Your replacement. Type `||` for a literal `|` (color codes use this).",
    "Reset",
    "Restore this string to its default.",
    "Preview",
    "The current format rendered with sample arguments.",
    -- Parent page
    "Slash Commands",
    "/prettychat is an alias for /pc",
    -- Slash-command help descriptions (shown in /pc help and the parent panel)
    "List available commands",
    "Open the settings panel",
    "List settings — `/pc list [<Category> | category | formatstring]`",
    "Print a setting's current value — `/pc get <path>`",
    "Set a setting — `/pc set <path> <value>` (try /pc list)",
    "Reset a category to defaults — `/pc reset <Category>`",
    "Reset every category to addon defaults",
    "Print sample chat lines — `/pc test [all | category <name> | formatstring <NAME>]`",
    "Toggle debug logging — `/pc debug [on | off | toggle]`",
}
for _, s in ipairs(enUS) do L[s] = s end
