# Override pipeline

How Blizzard's chat lines become PrettyChat's reformatted output. The engine lives in `modules/Override.lua` (`ApplyStrings`, the enable predicates, `ResetCategory` / `ResetAll`); the pristine-values snapshot is taken in `core/PrettyChat.lua`'s `OnEnable`. It runs at `OnEnable` plus on every settings change.

## Three steps

```
OnEnable                                            ApplyStrings (every settings change)
   │                                                       │
   ▼                                                       ▼
snapshot Blizzard originals                          for each (category, globalName):
   self.originalStrings[NAME] = _G[NAME]               if addon-enabled
   for every (category, globalName) in                    AND category-enabled
   ns.Defaults                                     AND string-enabled:
                                                              _G[NAME] = user override OR PrettyChat default
                                                          else:
                                                              _G[NAME] = self.originalStrings[NAME]
                                                       │
                                                       ▼
                                          WoW chat code reads _G[NAME]
                                          on every line via string.format
                                          (no addon hooks, no per-message rewriting)
```

## Why GlobalString overrides instead of chat events

Blizzard's chat code resolves the format string via `_G[GLOBALNAME]` lazily on every chat line. Overwriting `_G[GLOBALNAME]` once means *every* downstream consumer — the default chat frame, ElvUI, Glass, any other UI replacement — receives the formatted output for free. PrettyChat hooks no chat events and rewrites no messages.

This also means the addon adds zero per-message overhead: the cost is one global write per format-string-per-toggle-change, not one per chat line.

## Snapshot — `OnEnable`

Runs once at addon load, after Blizzard's `GlobalStrings.lua` has populated `_G`:

```lua
function PrettyChat:OnEnable()
    self.originalStrings = {}
    for cat, catData in pairs(ns.Defaults) do
        for globalName in pairs(catData.strings) do
            self.originalStrings[globalName] = _G[globalName]
        end
    end
    self:ApplyStrings()
end
```

This is the *only* chance to capture Blizzard's pristine values for the runtime "restore" path. Any later code that overrides `_G[GLOBALNAME]` (other addons, runtime patches) will be invisible to the snapshot.

The snapshot only covers strings that exist in `ns.Defaults`. Adding a new `globalName` to `defaults/Defaults.lua` requires a `/reload` for the snapshot to pick it up — there's no incremental snapshot path.

## Apply — `ApplyStrings()`

```lua
function PrettyChat:ApplyStrings()
    local addonEnabled = self:IsAddonEnabled()
    -- Deterministic iteration (PC-16): fixed CATEGORY_ORDER, sorted names within each
    -- category, so a global registered under two categories resolves the same way every
    -- reload. (Elided here: applied/restored counters; ApplyStrings returns them.)
    for _, category in ipairs(ns.Schema.CATEGORY_ORDER) do
        local catData = ns.Defaults[category]
        if catData and catData.strings then
            local names = {}
            for globalName in pairs(catData.strings) do names[#names + 1] = globalName end
            table.sort(names)
            for _, globalName in ipairs(names) do
                if addonEnabled
                   and self:IsCategoryEnabled(category)
                   and self:IsStringEnabled(category, globalName) then
                    _G[globalName] = self:GetStringValue(category, globalName)
                elseif self.originalStrings and self.originalStrings[globalName] then
                    _G[globalName] = self.originalStrings[globalName]
                end
            end
        end
    end
end
```

Runs from:

- `OnEnable` — initial pass after the snapshot.
- `Schema.Set` (every settings mutation) — `Schema.Set` calls `ApplyStrings` directly after the row's `set()` writes the DB. Row `set()` closures themselves are pure DB writes; they do not trigger `ApplyStrings` so a future `Schema.SetMany` / preset-load can apply once per batch.
- `PrettyChat:ResetCategory(cat)` and `PrettyChat:ResetAll()` — both bypass `Schema.Set` (they zero out whole sub-tables, not write through a single row), so they call `ApplyStrings` and `Schema.NotifyPanelChange` themselves.

`ApplyStrings` returns `(applied, restored)` counts rather than logging them itself, so each pass is summarised in **one** caller line (debug-logging-§8/§9): `[Boot]` at enable, `[Reset] <cat|all> → applied N restored M` on a reset. A settings change logs only `[Set] <path> = <value>` at the write seam (§10) — the re-apply is implied and not re-echoed. (Loot lines themselves never log: the addon hooks no events; it only swaps `_G[GLOBALNAME]`.)

