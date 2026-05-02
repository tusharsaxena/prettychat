# PrettyChat - WoW Addon

## Overview

PrettyChat is a World of Warcraft addon that reformats chat messages (loot, currency, money, reputation, XP, honor, tradeskill) with color-coded, pipe-delimited formatting. It overrides Blizzard's `GlobalStrings.lua` format strings rather than parsing chat messages directly, making it compatible with any UI framework (default Blizzard, ElvUI, etc.).

## Workflow

- **Do not auto-stage and do not auto-commit.** After making code changes, leave them as **unstaged** edits in the working tree and report what changed. Do NOT run `git add` (or `git stage`, `git commit`, `git push`, `git restore --staged`, etc.) without an explicit instruction from the user. The user decides when to stage and when to commit — those are two separate gates. Even after a multi-step refactor that "feels like" a natural commit point, wait for explicit phrasing (e.g. "stage this", "commit this", "commit and push") before running any git command that mutates the index, working tree, or refs. Read-only inspection (`git status`, `git diff`, `git log`) is fine without asking.
  - **Exception — `/wow-addon:commit`**: when the user invokes the `/wow-addon:commit` slash command, that invocation IS the explicit instruction to commit. The skill itself runs a "Commit with this message? (y/n/edit)" confirmation gate — a `y` reply *inside that flow* is the user's commit consent, and `git add` / `git commit` may proceed against the named files. The exception is narrowly scoped: it covers only `/wow-addon:commit` (and any future similarly-named explicit-commit skills like `/wow-addon:amend` if added). A casual mention of a commit elsewhere in conversation does NOT qualify, and a commit I propose on my own initiative still requires plain-language explicit ask.
- **Do not bump the version without an explicit instruction.** Leave `PrettyChat.toc` `## Version:` and `CLAUDE.md` "Version" alone unless the user says "bump version", "bump to X.Y.Z", or similar. Do NOT bump as a matter of course when shipping a feature, refactor, or fix — the user controls release cadence and may want multiple changes bundled into one version. Same for the README changelog: don't add a new `**_X.Y.Z_**` heading on your own; if the current version already has changelog notes, append to that section.

## Project Structure

```
PrettyChat.toc          # Addon metadata, load order, SavedVariables (also loads GlobalStrings chunks eagerly)
PrettyChat.lua          # Core addon (AceAddon, AceDB, AceConsole) + slash dispatch + Test()
Schema.lua              # Schema layer — flat row list generated from PrettyChatDefaults; shared write path for slash + panel
Config.lua              # AceConfig-based settings UI (widgets read/write via ns.Schema)
Defaults.lua            # PrettyChatDefaults table (all format strings)
GlobalStringSearch.lua  # Search API over PrettyChatGlobalStrings (loaded with main addon; API currently unused by slash commands)
README.md               # CurseForge/GitHub description with screenshots
LICENSE                 # MIT
.gitattributes          # Forces CRLF on disk for all text files (overrides per-user core.autocrlf)
.gitignore              # OS/editor ignores (also ignores TODO.md and .claude/)
Libs/                   # Bundled Ace3 libraries
media/                  # Source images (logo + screenshots) — local copies, not referenced by README which uses CDN URLs
GlobalStrings/          # GlobalStrings data — chunks loaded eagerly by PrettyChat.toc; also packaged as a LoadOnDemand sub-addon
  GlobalStrings.toc     # Sub-addon TOC ("PrettyChat - GlobalStrings", LoadOnDemand: 1) — see GlobalStrings Sub-Addon section for the dual-load story
  GlobalStrings.lua     # Bundled Blizzard reference (~1.6 MB, source file, not loaded by any TOC)
  GlobalStrings_001.lua # Chunk files (10 total, split by first letter of key)
  ...
  GlobalStrings_010.lua
  split_globalstrings.py  # Python script to regenerate chunk files
  README.md               # Usage instructions for the splitter script
```

## How It Works

