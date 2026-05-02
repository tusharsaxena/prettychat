# PrettyChat - WoW Addon

## Overview

PrettyChat is a World of Warcraft addon that reformats chat messages (loot, currency, money, reputation, XP, honor, tradeskill) with color-coded, pipe-delimited formatting. It overrides Blizzard's `GlobalStrings.lua` format strings rather than parsing chat messages directly, making it compatible with any UI framework (default Blizzard, ElvUI, etc.).

## Project Structure

```
PrettyChat.toc          # Addon metadata, file load order, SavedVariables
PrettyChat.lua          # Core addon (AceAddon, AceDB, AceConsole)
Config.lua              # AceConfig-based settings UI
Defaults.lua            # PrettyChatDefaults table (all format strings)
GlobalStringSearch.lua  # Search API for GlobalStrings data (loaded with main addon)
README.md               # CurseForge/GitHub description with screenshots
.gitignore              # OS/editor ignores
Libs/                   # Bundled Ace3 libraries
GlobalStrings/          # LoadOnDemand sub-addon with searchable GlobalStrings data
  GlobalStrings.toc     # Sub-addon TOC (LoadOnDemand: 1)
  GlobalStrings.lua     # Bundled Blizzard reference (~1.57 MB, source file)
  GlobalStrings_001.lua # Chunk files (10 total, split by first letter of key)
  ...
  GlobalStrings_010.lua
  split_globalstrings.py  # Python script to regenerate chunk files
  README.md               # Usage instructions for the splitter script
```

## How It Works

- AceAddon initialization (`OnInitialize`) → creates AceDB database → registers `/pc` and `/prettychat` slash commands (both routed to `HandleSlashCommand`)
- `HandleSlashCommand(input)` dispatches: `config` → `OpenConfig()`; anything else (including no args) → `PrintHelp()`
- `OnEnable()` captures original Blizzard globals into `self.originalStrings`, then calls `ApplyStrings()` which overrides `_G[globalName]` for each enabled category/string and restores originals for disabled ones
- Config UI (`Config.lua`) is built dynamically from `PrettyChatDefaults` using AceConfig, with one tab per category
- Uses WoW's `|cAARRGGBB...|r` color escape sequences throughout
- Format: `Category | Context | Source | +/- value` with each segment color-coded

## Chat Output

All chat output produced by the addon flows through a single shared helper to keep formatting consistent.

- `PrettyChat.lua` captures the addon namespace via `local addonName, ns = ...` and exposes `ns.Print(msg)`.
- `ns.Print` writes to `DEFAULT_CHAT_FRAME` and prepends a cyan `[PC]` prefix (`|cff00ffff[PC]|r `) — defined as the `PREFIX` local in `PrettyChat.lua`.
- All addon files (e.g. `GlobalStringSearch.lua`) use `ns.Print` instead of raw `print()` or `self:Print()` so the prefix and color stay uniform.
- Inside `PrintHelp()`, slash commands are wrapped in yellow (`|cffffff00`) and explanatory notes in white (`|cffffffff`) via small `cmd()`/`note()` local helpers.

## Dependencies

Bundled Ace3 libraries (in `Libs/`):

- **LibStub** — library versioning
- **CallbackHandler-1.0** — event callback system
- **AceAddon-3.0** — addon lifecycle management
- **AceDB-3.0** — saved variables / profile database
- **AceConsole-3.0** — slash command registration
- **AceGUI-3.0** — GUI widget framework
- **AceConfig-3.0** — options table → UI generation (AceConfig, AceConfigDialog, AceConfigCmd)

## Configuration System

- **Slash commands** (both `/pc` and `/prettychat` are aliases of the same handler):
  - `/pc` (no args) — prints the help text via `ns.Print`
  - `/pc config` — opens the Blizzard settings panel to the PrettyChat parent page
  - any other arg falls through to help