Idempotent — calling it multiple times leaves `_G` in the same state.

## The three enable layers

Resolved on every `ApplyStrings` pass, in this order:

1. **`General.enabled`** (addon-wide master). Stored at `db.profile.enabled` (not under `categories`). When false, **every** Blizzard original is restored regardless of per-category and per-string state — the master switch wins outright. Customizations stay in the database, just unapplied.
2. **`<Category>.enabled`** (per-category). Stored at `db.profile.categories[Cat].enabled`. Falls back to the per-category default in `ns.Defaults[Cat].enabled` (always `true` today).
3. **`<Category>.<GLOBALNAME>.enabled`** (per-string). Stored at `db.profile.categories[Cat].disabledStrings[NAME]`. Inverted: `disabledStrings[NAME] = true` means **disabled**; absent / nil means enabled.

A string only renders with the user's format if all three are on. For any string that resolves to "disabled" at any layer, `ApplyStrings` writes the captured original back to `_G[GLOBALNAME]` — so a panel-flip from "on" to "off" immediately restores Blizzard's behavior for that string.

## Format-value resolution

Inside `ApplyStrings`, the value written to `_G[GLOBALNAME]` for an enabled string is `self:GetStringValue(category, globalName)`:

```lua
function PrettyChat:GetStringValue(category, globalName)
    local catDB = self.db.profile.categories[category]
    if catDB and catDB.strings and catDB.strings[globalName] ~= nil then
        return catDB.strings[globalName]                   -- user override
    end
    return ns.Defaults[category].strings[globalName].default   -- PrettyChat default
end
```

Note this is the **PrettyChat default**, not the **Blizzard original**. The Blizzard original is only ever written by the disable branches above. The schema's auto-clear-on-default means `catDB.strings[globalName]` only ever holds genuinely-different overrides — see [schema.md](./schema.md#single-write-path).

## What this pipeline does NOT do

- **No event subscriptions.** `OnEnable` snapshots and applies once; `ApplyStrings` re-runs only when settings change. The pipeline is not driven by `CHAT_MSG_*` or any other event.
- **No per-message inspection.** The addon never sees individual chat lines — they go straight from WoW's chat frame through `string.format(_G[NAME], ...)` to the screen.
- **No combat guards.** `ApplyStrings` is unprotected; `_G` writes don't taint. The only combat-aware path is `/pc config`, which refuses to open the panel during combat because Blizzard's category-switch is protected.

## Known quirk: globals shared across categories

`LOOT_ITEM_CREATED_SELF` and `LOOT_ITEM_CREATED_SELF_MULTIPLE` are registered under **both** `Loot` and `Tradeskill` in `ns.Defaults` (`defaults/Defaults.lua:39` and `defaults/Defaults.lua:329`). The schema builds two rows for each — `Loot.LOOT_ITEM_CREATED_SELF.format` and `Tradeskill.LOOT_ITEM_CREATED_SELF.format` — both addressing the same `_G[LOOT_ITEM_CREATED_SELF]`. `ApplyStrings` writes both, so **the category that iterates last wins**. Because `ApplyStrings` walks `ns.Schema.CATEGORY_ORDER` in fixed order (and a sorted name list within each category), that winner is **deterministic** (PC-16): `Tradeskill` comes after `Loot` in `CATEGORY_ORDER`, so the Tradeskill row wins on every `/reload` — not a coin-flip. `Schema.crossRegisteredGlobals` records the conflict and the per-string enable-checkbox tooltip surfaces it in-page.

In practice this means: editing the format on the **Loot** sub-page for one of these two globals is silently overwritten by the **Tradeskill** value on the next `ApplyStrings`. The two defaults *do* differ — Loot uses the red `Loot` label; Tradeskill uses the magenta `Tradeskill` label — so the visible result is the Tradeskill one, stably across reloads. It's still a footgun (edit the Tradeskill page, not the Loot page, for these two), which is why the tooltip warns about it.

Don't try to "fix" this without a concrete user complaint. The duplicate registration is intentional (both contexts can produce the same Blizzard event), and any deduplication strategy has to pick one category to win, which is itself a policy decision.
