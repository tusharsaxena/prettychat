# Module map

Per-module roles + public APIs. Pair this with [override-pipeline.md](./override-pipeline.md) for how the modules talk to each other at runtime.

## Subsystem diagram

```
defaults/Defaults.lua  ──▶ ns.Defaults (categories + format strings)
                    │
                    ├──▶ settings/Schema.lua ──▶ ns.Schema  (rows[], byPath[], single write path)
                    │                       │
                    │                       ├──▶ /pc set / get / list / reset   (settings/Slash.lua)
                    │                       └──▶ Panel widget get/set           (settings/Panel.lua)
                    │
                    └──▶ modules/Override.lua ApplyStrings()
                                │
                                ▼
                          _G[GLOBALNAME]   ◀── WoW chat code reads lazily on every line

GlobalStrings/  ──▶ ns.GlobalStrings (Blizzard reference, ~22,879 entries)
                       │
                       └──▶ settings/Panel.lua "Original Format String" disabled input
```

## Namespace publishing pattern

Every file captures the addon namespace with the same idiom at the top:

```lua
local addonName, ns = ...
```

Public surfaces are exposed on `ns`:

| Member | Set by | Used by |
|--------|--------|---------|
| `ns.Compat` | `core/Compat.lua` | `core/Namespace.lua`, `settings/Slash.lua`, `settings/Panel.lua` (`Compat.GetAddOnMetadata` — C_AddOns vs legacy global) |
| `ns.Const` / `ns.PREFIX` | `core/Constants.lua` | `settings/Panel.lua` (padding / header height / spacers / `Color` palette / `BUTTON_PAIR_REL`); `settings/Slash.lua` (slash-output `Color` codes); `core/Util.lua` (colour-wrap helpers); `core/DebugLog.lua` (`FONT_MONO`); `core/PrettyChat.lua` (`Color` palette; `ns.PREFIX` = shared cyan `[PC]` tag read by `ns.Print`) |
| `ns.name` / `ns.version` | `core/Namespace.lua` | identity bootstrap (records addon name + TOC version so no module re-queries the TOC) |
| `ns.State` | `core/State.lua` | `core/DebugLog.lua`, `settings/Slash.lua` (session-only `debug` flag; `{ debug = false }`, reset every reload/login) |
| `ns.Util` | `core/Util.lua` | `settings/Slash.lua`, `core/DebugLog.lua` (`trim` / `note` / `cmd` string helpers) |
| `ns.Database` | `core/Database.lua` | `core/PrettyChat.lua` (`OnInitialize` merges `global.schemaVersion` defaults + runs `RunMigrations`) |
| `ns.DebugLog` / `ns.Debug(tag, fmt, …)` | `core/DebugLog.lua` | every file (on-screen debug console; `ns.Debug` gated on session-only `ns.State.debug`, routed to the console, driven by `/pc debug` through the `DebugLog:SetEnabled` seam) |
| `ns.Print(msg)` | `core/PrettyChat.lua` | every file (cyan `[PC]` chat-output chokepoint) |
| `ns.Defaults` | `defaults/Defaults.lua` | `settings/Schema.lua`, `modules/Override.lua`, `settings/Slash.lua`, `settings/Panel.lua` (category → format-string defaults) |
| `ns.L` | `locales/enUS.lua` | `settings/Panel.lua`, `settings/Slash.lua` (English-key localization; `__index` returns the key) |
| `ns.GlobalStrings` | `GlobalStrings/` chunks | `settings/Panel.lua` ("Original Format String" display) |
| `ns.Schema` | `settings/Schema.lua` | `settings/Slash.lua` (slash dispatch), `settings/Panel.lua` (every widget get/set; registers a per-sub-page refresh closure via `Schema.RegisterRefresher` on first `OnShow`) |
| `ns.RenderSample(fmt)` | `modules/Override.lua` | `settings/Panel.lua` (per-string Preview EditBox) |
| `ns.COMMANDS` | `settings/Slash.lua` | `settings/Panel.lua` (parent page's slash-command list — keeps panel and `/pc help` in lockstep with one source) |
| `ns.Config.RegisterPanels()` | `settings/Panel.lua` | `core/PrettyChat.lua` (`OnEnable` calls it after the snapshot/`ApplyStrings` pair, replacing the old `PLAYER_LOGIN` bootstrap frame) |

The addon object itself (`PrettyChat`, an `AceAddon-3.0` object) is **not** published on `ns`. Other files reach it via `LibStub("AceAddon-3.0"):GetAddon("PrettyChat")`.

## Public APIs

### `PrettyChat` (the AceAddon object — methods split across three files)

The object is registered in `core/PrettyChat.lua`; its methods hang off that shared object from several files — lifecycle + printer + panel-open in `core/PrettyChat.lua`, the override engine in `modules/Override.lua`, and the slash dispatch in `settings/Slash.lua`.

```lua
-- Lifecycle (core/PrettyChat.lua)
PrettyChat:OnInitialize()              -- AceDB, slash registration ("/pc" + "/prettychat")
PrettyChat:OnEnable()                  -- snapshot Blizzard originals → ApplyStrings → RegisterPanels
PrettyChat:OpenConfig()                -- Settings.OpenToCategory(self.optionsCategoryID); then expandMainCategory(self.optionsCategory) walks SettingsPanel:GetCategoryList():GetCategoryEntry(cat):SetExpanded(true) in pcall to unfold the sub-tree

-- Override pipeline (modules/Override.lua — also see override-pipeline.md)
PrettyChat:ApplyStrings()              -- writes enabled overrides to _G; restores originals for disabled ones
PrettyChat:ResetCategory(category)     -- clears one category's overrides + ApplyStrings + NotifyPanelChange
PrettyChat:ResetAll()                  -- clears every category + the addon-wide flag + ApplyStrings + NotifyPanelChange
PrettyChat:Test(filter?)               -- prints a per-category Original-vs-Formatted block per string (ignores enable toggles); filter is nil | {kind="category", value=…} | {kind="formatstring", value=…}

-- Read helpers (used by Schema closures, ApplyStrings, panel widgets)
PrettyChat:GetStringValue(category, globalName)   -- user override falling back to ns.Defaults
PrettyChat:IsAddonEnabled()                       -- nil → default true
PrettyChat:IsCategoryEnabled(category)            -- nil → default true (from ns.Defaults)
PrettyChat:IsStringEnabled(category, globalName)  -- false iff disabledStrings[NAME] == true
PrettyChat:EnsureCategoryDB(category)             -- creates db.profile.categories[Cat] if missing, returns it

-- Slash dispatch (settings/Slash.lua)
PrettyChat:OnSlashCommand(input)       -- parses verb + rest, dispatches via the COMMANDS table
```

### `ns.Schema` (`settings/Schema.lua`)

See [schema.md](./schema.md) for the row kinds, the single write path, and the auto-clear-on-default behavior.

```lua
ns.Schema.RowsByCategory(category)             -- filtered subset for one category
ns.Schema.FindByPath(path)                     -- O(1) lookup by dot path
ns.Schema.Get(path)                            -- read through the row's get() closure
ns.Schema.Set(path, value)                     -- DB write (row's set closure) → ApplyStrings → NotifyPanelChange
ns.Schema.FormatValue(row, value)              -- type-aware display string (bool → true/false; string → format with `|` doubled to `||`); shared by /pc list rows and the get/set echo
ns.Schema.ResolveCategory(name)                -- case-insensitive "loot" → "Loot"; falls back to unambiguous prefix
ns.Schema.NotifyPanelChange(category?)         -- invokes the closure registered for `category`; nil or "General" runs every closure
                                               -- (per-string disabled state depends on master, so master changes cascade)
ns.Schema.RegisterRefresher(category, fn)      -- settings/Panel.lua registers a per-sub-page refresh closure on first OnShow
ns.Schema.crossRegisteredGlobals               -- map of globalName → {Cat1, Cat2, …} for globals registered under >1 category
ns.Schema.CATEGORY_ORDER                       -- canonical display order (also drives /pc list, panel left-rail)
```

### `ns.Print` (`core/PrettyChat.lua`)

```lua
ns.Print(msg)   -- DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)   where PREFIX is built from ns.Const.Color.cyan
```

The single chokepoint for addon chat output. Use this, not raw `print()` or `self:Print()`, so the prefix and color stay uniform across files.

`Test()` is an intentional exception — sample lines are emitted via `DEFAULT_CHAT_FRAME:AddMessage` *without* the `[PC]` prefix so each rendered preview looks like a real chat message. Header/footer carry the prefix.

## Load order

`PrettyChat.toc` is the source of truth. Order is dependency, not alphabetical:

1. Ace3 libraries — LibStub, CallbackHandler-1.0, AceAddon-3.0, AceDB-3.0, AceConsole-3.0, AceGUI-3.0. (`AceConfig-3.0` was removed from `libs/` — no live consumer; re-vendor it if a future feature needs it.)
2. `core/Compat.lua` — populates `ns.Compat` (metadata shim). Side-effect-free; loads first among addon files so any later file can call it.
3. `core/Constants.lua` — populates `ns.Const` + `ns.PREFIX` with panel layout constants, the `Color` palette (incl. the slash-output `azure` / `listHead` codes and `FONT_MONO`), and the cyan tag. Side-effect-free.
4. `core/Namespace.lua` — populates `ns.name` / `ns.version` from the TOC (reads `ns.Compat`, so it loads after it).
5. `core/State.lua` — populates `ns.State` (`{ debug = false }`, session-only).
6. `core/Util.lua` — populates `ns.Util` (`trim` / `note` / `cmd`; reads `ns.Const.Color`, so it loads after Constants).
7. `core/Database.lua` — populates `ns.Database` (`SCHEMA_VERSION`, `global` defaults, `RunMigrations`).
8. `core/DebugLog.lua` — populates `ns.DebugLog` (the on-screen console) + `ns.Debug` (gated sink). Reads `ns.State` / `ns.Util` / `ns.Const.FONT_MONO`.
9. `core/PrettyChat.lua` — creates the AceAddon object, defines `ns.Print`, merges `ns.Database.defaults` + runs migrations in `OnInitialize`, registers slash commands, owns `OpenConfig`. **Every later file assumes the addon object exists** (`LibStub("AceAddon-3.0"):GetAddon("PrettyChat")`).
10. `defaults/Defaults.lua` — populates `ns.Defaults`.
11. `locales/enUS.lua` — populates `ns.L` (English-key metatable + enUS manifest).
12. `GlobalStrings/GlobalStrings_001.lua` … `_010.lua` — populates `ns.GlobalStrings` eagerly so the panel can resolve "Original" values without an explicit load step.
13. `modules/Override.lua` — attaches the override engine to the addon object (`ApplyStrings`, enable-cascade predicates, `ResetCategory` / `ResetAll`, `Test`) and defines `ns.RenderSample`.
14. `settings/Schema.lua` — builds `rows` / `byPath` from `ns.Defaults` (which is loaded earlier) and runs the load-time path validator. Closures bind to live values.
15. `settings/Slash.lua` — defines the `/pc` dispatcher (`ns.COMMANDS`, `OnSlashCommand`, and the per-verb handlers). Loads after Schema so its `list` / `get` / `set` handlers can reach `ns.Schema`.
16. `settings/Panel.lua` — exposes `ns.Config.RegisterPanels`. Called from `PrettyChat:OnEnable`, it registers the parent canvas-layout category + one sub-page per category. Defers AceGUI body rendering until each panel's first `OnShow`; that `OnShow` calls `ns.Schema.RegisterRefresher(category, refreshFn)` so `Schema.NotifyPanelChange` can re-sync the page after a write.

If you add a new file, put it in the right place in `PrettyChat.toc`.
