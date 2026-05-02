# Schema and storage

`Schema.lua` is the single source of truth for what's settable. At file-load (after `Defaults.lua` and `PrettyChat.lua`) it iterates `PrettyChatDefaults` and builds a flat array of rows, one per settable value, exposed at `ns.Schema`.

This doc covers: the four row kinds, the single write path that every settings mutation goes through, and the AceDB shape behind it.

## Row kinds

Four row kinds, addressed by dot path:

| Path | Kind | Type | Backed by |
|------|------|------|-----------|
| `General.enabled` | `addon_enabled` | bool | `db.profile.enabled` (addon-wide master toggle; `General` is a *virtual category* — no entry in `PrettyChatDefaults`) |
| `<Category>.enabled` | `category_enabled` | bool | `db.profile.categories[Cat].enabled` (via `IsCategoryEnabled` / `EnsureCategoryDB`) |
| `<Category>.<GLOBALNAME>.enabled` | `string_enabled` | bool | `db.profile.categories[Cat].disabledStrings[NAME]` (**inverted**: `disabledStrings[NAME] = true` means *disabled*) |
| `<Category>.<GLOBALNAME>.format` | `string_format` | string | `db.profile.categories[Cat].strings[NAME]` (with `PrettyChatDefaults[Cat].strings[NAME].default` fallback) |