- AceAddon initialization (`OnInitialize`) → creates AceDB database → registers `/pc` and `/prettychat` slash commands (both routed to `OnSlashCommand`)
- `OnSlashCommand(input)` parses `<command> <rest>`, lowercases the command name, preserves case in `rest` (so dot paths like `Loot.LOOT_ITEM_SELF.format` survive), and dispatches via the ordered `COMMANDS` table at the top of `PrettyChat.lua`
- `OnEnable()` captures original Blizzard globals into `self.originalStrings`, then calls `ApplyStrings()` which overrides `_G[globalName]` for each enabled category/string and restores originals for disabled ones
- Settings UI (`Config.lua`) is built dynamically from `PrettyChatDefaults` using AceConfig, with one Blizzard sub-page per category. Widget get/set callbacks delegate to `ns.Schema.Get`/`ns.Schema.Set`, so the panel and the slash UI share a single write path.
- Uses WoW's `|cAARRGGBB...|r` color escape sequences throughout
- Format: `Category | Context | Source | +/- value` with each segment color-coded

## Chat Output

All chat output produced by the addon flows through a single shared helper to keep formatting consistent.

- `PrettyChat.lua` captures the addon namespace via `local addonName, ns = ...` and exposes `ns.Print(msg)`.
- `ns.Print` writes to `DEFAULT_CHAT_FRAME` and prepends a cyan `[PC]` prefix (`|cff00ffff[PC]|r `) — defined as the `PREFIX` local in `PrettyChat.lua`.
- All addon files (e.g. `GlobalStringSearch.lua`) use `ns.Print` instead of raw `print()` or `self:Print()` so the prefix and color stay uniform.
- Inside `printHelp()`, slash commands are wrapped in yellow (`|cffffff00`) and explanatory notes in white (`|cffffffff`) via small `cmd()`/`note()` local helpers.

## Dependencies

Bundled Ace3 libraries (in `Libs/`):

- **LibStub** — library versioning
- **CallbackHandler-1.0** — event callback system
- **AceAddon-3.0** — addon lifecycle management
- **AceDB-3.0** — saved variables / profile database
- **AceConsole-3.0** — slash command registration
- **AceGUI-3.0** — GUI widget framework
- **AceConfig-3.0** — options table → UI generation (AceConfig, AceConfigDialog, AceConfigCmd)

## Schema Layer

`Schema.lua` is the single source of truth for what's settable. At file-load time (after `Defaults.lua` and `PrettyChat.lua`) it iterates `PrettyChatDefaults` and builds a flat array of rows, one per settable value, exposed at `ns.Schema`.

Four row kinds, addressed by dot path:

| Path | Type | Backed by |
|------|------|-----------|
| `General.enabled` | bool | `db.profile.enabled` (addon-wide master toggle; "General" is a virtual category — no entry in `PrettyChatDefaults`) |
| `<Category>.enabled` | bool | `db.profile.categories[Cat].enabled` (via `IsCategoryEnabled` / `EnsureCategoryDB`) |
| `<Category>.<GLOBALNAME>.enabled` | bool | `db.profile.categories[Cat].disabledStrings[NAME]` (inverted: `disabledStrings[NAME] = true` means disabled) |
| `<Category>.<GLOBALNAME>.format` | string | `db.profile.categories[Cat].strings[NAME]` (with default fallback) |

The addon-wide toggle wins: when `General.enabled` is false, `ApplyStrings` restores every Blizzard original regardless of per-category and per-string state.

