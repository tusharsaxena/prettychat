# PrettyChat - WoW Addon

## Overview

PrettyChat is a World of Warcraft addon that reformats chat messages (loot, currency, money, reputation, XP, honor, tradeskill) with color-coded, pipe-delimited formatting. It overrides Blizzard's `GlobalStrings.lua` format strings rather than parsing chat messages directly, making it compatible with any UI framework (default Blizzard, ElvUI, etc.).

## Project Structure

```
PrettyChat.toc    # Addon metadata (Interface version, title, author, file list)
PrettyChat.lua    # Entire addon logic - single file
README.md         # CurseForge/GitHub description with screenshots
.gitignore        # OS/editor ignores
```

This is a minimal, single-file addon with no dependencies, no SavedVariables, and no configuration UI.

## How It Works

- Creates a frame that listens for `PLAYER_ENTERING_WORLD`
- On that event, overrides global string constants (e.g., `LOOT_ITEM`, `CURRENCY_GAINED`, `FACTION_STANDING_INCREASED`) with colorized versions
- Uses WoW's `|cAARRGGBB...|r` color escape sequences throughout
- Format: `Category | Context | Source | +/- value` with each segment color-coded

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

- **Interface version**: `120000` (The War Within / Retail). Classic/Classic Era not yet supported.
- **No build system** - the Lua file is loaded directly by WoW.
- The frame is named `LootLiteFrame` (appears to be a legacy name from an earlier iteration).
- There are duplicate assignments for `LOOT_ITEM_PUSHED_SELF` and `LOOT_ITEM_PUSHED_SELF_MULTIPLE` (lines 20-22).
- `LOOT_ITEM_CREATED_SELF` and `LOOT_ITEM_CREATED_SELF_MULTIPLE` are assigned twice: once under Loot (lines 14-15) and again under Tradeskill (lines 86-87), with the Tradeskill version taking precedence.
- The TOC title uses rainbow color escapes for display in the addon list.
- Bug reports go to: https://github.com/tusharsaxena/prettychat/issues

## WoW Addon Conventions

- `.toc` files define metadata and file load order
- Global string overrides must happen after the game loads defaults (hence `PLAYER_ENTERING_WORLD`)
- Color codes use `|cAARRGGBB` (AA = alpha, always `ff`) and `|r` to reset
- Format specifiers (`%s`, `%d`, `%.1f`) must match the original Blizzard string signatures exactly
