# Module map

Per-module roles + public APIs. Pair this with [override-pipeline.md](./override-pipeline.md) for how the modules talk to each other at runtime.

## Subsystem diagram

```
Defaults.lua  ──▶ PrettyChatDefaults (categories + format strings)
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

GlobalStrings/  ──▶ PrettyChatGlobalStrings (Blizzard reference, ~22,879 entries)
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
| `ns.Print(msg)` | `PrettyChat.lua` | every file (`Schema.lua` indirectly via `PrettyChat.*`, slash command bodies) |
| `ns.Schema` | `Schema.lua` | `PrettyChat.lua` (slash dispatch), `Config.lua` (every widget get/set; registers a per-sub-page refresh closure via `Schema.RegisterRefresher` on first `OnShow`) |
| `ns.Const` | `Constants.lua` | `Config.lua` (panel padding / header height / spacers / `Color` palette); `PrettyChat.lua` (`Color` palette: `cyan` for `[PC]` prefix, `yellow`/`white` for `cmd`/`note` helpers, `gold`+`green` for the `/pc test` Category header and Name/Original/Formatted labels, `grey` for inline error text) |
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
PrettyChat:GetStringValue(category, globalName)   -- user override falling back to PrettyChatDefaults
PrettyChat:IsAddonEnabled()                       -- nil → default true
PrettyChat:IsCategoryEnabled(category)            -- nil → default true (from PrettyChatDefaults)
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

1. Ace3 libraries — LibStub, CallbackHandler-1.0, AceAddon-3.0, AceDB-3.0, AceConsole-3.0, AceGUI-3.0. (`Libs/AceConfig-3.0/` is vendored on disk but no longer loaded by the TOC — re-add the load line if a future feature needs it.)
2. `GlobalStrings/GlobalStrings_001.lua` … `_010.lua` — populates `PrettyChatGlobalStrings` eagerly so the panel can resolve "Original" values without an explicit load step.
3. `Constants.lua` — populates `ns.Const` with panel layout constants. Side-effect-free.
4. `Defaults.lua` — populates `PrettyChatDefaults`.
5. `PrettyChat.lua` — creates the AceAddon object, defines `ns.Print` + `ns.RenderSample`, registers slash commands. **Every later file assumes the addon object exists** (`LibStub("AceAddon-3.0"):GetAddon("PrettyChat")`).
6. `Schema.lua` — builds `rows` / `byPath` from `PrettyChatDefaults` (which is loaded earlier). Closures bind to live values.
7. `Config.lua` — exposes `ns.Config.RegisterPanels`. Called from `PrettyChat:OnEnable`, it registers the parent canvas-layout category + one sub-page per category. Defers AceGUI body rendering until each panel's first `OnShow`; that `OnShow` calls `ns.Schema.RegisterRefresher(category, refreshFn)` so `Schema.NotifyPanelChange` can re-sync the page after a write.

If you add a new file, put it in the right place in `PrettyChat.toc`.
