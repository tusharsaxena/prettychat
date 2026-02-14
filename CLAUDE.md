# PrettyChat - WoW Addon

## Overview

PrettyChat is a World of Warcraft addon that reformats chat messages (loot, currency, money, reputation, XP, honor, tradeskill) with color-coded, pipe-delimited formatting. It overrides Blizzard's `GlobalStrings.lua` format strings rather than parsing chat messages directly, making it compatible with any UI framework (default Blizzard, ElvUI, etc.).

## Project Structure

```
PrettyChat.toc      # Addon metadata, file load order, SavedVariables
PrettyChat.lua      # Core addon (AceAddon, AceDB, AceConsole)
Config.lua          # AceConfig-based settings UI
Defaults.lua        # PrettyChatDefaults table (all format strings)
GlobalStrings.lua   # Bundled Blizzard reference (~1.57 MB)
README.md           # CurseForge/GitHub description with screenshots
.gitignore          # OS/editor ignores
Libs/               # Bundled Ace3 libraries
```

## How It Works

- AceAddon initialization (`OnInitialize`) → creates AceDB database → registers `/pc` and `/prettychat` slash commands
- `OnEnable()` captures original Blizzard globals into `self.originalStrings`, then calls `ApplyStrings()` which overrides `_G[globalName]` for each enabled category/string and restores originals for disabled ones
- Config UI (`Config.lua`) is built dynamically from `PrettyChatDefaults` using AceConfig, with one tab per category
- Uses WoW's `|cAARRGGBB...|r` color escape sequences throughout
- Format: `Category | Context | Source | +/- value` with each segment color-coded

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

- **Slash commands**: `/pc`, `/prettychat` — opens the Blizzard settings panel to the PrettyChat page
- AceConfig options table is built dynamically per category from `PrettyChatDefaults`
- Each format string is displayed as a **string set** with the following layout:
  - **Toggle** — per-string enable/disable checkbox (label in gold, GlobalString enum name in white)
  - **Format input** — editable edit box (escapes `|` → `||` for raw editing; unescapes on save), label in gold
  - **Preview label** — "Preview" in gold
  - **Preview input** — disabled edit box showing the current format string value
  - Separated by spacers and horizontal rules
- Per-category controls: enable/disable toggle and reset button at the top of each tab
- Key functions in `PrettyChat.lua`:
  - `GetStringValue(category, globalName)` — returns user override or default
  - `IsCategoryEnabled(category)` — returns user override or default enabled state
  - `IsStringEnabled(category, globalName)` — returns false if string is individually disabled
  - `ApplyStrings()` — writes enabled strings to `_G`, restores originals for disabled strings
  - `ResetCategory(category)` — clears saved overrides for one category
  - `ResetAll()` — clears all saved overrides

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
| `00ffff`     | XP category label            |
| `4a86e8`     | Honor category label         |
| `ff00ff`     | Tradeskill category label    |
| `93c47d`     | "You" / self-referencing     |
| `f6b26b`     | Other player names / sources |
| `76a5af`     | Bonus / Standing context     |
| `e06666`     | Negative / Refund / Lost     |
| `cccccc`     | Generic / secondary labels   |
| `ffffff`     | Default / value text         |

## Development Notes

- **Version**: `1.1.0`
- **Interface version**: `120000` (The War Within / Retail). Classic/Classic Era not yet supported.
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
