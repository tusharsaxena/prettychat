# PrettyChat Architecture

This document is a contributor-facing reference for how PrettyChat is wired together. User-facing usage lives in the [README](README.md); deep "how the panel was built" notes live in [CLAUDE.md](CLAUDE.md). This file covers the parts a new contributor needs to read code confidently.

## Module map

| File | Role |
|------|------|
| `PrettyChat.toc` | Addon metadata + load order. Pulls Ace3 libs, then loads `GlobalStrings/GlobalStrings_001…010.lua` eagerly, then `Defaults.lua` → `PrettyChat.lua` → `Schema.lua` → `Config.lua` → `GlobalStringSearch.lua`. |
| `Defaults.lua` | The `PrettyChatDefaults` global — canonical per-category format strings, labels, and per-category `enabled` flag. Single source of truth for what categories and strings exist. |
| `PrettyChat.lua` | AceAddon lifecycle (`OnInitialize`, `OnEnable`), `ApplyStrings()`, `Test()`, the ordered `COMMANDS` table for slash dispatch, and `ns.Print` (the `[PC]`-prefixed chat helper used by every other file). |
| `Schema.lua` | Builds a flat list of settable rows from `PrettyChatDefaults` at file-load. Exposes `ns.Schema` — the **single write path** shared by slash commands and panel widgets. |
| `Config.lua` | AceConfig options tables registered as Blizzard sub-pages (one per category, plus a virtual `General`). All widget get/set go through `ns.Schema`. |
| `GlobalStringSearch.lua` | Public search API over the `PrettyChatGlobalStrings` global (`FindByKey`, `FindByValue`, `Find`). Not currently consumed at runtime — kept for future debug tooling. |
| `GlobalStrings/` | The chunked Blizzard `GlobalStrings.lua` reference + a separate `LoadOnDemand` sub-addon TOC. See **GlobalStrings dual-load** below. |
| `Libs/` | Bundled Ace3 (LibStub, CallbackHandler-1.0, AceAddon-3.0, AceDB-3.0, AceConsole-3.0, AceGUI-3.0, AceConfig-3.0). |

Globals introduced by the addon: `PrettyChatDefaults` (Defaults.lua), `PrettyChatDB` (AceDB SavedVariables), `PrettyChatGlobalStrings` (GlobalStrings chunks). The addon namespace `ns` is captured by every file via `local addonName, ns = ...`.

## The override pipeline