- The settings UI uses **one Blizzard sub-page per category** — not tabs. Each category (Loot, Currency, Money, Reputation, Experience, Honor, Tradeskill, Misc) is registered as its own AceConfig options table and added to the Blizzard panel via `AceConfigDialog:AddToBlizOptions(appName, displayName, PARENT_TITLE)`. The third argument nests the entry under the parent in the addon list, so each category renders as a sibling row beneath "Ka0s Pretty Chat" with the full right-pane width to itself (no tab strip).
- The parent page ("Ka0s Pretty Chat") hosts only a description and the "Reset All to Defaults" button.
- `CATEGORY_ORDER` (in `Config.lua`) controls the display order of the sub-pages — iterating `pairs(PrettyChatDefaults)` directly would give a non-deterministic order, so the list is explicit.
- `PrettyChat.subFrames[category]` stores the frame returned by `AddToBlizOptions` for each sub-page (currently unused, available for `/pc config <Category>` direct-jump in future).
- Each format string is displayed as a **string set** with the following layout (12 elements per set, increment = 12):

  | Order | Key Suffix | Type | Width | Font Size | Content |
  |-------|-----------|------|-------|-----------|---------|
  | i | `_spacer_top` | description | full | — | `"\n"` spacer |
  | i+1 | `_toggle` | toggle | 0.4 | — | "Enable" checkbox |
  | i+2 | `_toggle_label` | description | 2.0 | large | Gold `strData.label` |
  | i+3 | `_toggle_globalname` | description | full | small | White `globalName` |
  | i+4 | `_original_label` | description | relative 0.5 | medium | Gold "Original Format String" |
  | i+5 | `_format_label` | description | relative 0.5 | medium | Gold "New Format String" |
  | i+6 | `_original` | input | relative 0.5 | — | Disabled edit box — original Blizzard string |
  | i+7 | *(globalName)* | input | relative 0.5 | — | Editable format box (escapes `\|` → `\|\|` for raw editing; unescapes on save) |
  | i+8 | `_preview_label` | description | full | medium | Gold "Preview" |
  | i+9 | `_preview` | input | full | — | Disabled edit box — rendered preview |
  | i+10 | `_spacer_bottom` | description | full | — | `"\n"` spacer |
  | i+11 | `_hr` | header | — | — | Horizontal rule separator |

  - "Width" semantics in AceConfig: a numeric `width = N` is `N × 170 px` **absolute**. A percentage of the row requires `width = "relative", relWidth = N` — that's how the side-by-side rows are wired.
  - Row 1: `_toggle` (0.4 × 170 = 68 px) + `_toggle_label` (2.0 × 170 = 340 px) sit on the same line
  - Row 2: `_toggle_globalname` (full) on its own line
  - Row 3: `_original_label` (rel 0.5) + `_format_label` (rel 0.5) — paired headers
  - Row 4: `_original` (rel 0.5) + *(globalName)* (rel 0.5) — paired edit boxes for direct comparison
  - Row 5: `_preview_label` (full)
  - Row 6: `_preview` (full)
- Per-category controls: enable/disable toggle and reset button at the top of each sub-page
- Key functions in `PrettyChat.lua`:
  - `ns.Print(msg)` — namespace-level helper that writes to `DEFAULT_CHAT_FRAME` with the cyan `[PC]` prefix; used by every file in the addon
  - `HandleSlashCommand(input)` — slash dispatcher; routes `config` to `OpenConfig()` and everything else to `PrintHelp()`
  - `PrintHelp()` — emits the slash-command help via `ns.Print`, with commands in yellow and notes in white
  - `GetStringValue(category, globalName)` — returns user override or default
  - `IsCategoryEnabled(category)` — returns user override or default enabled state
  - `IsStringEnabled(category, globalName)` — returns false if string is individually disabled
  - `EnsureCategoryDB(category)` — creates `db.profile.categories[category]` if nil, returns it
  - `ApplyStrings()` — writes enabled strings to `_G`, restores originals for disabled strings
  - `ResetCategory(category)` — clears saved overrides for one category
  - `ResetAll()` — clears all saved overrides
- Config.lua helpers:
  - Color constants: `GOLD`, `WHITE`, `RESET` — avoid repeated inline color escape strings
  - `MakeSpacer(order, width?)` — returns a spacer description widget (defaults to full width)
  - `MakeLabel(order, text, fontSize?, width?)` — returns a label description widget (defaults to full width)
  - `MakeDisabledInput(order, getter, width?)` — returns a disabled input widget (defaults to full width)
  - `BuildStringEntry(group, globalName, strData, category, i)` — populates all 12 widgets for one string set
  - `BuildCategoryOptions(category, catData)` — returns the root options table for one category sub-page (no nesting under `args[category]`)

## Database Structure

AceDB with default profile (`true` = shared default):