Each row carries its own `get()` and `set(value)` closures. PrettyChat's storage layout doesn't map 1:1 onto the path structure — the inverted `disabledStrings` table, the virtual `General` category, the default-fallback for formats — so a generic dot-walker (KickCD's `Helpers.Resolve` style) doesn't fit. Closures are simpler than a special-case resolver.

## Single write path

`Schema.Set(path, value)` is the **only** function that mutates settings:

```lua
function Schema.Set(path, value)
    local row = byPath[path]
    if not row then return false end
    row.set(value)                              -- writes DB + runs PrettyChat:ApplyStrings()
    Schema.NotifyPanelChange(row.category)      -- dispatches to the affected sub-page's refresher (Config.lua)
    return true
end
```

Both surfaces go through the same row's `set()`:

- **Panel widget callbacks** in `Config.lua` call `ns.Schema.Set(path, val)`.
- **`/pc set`** (in `PrettyChat.lua`'s `setSetting`) parses the value to the row's declared type, then calls `ns.Schema.Set(path, newVal)`.

After writing, `Set` runs `PrettyChat:ApplyStrings()` (so the live `_G` overrides reconcile — see [override-pipeline.md](./override-pipeline.md)) and calls `Schema.NotifyPanelChange(row.category)`. `Config.lua` rebinds `NotifyPanelChange` to dispatch to the affected sub-page's refresher closure (`PrettyChat.subRefreshers[category]`), which re-syncs every visible widget on that page from the DB. Master-toggle changes (category `"General"`) cascade to every sub-page since per-string disabled state depends on the master. This keeps the panel and the slash UI from ever drifting — a `/pc set` while the panel is open updates both surfaces in the same frame.

### Auto-clear on default

For `string_format` rows specifically, the row's `set` closure stores `nil` (clears the override entry) when `value` matches the row's PrettyChat default:

```lua
if v == PrettyChatDefaults[category].strings[globalName].default then
    catDB.strings[globalName] = nil
else
    catDB.strings[globalName] = v
end
```

So writing a format back to its default value via `/pc set` or the panel acts as a per-string reset — the override entry is removed from `db.profile.categories[Cat].strings`, and `GetStringValue` falls back to the default on next read. The `strings` table never collects "override that happens to equal the default".

## Public API

| Function | Purpose |
|----------|---------|
| `Schema.AllRows()` | Full ordered row list. Defined but currently uncalled — `/pc list` no-arg iterates `CATEGORY_ORDER` and calls `RowsByCategory` per category instead. Kept as a public surface for future scripted access. |
| `Schema.RowsByCategory(category)` | Filtered subset. Used by `/pc list <Category>` and Config.lua's per-page builder. |
| `Schema.FindByPath(path)` | O(1) lookup; returns the row or `nil`. |
| `Schema.Get(path)` / `Schema.Set(path, value)` | Read/write through the row's closures. `Set` returns `false` if the path is unknown. |
| `Schema.ResolveCategory(name)` | Case-insensitive PascalCase resolver — `/pc reset loot` finds `Loot`. Returns `nil` for unknowns. |
| `Schema.NotifyPanelChange(category?)` | Dispatches to `PrettyChat.subRefreshers[category]` (rebound by `Config.lua`). Pass `nil` to refresh every sub-page. Master-toggle changes (`"General"`) also cascade to every sub-page. Safe to call before `Config.lua` has installed the override — the original Schema.lua implementation no-ops gracefully. |
| `Schema.CATEGORY_ORDER` | Display order array. Imported by `Config.lua` (left-rail order), `PrettyChat.lua`'s `Test()` and `/pc list` (iteration order). The single source of truth — iterating `pairs(PrettyChatDefaults)` would give a non-deterministic order. |

## Reset semantics

Two reset paths, both routed through `PrettyChat:Reset*` not directly through Schema:

- **`PrettyChat:ResetCategory(category)`** clears one category's overrides. Special case: `category == "General"` clears `db.profile.enabled` back to `nil` (default true). After clearing, calls `ApplyStrings` and `Schema.NotifyPanelChange(category)`.
- **`PrettyChat:ResetAll()`** clears `db.profile.enabled` *and* every entry in `db.profile.categories`. Calls `ApplyStrings` and `Schema.NotifyPanelChange(nil)` (every category).

Both are reachable from:

- The panel's per-category `Defaults` button (in the page header — no popup confirm) and the General sub-page's "Reset all to defaults" button (gated by the `PRETTYCHAT_RESET_ALL` StaticPopup).
- `/pc reset <Category>` and `/pc resetall` (no in-chat confirmation — typing the command is itself the assertion).

## SavedVariables shape

```
PrettyChatDB.profile.enabled                                         -- bool (addon-wide master toggle; nil = default true)
PrettyChatDB.profile.categories[catName].enabled                     -- bool (nil = default true, sourced from PrettyChatDefaults[Cat].enabled)
PrettyChatDB.profile.categories[catName].strings[globalName]         -- string override (nil = use PrettyChat default)
PrettyChatDB.profile.categories[catName].disabledStrings[globalName] -- true = disabled (absent / nil = enabled)
```

Only user-modified values are stored. The schema's auto-clear keeps `strings[...]` lean — it never collects "override that happens to equal the default".

`db.profile.categories[catName]` is created lazily by `EnsureCategoryDB` on first write. `disabledStrings` and `strings` sub-tables are created lazily inside the row's `set()` closures.

### Profiles

Profiles use AceDB with a single shared `Default` profile:

```lua
self.db = LibStub("AceDB-3.0"):New("PrettyChatDB", defaults, true)
```

The third arg (`true`) selects the `Default` profile name for every character. All characters on the account see the same configuration out of the box.

`AceDBOptions-3.0` (per-character / per-class / per-realm profile UI) is **not** wired in. Adding it is a small contribution: register the AceDBOptions table as another `PrettyChat_Profiles` sub-page in `Config.lua`. See [scope.md](./scope.md#out-of-scope) for why it isn't there today.

## Build sequence

Schema construction runs once at file-load (`Schema.lua`). The order matters:

1. `buildAddonEnabledRow()` — adds the single `General.enabled` row.
2. For each `category` in `CATEGORY_ORDER` (skipping `General`):
   - `buildCategoryRow(category)` — adds `<Cat>.enabled`.
   - For each `globalName` in `PrettyChatDefaults[Cat].strings` (sorted alphabetically): `buildStringRows(...)` — adds `<Cat>.<NAME>.enabled` *and* `<Cat>.<NAME>.format`.

Closures bind to live values: `PrettyChatDefaults` is populated by `Defaults.lua` (loaded earlier by the TOC) and the addon object exists (`PrettyChat.lua`'s `:NewAddon` ran before `Schema.lua`).