Each row carries its own `get()` and `set(value)` closures — PrettyChat's storage layout doesn't map 1:1 to the path structure, so a generic dot-walker (KickCD's `Helpers.Resolve` style) doesn't fit. Closures are simpler than a special-case resolver.

Public API:

- `ns.Schema.AllRows()` — full ordered row list
- `ns.Schema.RowsByCategory(category)` — filtered subset
- `ns.Schema.FindByPath(path)` — exact lookup
- `ns.Schema.Get(path)` / `ns.Schema.Set(path, value)` — read/write through the row's closures. For `string_format` rows specifically, the row's `set` closure stores `nil` (clears the override) when `value` matches the row's PrettyChat default — so writing a format back to its default value via `/pc set` or the panel acts as a per-string reset
- `ns.Schema.ResolveCategory(name)` — case-insensitive lookup → canonical PascalCase name
- `ns.Schema.NotifyPanelChange(category?)` — calls `AceConfigRegistry:NotifyChange("PrettyChat_<Cat>")` so an open AceConfig panel re-renders. Called automatically by `Schema.Set`, `PrettyChat:ResetCategory`, and `PrettyChat:ResetAll`. Pass `nil` to fire for every category.
- `ns.Schema.CATEGORY_ORDER` — display order (also imported by `Config.lua` so left-rail order and `/pc list` order stay aligned)

`Schema.Set` is the **single write path** shared by every surface that mutates settings. AceConfig widget set-callbacks call it; `/pc set` calls it; both go through the same row's `set()` closure, which writes the DB and runs `PrettyChat:ApplyStrings()`. The panel re-syncs via `NotifyPanelChange`.

## Configuration System

- **Slash commands** (both `/pc` and `/prettychat` are aliases of the same handler — `OnSlashCommand`). The KickCD-style ordered `COMMANDS` table at the top of `PrettyChat.lua` drives both the help index and the dispatch table — adding a command means adding one `{name, description, fn(self, rest)}` row.

  | Command | Effect |
  |---------|--------|
  | `/pc` (no args) / `/pc help` | Print the help index via `ns.Print`. Header line includes the addon version (`v<VERSION>`, read from TOC `## Version:` via `C_AddOns.GetAddOnMetadata`). |
  | `/pc config` | Open the Blizzard settings panel to the parent page. Refuses during combat (`InCombatLockdown()`) — Blizzard's category-switch is protected and would taint the panel. |
  | `/pc list` | List every setting and its current value, grouped by category (~170 lines — matches KickCD's `/kcd list` behavior, and is the only way to reach panel/slash parity) |
  | `/pc list <Category>` | Filter to one category — case-insensitive, prints the category toggle + every per-string `.enabled` and `.format` row |
  | `/pc get <path>` | Print one row's current value |
  | `/pc set <path> <value>` | Write one row. `bool` accepts `true/false/on/off/yes/no/1/0`; `string` consumes the rest of the line literally. For `string_format` rows, setting `<value>` to the row's PrettyChat default clears the override (see Schema Layer for the auto-clear behavior). |
  | `/pc reset <Category>` | Clear all overrides for one category (case-insensitive name). For `General`, clears the addon-wide enabled override back to default (true). |
  | `/pc resetall` | Clear every category's overrides AND the addon-wide enabled flag |
  | `/pc test` | Print a sample of every format string to chat — preview ignores enable toggles, so it works even when the addon is disabled (same action as the General page's "Test" button) |
  | unknown command | Print the help index |

  Format-string `set` from chat is a power-user feature — chat input interprets `|c...|r` as inline color escapes, so users must double `||` to send a literal `|`. The settings panel is the recommended editing surface for format strings; `/pc get` output renders with colors applied (no double-escaping at print time).
- The settings UI uses **one Blizzard sub-page per category** — not tabs. Categories (`General`, Loot, Currency, Money, Reputation, Experience, Honor, Tradeskill, Misc) are each registered as their own AceConfig options table and added to the Blizzard panel via `AceConfigDialog:AddToBlizOptions(appName, displayName, PARENT_TITLE)`. The third argument nests the entry under the parent in the addon list, so each category renders as a sibling row beneath "Ka0s Pretty Chat" with the full right-pane width to itself (no tab strip).
- The **General sub-page** hosts addon-wide controls — built by `BuildGeneralOptions()` (in `Config.lua`), separate from the format-string `BuildCategoryOptions()` path because "General" is a virtual category with no entry in `PrettyChatDefaults`. It contains:
  - **Enable PrettyChat** toggle — bound to the `General.enabled` schema row. Master switch: when off, `ApplyStrings` restores every Blizzard original.
  - **Test** button — calls `PrettyChat:Test()`, which iterates EVERY format string regardless of enable toggles (so the preview works even when the addon is disabled), substitutes generic sample arguments for each `%[...]type` conversion, and prints the rendered result to `DEFAULT_CHAT_FRAME` so the user sees what each format looks like. If the addon is currently disabled, a `[PC]` notice is emitted alongside the header. Header and footer lines carry the `[PC]` prefix to bracket the test block; sample lines themselves are emitted *without* the prefix so each rendered preview looks identical to a real loot/currency/XP chat message. The footer reports the count of strings shown.
  - **Reset All to Defaults** button — was previously on the parent page; moved here so every actionable control lives one click in from the addon list. Renders an AceConfig confirm popup before clearing.
- The parent page ("Ka0s Pretty Chat") hosts only a description — no actionable buttons. Sub-categories own their own controls.
- `ns.Schema.CATEGORY_ORDER` (defined in `Schema.lua`, imported by `Config.lua`) controls the display order of the sub-pages and the iteration order in `/pc list` — iterating `pairs(PrettyChatDefaults)` directly would give a non-deterministic order, so the list is explicit.
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
- Per-category controls: enable/disable toggle and reset button at the top of each sub-page. The reset button uses an AceConfig confirm popup (`Reset all <Category> strings to defaults?`) before clearing.
- Key functions in `PrettyChat.lua`:
  - `ns.Print(msg)` — namespace-level helper that writes to `DEFAULT_CHAT_FRAME` with the cyan `[PC]` prefix; used by every file in the addon
  - `OnSlashCommand(input)` — slash dispatcher; iterates the local `COMMANDS` table and calls the matching entry's `fn(self, rest)`. Falls back to `printHelp` on empty/unknown.
  - `printHelp(self)` — emits the slash-command help via `ns.Print`, generated from the `COMMANDS` table so help and dispatch never drift. Header line includes the addon version (`v<VERSION>`) read once at file load via `C_AddOns.GetAddOnMetadata(addonName, "Version")`
  - `listSettings(self, rest)` / `getSetting(self, rest)` / `setSetting(self, rest)` / `runReset(self, rest)` / `runResetAll(self)` — schema-driven slash command bodies. All read/write via `ns.Schema`.
  - `GetStringValue(category, globalName)` — returns user override or default (read by `ns.Schema` row's `get()`)
  - `IsCategoryEnabled(category)` — returns user override or default enabled state
  - `IsStringEnabled(category, globalName)` — returns false if string is individually disabled
  - `EnsureCategoryDB(category)` — creates `db.profile.categories[category]` if nil, returns it
  - `IsAddonEnabled()` — returns `db.profile.enabled` (default true if nil); read by `ApplyStrings` and the `General.enabled` schema row
  - `ApplyStrings()` — writes enabled strings to `_G`, restores originals for disabled strings. Addon-wide disable wins over per-category / per-string state.
  - `ResetCategory(category)` — clears saved overrides for one category, then `NotifyPanelChange(category)`. Special case: `category == "General"` clears `db.profile.enabled` back to default.
  - `ResetAll()` — clears `db.profile.enabled` AND every category's overrides, then `NotifyPanelChange()` (every category)
  - `Test()` — synthesizes one sample chat line per format string (every category, every string — preview ignores enable toggles). `buildSampleArgs(fmt)` (file-local) parses `%[flags][width][.precision]type` conversions and produces typed placeholders (`"Sample"` for `%s`, `42` for integer types, `1.5` for floats, etc.); `pcall(string.format, ...)` keeps a malformed format from breaking the loop.
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
PrettyChatDB.profile.enabled                                         -- boolean (addon-wide master toggle; default true)
PrettyChatDB.profile.categories[catName].enabled                     -- boolean
PrettyChatDB.profile.categories[catName].strings[globalName]         -- string override
PrettyChatDB.profile.categories[catName].disabledStrings[globalName] -- true = disabled
```

Only user-modified values are stored; `nil` means "use default" (true for `enabled` / per-category enabled, the `PrettyChatDefaults` value for format strings). Disabled strings are tracked in `disabledStrings`; absent/nil means enabled.

## Categories

| Category    | Strings | Examples                                       |
|-------------|---------|------------------------------------------------|
| Loot        | 19      | `LOOT_ITEM`, `LOOT_ITEM_SELF`, bonus rolls     |
| Currency    | 4       | `CURRENCY_GAINED`, `CURRENCY_LOST_FROM_DEATH`   |
| Money       | 8       | `YOU_LOOT_MONEY`, `LOOT_MONEY_SPLIT`, `ERR_QUEST_REWARD_MONEY_S` |
| Reputation  | 14      | `FACTION_STANDING_INCREASED`, standing changes  |
| Experience  | 20      | `COMBATLOG_XPGAIN_*` (rested, group, raid, etc)|
| Honor       | 6       | `COMBATLOG_HONORGAIN`, `COMBATLOG_HONORAWARD`   |
| Tradeskill  | 8       | `CREATED_ITEM`, `OPEN_LOCK_SELF`                |
| Misc        | 2       | `ERR_QUEST_REWARD_EXP_I`, `ERR_ZONE_EXPLORED_XP`|

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

`GlobalStrings/` holds a searchable copy of Blizzard's `GlobalStrings.lua` (~22,879 entries), split into 10 chunk files by first letter of key. The chunks populate a single global table, `PrettyChatGlobalStrings`.

**Two TOCs reference these chunks** — this is intentional, but worth flagging because the historical name "LoadOnDemand sub-addon" is misleading about runtime behavior:

- **`PrettyChat.toc`** loads `GlobalStrings_001.lua` … `GlobalStrings_010.lua` *eagerly at addon startup* (load order: after `Libs/`, before `Defaults.lua`). This populates `PrettyChatGlobalStrings` so `Config.lua`'s "Original Format String" disabled input can resolve every key without an explicit load step.
- **`GlobalStrings/GlobalStrings.toc`** is a separate `LoadOnDemand: 1` sub-addon (`PrettyChat - GlobalStrings`, version `1.1.0`) that *also* loads the same chunks. `GlobalStringSearch.lua`'s `EnsureLoaded()` calls `C_AddOns.LoadAddOn("GlobalStrings")`, but because the chunks are already loaded by the main TOC, the call is effectively idempotent (Blizzard returns the addon as already-loaded).

The redundant load path exists for historical reasons: the sub-addon was originally LoD-only, then the main TOC was given the chunks directly when the Settings panel started rendering originals at panel-open time. The LoD packaging now mostly serves as a guard for a future world where the eager load is removed.

- **Source file**: `GlobalStrings/GlobalStrings.lua` — the full Blizzard reference (~1.6 MB), not loaded by any TOC; only used as input to `split_globalstrings.py`
- **Chunk files**: `GlobalStrings/GlobalStrings_001.lua` through `GlobalStrings_010.lua` — emit `PrettyChatGlobalStrings["KEY"] = "value"` assignments
- **Splitter script**: `GlobalStrings/split_globalstrings.py` — re-run after updating the source file (e.g., new WoW patch). Computes 10 balanced groups by letter, cleans up old chunk files, and rewrites `GlobalStrings.toc`'s file list
- **Search API**: `GlobalStringSearch.lua` (loaded with main addon) exposes `EnsureLoaded()`, `FindByKey(pattern)`, `FindByValue(pattern)`, and `Find(pattern)` via `ns.GlobalStringSearch`. Internally uses a shared `Search(predicate, limit)` helper. The API is *not currently consumed* by any slash command or panel widget — it's available for future debug tooling. `Config.lua` reads `_G.PrettyChatGlobalStrings` directly rather than going through this API.

## Development Notes

- **Version**: `1.2.0`
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