```
PrettyChatDB.profile.categories[catName].enabled                    -- boolean
PrettyChatDB.profile.categories[catName].strings[globalName]        -- string override
PrettyChatDB.profile.categories[catName].disabledStrings[globalName] -- true = disabled
```

Only user-modified values are stored; `nil` means "use default from `PrettyChatDefaults`". Disabled strings are tracked in `disabledStrings`; absent/nil means enabled.

## Categories

| Category    | Strings | Examples                                       |
|-------------|---------|------------------------------------------------|
| Loot        | 19      | `LOOT_ITEM`, `LOOT_ITEM_SELF`, bonus rolls     |
| Currency    | 4       | `CURRENCY_GAINED`, `CURRENCY_LOST_FROM_DEATH`   |
| Money       | 7       | `YOU_LOOT_MONEY`, `LOOT_MONEY_SPLIT`            |
| Reputation  | 14      | `FACTION_STANDING_INCREASED`, standing changes  |
| Experience  | 20      | `COMBATLOG_XPGAIN_*` (rested, group, raid, etc)|
| Honor       | 6       | `COMBATLOG_HONORGAIN`, `COMBATLOG_HONORAWARD`   |
| Tradeskill  | 8       | `CREATED_ITEM`, `OPEN_LOCK_SELF`                |
| Misc        | 3       | `ERR_QUEST_REWARD_EXP_I`, `ERR_ZONE_EXPLORED_XP`|

## Color Convention

| Color Code   | Usage                        |
|--------------|------------------------------|
| `ff0000`     | Loot category label          |
| `ff9900`     | Currency category label      |
| `ffff00`     | Money category label         |
| `00ff00`     | Rep category label           |
| `00ffff`     | XP category label; `[PC]` chat-output prefix |
| `4a86e8`     | Honor category label         |
| `ff00ff`     | Tradeskill category label    |
| `93c47d`     | "You" / self-referencing     |
| `f6b26b`     | Other player names / sources |
| `76a5af`     | Bonus / Standing context     |
| `e06666`     | Negative / Refund / Lost     |
| `cccccc`     | Generic / secondary labels   |
| `ffffff`     | Default / value text         |

## GlobalStrings Sub-Addon

`GlobalStrings/` is a LoadOnDemand sub-addon containing a searchable copy of Blizzard's `GlobalStrings.lua` (~22,879 entries), split into 10 chunk files by first letter of key.

- **Source file**: `GlobalStrings/GlobalStrings.lua` — the full Blizzard reference (not loaded by any TOC)
- **Chunk files**: `GlobalStrings/GlobalStrings_001.lua` through `GlobalStrings_010.lua` — populated into `PrettyChatGlobalStrings` table
- **Splitter script**: `GlobalStrings/split_globalstrings.py` — re-run after updating the source file (e.g., new WoW patch)
- **Search API**: `GlobalStringSearch.lua` (loaded with main addon) provides `EnsureLoaded()`, `FindByKey(pattern)`, `FindByValue(pattern)`, and `Find(pattern)` methods via `ns.GlobalStringSearch`. Internally uses a shared `Search(predicate, limit)` helper to eliminate duplication

## Development Notes

- **Version**: `1.3.0`
- **Interface version**: `120000,120001,120005` (The War Within / Midnight / Retail). Classic/Classic Era not yet supported.
- **No build system** — Lua files are loaded directly by WoW in the order specified in the TOC.
- `LOOT_ITEM_CREATED_SELF` and `LOOT_ITEM_CREATED_SELF_MULTIPLE` appear in both Loot and Tradeskill categories in `Defaults.lua`. Since `PrettyChatDefaults` is a Lua table, only one category will hold each key — whichever is iterated last by `ApplyStrings()` wins.
- The TOC title uses rainbow color escapes for display in the addon list.
- `Settings.OpenToCategory()` requires the category frame's `.name` property (returned by `AceConfigDialog:AddToBlizOptions()`), NOT a plain string name.
- Bug reports go to: https://github.com/tusharsaxena/prettychat/issues

## WoW Addon Conventions

- `.toc` files define metadata and file load order
- Global string overrides must happen after the game loads defaults (hence `OnEnable`)
- Color codes use `|cAARRGGBB` (AA = alpha, always `ff`) and `|r` to reset
- Format specifiers (`%s`, `%d`, `%.1f`) must match the original Blizzard string signatures exactly
