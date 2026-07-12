# Module map

Per-module roles + public APIs. Pair this with [override-pipeline.md](./override-pipeline.md) for how the modules talk to each other at runtime.

## Subsystem diagram

```
Defaults.lua  ──▶ ns.Defaults (categories + format strings)
                    │
                    ├──▶ Schema.lua ──▶ ns.Schema   (rows[], byPath[], single write path)
                    │                       │
                    │                       ├──▶ /pc set / get / list / reset    (PrettyChat.lua)
                    │                       └──▶ Panel widget get/set            (Config.lua)
                    │
                    └──▶ PrettyChat.lua ApplyStrings()
                                │
                                ▼
                          _G[GLOBALNAME]   ◀── WoW chat code reads lazily on every line

GlobalStrings/  ──▶ ns.GlobalStrings (Blizzard reference, ~22,879 entries)
                       │
                       └──▶ Config.lua "Original Format String" disabled input
```

## Namespace publishing pattern

Every file captures the addon namespace with the same idiom at the top:

```lua
local addonName, ns = ...
```

Public surfaces are exposed on `ns`:

| Member | Set by | Used by |
|--------|--------|---------|
| `ns.Compat` | `Compat.lua` | `PrettyChat.lua`, `Config.lua` (`Compat.GetAddOnMetadata` — C_AddOns vs legacy global) |
| `ns.L` | `Locale.lua` | `Config.lua`, `PrettyChat.lua` (English-key localization; `__index` returns the key) |
| `ns.Const` / `ns.PREFIX` | `Constants.lua` | `Config.lua` (padding / header height / spacers / `Color` palette / `BUTTON_PAIR_REL`); `PrettyChat.lua` (`Color` palette; `ns.PREFIX` = shared cyan `[PC]` tag read by `ns.Print`) |
| `ns.Defaults` | `Defaults.lua` | `Schema.lua`, `PrettyChat.lua`, `Config.lua` (category → format-string defaults) |
| `ns.Database` | `Database.lua` | `PrettyChat.lua` (`OnInitialize` merges `global.schemaVersion` defaults + runs `RunMigrations`) |
| `ns.GlobalStrings` | `GlobalStrings/` chunks | `Config.lua` ("Original Format String" display) |
| `ns.Print(msg)` / `ns.Debug(tag, fmt, …)` / `ns.State` | `PrettyChat.lua` | every file (chat output chokepoint; `ns.Debug` gated on session-only `ns.State.debug`, toggled by `/pc debug`) |
| `ns.Schema` | `Schema.lua` | `PrettyChat.lua` (slash dispatch), `Config.lua` (every widget get/set; registers a per-sub-page refresh closure via `Schema.RegisterRefresher` on first `OnShow`) |
| `ns.RenderSample(fmt)` | `PrettyChat.lua` | `Config.lua` (per-string Preview EditBox) |
| `ns.COMMANDS` | `PrettyChat.lua` | `Config.lua` (parent page's slash-command list — keeps panel and `/pc help` in lockstep with one source) |
| `ns.Config.RegisterPanels()` | `Config.lua` | `PrettyChat.lua` (`OnEnable` calls it after the snapshot/`ApplyStrings` pair, replacing the old `PLAYER_LOGIN` bootstrap frame) |

The addon object itself (`PrettyChat`, an `AceAddon-3.0` object) is **not** published on `ns`. Other files reach it via `LibStub("AceAddon-3.0"):GetAddon("PrettyChat")`.

## Public APIs

### `PrettyChat` (the AceAddon object — `PrettyChat.lua`)

```lua
-- Lifecycle
PrettyChat:OnInitialize()              -- AceDB, slash registration ("/pc" + "/prettychat")
PrettyChat:OnEnable()                  -- snapshot Blizzard originals → ApplyStrings
PrettyChat:OpenConfig()                -- Settings.OpenToCategory(self.optionsCategoryID); then expandMainCategory(self.optionsCategory) walks SettingsPanel:GetCategoryList():GetCategoryEntry(cat):SetExpanded(true) in pcall to unfold the sub-tree

-- Override pipeline (also see override-pipeline.md)
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

-- Slash dispatch
PrettyChat:OnSlashCommand(input)       -- parses verb + rest, dispatches via the COMMANDS table
```

### `ns.Schema` (`Schema.lua`)

See [schema.md](./schema.md) for the row kinds, the single write path, and the auto-clear-on-default behavior.

```lua
ns.Schema.RowsByCategory(category)             -- filtered subset for one category
ns.Schema.FindByPath(path)                     -- O(1) lookup by dot path
ns.Schema.Get(path)                            -- read through the row's get() closure
ns.Schema.Set(path, value)                     -- DB write (row's set closure) → ApplyStrings → NotifyPanelChange
ns.Schema.ResolveCategory(name)                -- case-insensitive "loot" → "Loot"; falls back to unambiguous prefix
ns.Schema.NotifyPanelChange(category?)         -- invokes the closure registered for `category`; nil or "General" runs every closure
                                               -- (per-string disabled state depends on master, so master changes cascade)
ns.Schema.RegisterRefresher(category, fn)      -- Config.lua registers a per-sub-page refresh closure on first OnShow
ns.Schema.crossRegisteredGlobals               -- map of globalName → {Cat1, Cat2, …} for globals registered under >1 category
ns.Schema.CATEGORY_ORDER                       -- canonical display order (also drives /pc list, panel left-rail)
```

### `ns.Print` (`PrettyChat.lua`)

```lua
ns.Print(msg)   -- DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)   where PREFIX is built from ns.Const.Color.cyan
```

The single chokepoint for addon chat output. Use this, not raw `print()` or `self:Print()`, so the prefix and color stay uniform across files.

`Test()` is an intentional exception — sample lines are emitted via `DEFAULT_CHAT_FRAME:AddMessage` *without* the `[PC]` prefix so each rendered preview looks like a real chat message. Header/footer carry the prefix.

## Load order

`PrettyChat.toc` is the source of truth. Order is dependency, not alphabetical:

1. Ace3 libraries — LibStub, CallbackHandler-1.0, AceAddon-3.0, AceDB-3.0, AceConsole-3.0, AceGUI-3.0. (`AceConfig-3.0` was removed from `libs/` — no live consumer; re-vendor it if a future feature needs it.)
2. `Compat.lua` — populates `ns.Compat` (metadata shim). Side-effect-free; loads first among addon files so any later file can call it.
3. `Locale.lua` — populates `ns.L` (English-key metatable + enUS manifest).
4. `Constants.lua` — populates `ns.Const` + `ns.PREFIX` with panel layout constants and the cyan tag. Side-effect-free.
5. `Defaults.lua` — populates `ns.Defaults`.
6. `Database.lua` — populates `ns.Database` (`SCHEMA_VERSION`, `global` defaults, `RunMigrations`).
7. `GlobalStrings/GlobalStrings_001.lua` … `_010.lua` — populates `ns.GlobalStrings` eagerly so the panel can resolve "Original" values without an explicit load step.
8. `PrettyChat.lua` — creates the AceAddon object, defines `ns.Print` / `ns.Debug` / `ns.RenderSample`, merges `ns.Database.defaults` + runs migrations in `OnInitialize`, registers slash commands. **Every later file assumes the addon object exists** (`LibStub("AceAddon-3.0"):GetAddon("PrettyChat")`).
9. `Schema.lua` — builds `rows` / `byPath` from `ns.Defaults` (which is loaded earlier) and runs the load-time path validator. Closures bind to live values.
10. `Config.lua` — exposes `ns.Config.RegisterPanels`. Called from `PrettyChat:OnEnable`, it registers the parent canvas-layout category + one sub-page per category. Defers AceGUI body rendering until each panel's first `OnShow`; that `OnShow` calls `ns.Schema.RegisterRefresher(category, refreshFn)` so `Schema.NotifyPanelChange` can re-sync the page after a write.

If you add a new file, put it in the right place in `PrettyChat.toc`.