1.  **`OnEnable`** walks `PrettyChatDefaults` and snapshots `_G[globalName]` for every string into `self.originalStrings`. This must happen before any override is applied — it's the only chance to capture Blizzard's pristine values for the runtime "restore" path.
2.  **`ApplyStrings()`** walks `PrettyChatDefaults` again and, for each `(category, globalName)`:
    - If addon-enabled **and** category-enabled **and** string-enabled → write `_G[globalName] = GetStringValue(category, globalName)` (user override, falling back to PrettyChat's default).
    - Otherwise → restore the snapshot (`_G[globalName] = self.originalStrings[globalName]`).
3.  **WoW's chat code** reads `_G[GLOBALNAME]` lazily as messages flow, so overrides take effect immediately and uniformly across any chat frame (default Blizzard, ElvUI, Glass, etc.). PrettyChat hooks no chat events and rewrites no messages.

The three enable layers resolve in this order on every `ApplyStrings` pass: **addon-wide → category → per-string**. The addon-wide toggle wins outright — when off, every Blizzard original is restored regardless of per-category and per-string state.

`ApplyStrings()` runs after every `Schema.Set`, every `ResetCategory`, and every `ResetAll` — so any settings change immediately re-resolves the override state for every key.

## Schema-driven settings

`Schema.lua` is the single source of truth for what's settable. At file-load it iterates `PrettyChatDefaults` (loaded earlier by the TOC) and emits a flat array of rows, one per settable value, addressed by dot path:

| Path | Type | Backed by |
|------|------|-----------|
| `General.enabled` | bool | `db.profile.enabled` (addon-wide master toggle; `General` is a virtual category — no entry in `PrettyChatDefaults`) |
| `<Category>.enabled` | bool | `db.profile.categories[Cat].enabled` (via `IsCategoryEnabled` / `EnsureCategoryDB`) |
| `<Category>.<GLOBALNAME>.enabled` | bool | `db.profile.categories[Cat].disabledStrings[NAME]` (inverted: `disabledStrings[NAME] = true` means disabled) |
| `<Category>.<GLOBALNAME>.format` | string | `db.profile.categories[Cat].strings[NAME]` (with default fallback) |

Each row carries its own `get()` and `set(value)` closures. PrettyChat's storage layout doesn't map 1:1 onto the path structure (the inverted `disabledStrings` table, the virtual `General` category, the default-fallback for formats), so a generic dot-walker doesn't fit — closures are simpler than a special-case resolver.

### The single write path

`Schema.Set(path, value)` is the **only** function that mutates settings:

- The slash dispatcher (`/pc set`) calls it with parsed CLI input.
- AceConfig widget set-callbacks in `Config.lua` call it from the panel.

After writing, `Set` runs `PrettyChat:ApplyStrings()` (so the live `_G` overrides reconcile) and calls `Schema.NotifyPanelChange(row.category)` (so an open AceConfig panel re-renders). This keeps the panel and the slash UI from ever drifting — a `/pc set` while the panel is open updates both surfaces.

**Auto-clear on default match**: for `string_format` rows specifically, the row's `set` closure stores `nil` (clears the override) when `value` matches the row's PrettyChat default. So writing a format back to its default value via `/pc set` or the panel acts as a per-string reset — the override entry is removed from `db.profile.categories[Cat].strings`, and `GetStringValue` falls back to the default on next read.

### Public API

| Function | Purpose |
|----------|---------|
| `Schema.AllRows()` | Full ordered row list (used by `/pc list` no-arg). |
| `Schema.RowsByCategory(category)` | Filtered subset (used by `/pc list <Category>` and Config.lua). |
| `Schema.FindByPath(path)` | O(1) lookup; returns the row or `nil`. |
| `Schema.Get(path)` / `Schema.Set(path, value)` | Read/write through the row's closures. |
| `Schema.ResolveCategory(name)` | Case-insensitive PascalCase resolver — `/pc reset loot` finds `Loot`. Returns `nil` for unknowns. |
| `Schema.NotifyPanelChange(category?)` | Calls `AceConfigRegistry:NotifyChange("PrettyChat_<Cat>")`. Pass `nil` to fire for every category. Safe to call before AceConfigRegistry is loaded — no-op. |
| `Schema.CATEGORY_ORDER` | Display order. Imported by `Config.lua` and `PrettyChat.lua`'s `Test()` and `/pc list` so left-rail order, list iteration order, and Test output order all stay aligned. |

## Saved variables

```
PrettyChatDB.profile.enabled                                         -- bool (addon-wide master toggle; nil = default true)
PrettyChatDB.profile.categories[catName].enabled                     -- bool (nil = default true)
PrettyChatDB.profile.categories[catName].strings[globalName]         -- string override (nil = use PrettyChat default)
PrettyChatDB.profile.categories[catName].disabledStrings[globalName] -- true = disabled (absent = enabled)
```

Only user-modified values are stored. The schema's auto-clear (above) keeps `strings[...]` lean — the table never collects "override that happens to equal the default".

Profiles use AceDB with a single shared **Default** profile (`db = AceDB:New("PrettyChatDB", defaults, true)` — the third arg is the profile name, "Default"). All characters on the account see the same configuration out of the box. Profile scoping UI (`AceDBOptions-3.0`) is **not** wired in today; adding it would be a small contribution — register the AceDBOptions table as another `PrettyChat_Profiles` sub-page in `Config.lua`.

## Settings panel wiring

PrettyChat appears in the Blizzard Settings panel under **Ka0s Pretty Chat**. The parent page hosts only a description; nine sub-pages hold actionable controls. Each sub-page is a sibling row in the addon list (no tabs in the right pane), so each gets the full pane width.

- Each category is registered as its own AceConfig options table (`PrettyChat_<Cat>`) and added via `AceConfigDialog:AddToBlizOptions(appName, displayName, PARENT_TITLE)`. The third arg nests the entry under the parent in the addon list.
- **General** is a *virtual category* — no entry in `PrettyChatDefaults`. It's built by a dedicated `BuildGeneralOptions()` in `Config.lua` and hosts: master Enable toggle, Test button, Reset All to Defaults.
- Each per-string row in a category sub-page is a 12-widget block (toggle, gold label, white globalname, paired Original/New labels, paired Original/New input boxes, full-width Preview label, full-width Preview input, spacers, HR). See `Config.lua`'s `BuildStringEntry` for the exact layout and the `width = "relative", relWidth = 0.5` trick used for the side-by-side rows.
- AceConfig `confirm = true` popups guard both the per-category Reset and the General Reset All buttons.

`PrettyChat.subFrames[category]` stores the frame returned by `AddToBlizOptions` for each sub-page. Currently unused at runtime, but available for a future `/pc config <Category>` direct-jump.

## Slash dispatch

`PrettyChat.lua` defines an ordered `COMMANDS` table at the top of the file — `{name, description, fn(self, rest)}` per row. The same table drives both the dispatch logic (`OnSlashCommand`) and the `/pc help` output (`printHelp`), so adding a new command is one-row work and the help text never drifts.

`OnSlashCommand(input)` parses `<command> <rest>`, lowercases the command name, and **preserves case in `rest`** so dot paths like `Loot.LOOT_ITEM_SELF.format` survive intact through to `set`/`get`. Both `/pc` and `/prettychat` route to the same dispatcher.

## Conventions

### Chat output

Every chat line the addon emits goes through `ns.Print(msg)` from `PrettyChat.lua`, which writes to `DEFAULT_CHAT_FRAME` and prepends a cyan `[PC]` prefix (`|cff00ffff[PC]|r `). Use `ns.Print`, not raw `print()` or `self:Print()`, so the prefix and color stay uniform across files.

`Test()` is the one intentional exception: sample lines are emitted via `DEFAULT_CHAT_FRAME:AddMessage` directly, **without** the `[PC]` prefix, so each rendered preview looks identical to a real loot/currency/XP chat message. Only the header and footer carry the prefix.

`printHelp` wraps slash commands in yellow (`|cffffff00`) and explanations in white (`|cffffffff`) via small `cmd()`/`note()` local helpers. The header line includes the addon version (`v<VERSION>`, read once at file load via `C_AddOns.GetAddOnMetadata`).

### Format strings

Color escapes use WoW's `|cAARRGGBB...|r` syntax (AA = alpha, always `ff`, then RRGGBB). The category-color palette lives in `Defaults.lua` — see the existing entries for the per-category convention (e.g. red `Loot` label, gold `Money` label).

Each Blizzard format string has a fixed signature (`%s`, `%d`, `%.1f`, `%2$s`, etc.). Replacements **must** consume the same conversions in the same order, or `string.format` will error at runtime when the line tries to render. The Settings panel's left edit box always shows Blizzard's exact original — copy from there and modify only the surrounding text and color escapes.

The house style for new defaults is `Category | Context | Source | +/- value`, each segment color-coded.

### Edit-box pipe escaping

WoW's chat input interprets `|c…|r` as inline color escapes the moment the user presses Enter. To send a literal `|` through `/pc set`, the user must type `||`. The settings panel's format input box wraps this internally — `Config.lua`'s edit-box `get` does `:gsub("|", "||")` and `set` does `:gsub("||", "|")`, so users see double-escaped strings while editing but `ns.Schema` always stores raw single-`|` format strings. `/pc get` output renders with colors applied (no double-escaping for reading).

## GlobalStrings dual-load

`GlobalStrings/` ships with both an eager-load path and a `LoadOnDemand` sub-addon — a quirk worth understanding before you touch the load order:

- **`PrettyChat.toc`** loads `GlobalStrings_001.lua` … `GlobalStrings_010.lua` directly at addon startup (between `Libs/` and `Defaults.lua`). This populates the `PrettyChatGlobalStrings` global so `Config.lua`'s "Original Format String" disabled input can resolve every key without an explicit load step.
- **`GlobalStrings/GlobalStrings.toc`** packages the same chunks as a separate `LoadOnDemand: 1` sub-addon (`PrettyChat - GlobalStrings`). `GlobalStringSearch:EnsureLoaded()` calls `C_AddOns.LoadAddOn("GlobalStrings")`, but because the chunks are already loaded by the main TOC, the call is effectively idempotent.

The redundant path exists for historical reasons — the sub-addon was originally LoD-only, then the main TOC was given the chunks directly when the Settings panel started rendering originals at panel-open time. The LoD packaging now mostly serves as a guard for a future world where the eager load is removed (e.g. to cut startup memory).

To regenerate the chunks after a WoW patch:

1.  Drop the new `GlobalStrings.lua` into `GlobalStrings/` (download from [townlong-yak](https://www.townlong-yak.com/framexml/live/Helix/GlobalStrings.lua)).
2.  `python3 GlobalStrings/split_globalstrings.py` — rewrites the chunk files and updates `GlobalStrings.toc`'s file list.

## Where to look first

- Adding a new category or string → `Defaults.lua`. Schema, Config, and slash UI all derive from this.
- Adding a new slash command → one row in `PrettyChat.lua`'s `COMMANDS` table.
- Changing how a setting is stored or how the panel reads/writes a value → `Schema.lua` (one closure per row).
- Changing the look of the per-string panel row → `Config.lua`'s `BuildStringEntry`.
- Changing the colors in default formats → `Defaults.lua`.
- Anything chat-output-related → start at `ns.Print` in `PrettyChat.lua`.
