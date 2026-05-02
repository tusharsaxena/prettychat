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
                       ├──▶ Config.lua "Original Format String" disabled input
                       └──▶ ns.GlobalStringSearch  (FindByKey/Value/etc — unused at runtime today)
```

## Namespace publishing pattern

Every file captures the addon namespace with the same idiom at the top:

```lua
local addonName, ns = ...
```

Public surfaces are exposed on `ns`:

| Member | Set by | Used by |
|--------|--------|---------|
| `ns.Print(msg)` | `PrettyChat.lua` | every file (`GlobalStringSearch.lua`, `Schema.lua` indirectly via `PrettyChat.*`, slash command bodies) |
| `ns.Schema` | `Schema.lua` | `PrettyChat.lua` (slash dispatch), `Config.lua` (every widget get/set; also overrides `Schema.NotifyPanelChange` with a refresher dispatch) |
| `ns.Const` | `Constants.lua` | `Config.lua` (panel padding / header height / spacers) |
| `ns.RenderSample` | `PrettyChat.lua` | `Config.lua` (per-string sample row) |
| `ns.GlobalStringSearch` | `GlobalStringSearch.lua` | nobody at runtime today; kept for future debug tooling |

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
PrettyChat:Test()                      -- prints one synthesized sample line per format string (ignores enable toggles)

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
ns.Schema.AllRows()                            -- ordered row list (full)
ns.Schema.RowsByCategory(category)             -- filtered subset
ns.Schema.FindByPath(path)                     -- O(1) lookup by dot path
ns.Schema.Get(path)                            -- read through the row's get() closure
ns.Schema.Set(path, value)                     -- write through the row's set() closure → ApplyStrings → NotifyPanelChange
ns.Schema.ResolveCategory(name)                -- case-insensitive "loot" → "Loot"
ns.Schema.NotifyPanelChange(category?)         -- dispatches to PrettyChat.subRefreshers[category] (rebound by Config.lua); nil → all
                                               -- "General" cascades to all sub-pages (per-string disabled state depends on master)
ns.Schema.CATEGORY_ORDER                       -- canonical display order (also drives /pc list, panel left-rail)
```

### `ns.Print` (`PrettyChat.lua`)

```lua
ns.Print(msg)   -- DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PC]|r " .. msg)
```

The single chokepoint for addon chat output. Use this, not raw `print()` or `self:Print()`, so the prefix and color stay uniform across files.

`Test()` is an intentional exception — sample lines are emitted via `DEFAULT_CHAT_FRAME:AddMessage` *without* the `[PC]` prefix so each rendered preview looks like a real chat message. Header/footer carry the prefix.

### `ns.GlobalStringSearch` (`GlobalStringSearch.lua`)

```lua
ns.GlobalStringSearch:EnsureLoaded()                 -- C_AddOns.LoadAddOn("GlobalStrings") (idempotent in practice — see global-strings.md)
ns.GlobalStringSearch:FindByKey(pattern, limit?)     -- substring match against keys, case-insensitive
ns.GlobalStringSearch:FindByValue(pattern, limit?)   -- substring match against values
ns.GlobalStringSearch:Find(pattern, limit?)          -- both
```

Returns sorted `{ {key, value}, ... }` arrays. `limit` defaults to 50. **Not consumed by any slash command or panel widget today** — kept for future debug tooling. `Config.lua` reads `_G.PrettyChatGlobalStrings` directly rather than going through this API.

## Load order

`PrettyChat.toc` is the source of truth. Order is dependency, not alphabetical:

1. Ace3 libraries — LibStub, CallbackHandler-1.0, AceAddon-3.0, AceDB-3.0, AceConsole-3.0, AceGUI-3.0, AceConfig-3.0.
2. `GlobalStrings/GlobalStrings_001.lua` … `_010.lua` — populates `PrettyChatGlobalStrings` eagerly so the panel can resolve "Original" values without an explicit load step.
3. `Constants.lua` — populates `ns.Const` with panel layout constants. Side-effect-free.
4. `Defaults.lua` — populates `PrettyChatDefaults`.
5. `PrettyChat.lua` — creates the AceAddon object, defines `ns.Print` + `ns.RenderSample`, registers slash commands. **Every later file assumes the addon object exists** (`LibStub("AceAddon-3.0"):GetAddon("PrettyChat")`).
6. `Schema.lua` — builds `rows` / `byPath` from `PrettyChatDefaults` (which is loaded earlier). Closures bind to live values.
7. `Config.lua` — registers the parent canvas-layout category + one sub-page per category. Defers AceGUI body rendering until each panel's first `OnShow`. Overrides `ns.Schema.NotifyPanelChange`.
8. `GlobalStringSearch.lua` — last; depends on nothing in particular.

If you add a new file, put it in the right place in `PrettyChat.toc`.
