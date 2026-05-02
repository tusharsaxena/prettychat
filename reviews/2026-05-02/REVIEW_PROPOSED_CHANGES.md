# Proposed changes — Ka0s Pretty Chat

Companion to `REVIEW_FINDINGS.md`. Each LLD section links back to the finding IDs it implements.

## HLD — themes

### Theme 1 — Collapse the "two `NotifyPanelChange` implementations" into one (covers F-001, F-012, F-020)

`Schema.lua` ships an AceConfigRegistry-based `NotifyPanelChange`. `Config.lua` *replaces* it at file load with a refresher dispatch. The Schema.lua body is dead and the comment misleads. The AceConfigRegistry call itself has no consumer (no `RegisterOptionsTable("PrettyChat_<Cat>", …)` anywhere — Theme 4).

**Decision:** delete the Schema.lua body. Move the refresher dispatch into Schema.lua as the canonical implementation, with `PrettyChat.subRefreshers` (or a new schema-owned table) as the registration target. Config.lua then *registers* refreshers rather than *replaces* the function.

**Alternatives considered:**

- Keep the replace-at-load pattern but rewrite the comment. Rejected — the indirection adds zero value; either Schema is the contract or Config is.
- Extract the dispatch table into a new `Notify.lua` module. Rejected — over-engineering for a 7-line function.

**Trade-off:** Schema gains a small dependency on the dispatch concept (knowing about per-category refreshers), which slightly weakens its "pure schema, no UI" character. Net win because the alternative is a comment that lies.

### Theme 2 — Fold the `Config.lua` PLAYER_LOGIN bootstrap into the AceAddon lifecycle (covers F-002)

`Config.lua` runs its own `CreateFrame + RegisterEvent("PLAYER_LOGIN")` to call `registerPanels()`. The addon already has `OnInitialize` and `OnEnable`. `Settings.RegisterAddOnCategory` is allowed in `OnEnable` (which fires after `PLAYER_LOGIN` for non-LoD addons in modern WoW), and the AceGUI deferred-render-on-`OnShow` pattern handles the size-zero-frame issue independently.

**Decision:** expose a `Config.RegisterPanels()` from `Config.lua` (or `ns.Config = { RegisterPanels = … }`) and call it from `PrettyChat:OnEnable` after the snapshot/`ApplyStrings` pair. Drop the bootstrap frame. The existing combat-guard convention for `Settings.*` registrations is already satisfied because `OnEnable` is not entered during combat.

**Alternative:** keep the bootstrap but document why. Rejected — there is no reason; it's historical.

### Theme 3 — Centralize "post-write side effects" in `Schema.Set` (covers F-013, partially F-014)

Today every row's `set` closure individually calls `PrettyChat:ApplyStrings()`. `Schema.Set` then calls `Schema.NotifyPanelChange(row.category)`. Splitting "DB write" from "side effects" lets a future `Schema.SetMany(pairs)` run `ApplyStrings` exactly once.

**Decision:** row `set` closures *only* mutate the DB. `Schema.Set` runs `PrettyChat:ApplyStrings()` then `Schema.NotifyPanelChange(row.category)` after the row's set returns successfully.

**Alternative:** add a "batch mode" flag to `Schema.Set`. Rejected — the simpler refactor is to just centralize.

### Theme 4 — Drop `AceConfig-3.0` from the TOC (covers F-010, follows from Theme 1)

After Theme 1 removes the `LibStub("AceConfigRegistry-3.0", true)` call, the only remaining reference is the TOC load. `AceConfig-3.0` brings its own dependency tree (AceGUI-3.0 — already loaded for our panel — plus the registry/dialog modules). With no live consumer, the load is overhead.

**Decision:** drop the TOC line. Re-add it with the future feature that needs it. `ARCHITECTURE.md` updated to remove the "kept for future re-wiring" disclaimer.

**Alternative:** keep it, document why more clearly. Rejected — "future maybe" is not a load-time justification.

### Theme 5 — Render-sample parity between `Test()` and the per-row Preview (covers F-003, F-014, F-031)

Two paths render synthesized samples: `ns.RenderSample(fmt)` (used by the per-row Preview) and the inline `pcall(string.format, fmt, unpack(buildSampleArgs(fmt)))` in `Test()`. Both miss positional `%n$` conversions (F-003).

**Decision:** `Test()` calls `ns.RenderSample(fmt)`; on failure, it emits a grey error line so the user sees *which* string is broken. `buildSampleArgs` upgrades to recognize `%n$type` (Lua pattern: `%%(%d+%$)?[%-+ #0]*%d*%.?%d*([%a])`); positional indices are honored when assembling the args array.

**Alternative:** punt on positional args (English-only contract). Rejected — `docs/scope.md:19` already acknowledges localization is a known gap, but breaking the panel preview for non-English users is a regression risk worth pre-empting.

### Theme 6 — Centralize the chat-color palette (covers F-021)

`PrettyChat.lua`'s `cmd()`/`note()` and `Config.lua`'s `GOLD/GREY/RED/RESET` are convergent. A small `ns.Color` table on `ns.Const` (or its own micro-module) gives one source.

**Decision:** add `ns.Const.Color = { gold = "|cffffd700", grey = "|cffaaaaaa", red = "|cffff5050", yellow = "|cffffff00", white = "|cffffffff", reset = "|r" }`. PrettyChat's `cmd`/`note` and Config.lua's local constants reference these.

### Theme 7 — One DB-default convention for `enabled` flags (covers F-015, F-039)

Two patterns coexist: AceDB's defaults-merge writes `enabled = true` into `db.profile`; the read helpers (`IsAddonEnabled`, `IsCategoryEnabled`) treat `nil` as default-true. The `nil`-treatment branches can never fire after `OnInitialize` because the merge already populated the value (for the master toggle), and the per-category sub-tables never get the merge (because `categories = {}` is the default).

**Decision:** drop `enabled = true` from `defaults.profile`. Keep the `nil → true` semantic as the contract (already used everywhere). `ResetCategory("General")` becomes coherent — setting `db.profile.enabled = nil` actually resets to default-true. Document the contract in one place (`docs/schema.md`).

### Theme 8 — Cross-category shared-global awareness (covers F-011)

`LOOT_ITEM_CREATED_SELF` registers under both Loot and Tradeskill. The doc note says "do not fix without a triggering complaint", which is fine — but the user has no in-panel signal.

**Decision:** add a small `crossRegisteredGlobals` set computed at schema-build time. The per-string row tooltip notes "shared with `<other category>`" when the global appears in more than one category. No behavior change — just a signal so the user knows what they're up against.

**Alternative:** collapse to a single registration with a "category" enum. Rejected — `docs/override-pipeline.md:115-116` flags this as "intentional, don't fix without complaint".

---

## LLD — concrete changes

### LLD-1 — Remove `Schema.NotifyPanelChange` body from `Schema.lua`; install dispatch in `Schema.lua` (F-001, F-012, F-020)

**File:** `Schema.lua:148-162`.

**Before:**

```lua
function Schema.NotifyPanelChange(category)
    local registry = LibStub("AceConfigRegistry-3.0", true)
    if not registry then return end
    if category then
        registry:NotifyChange("PrettyChat_" .. category)
    else
        for _, c in ipairs(CATEGORY_ORDER) do
            registry:NotifyChange("PrettyChat_" .. c)
        end
    end
end
```

**After:**

```lua
-- Refresher table populated by Config.lua during sub-page first-`OnShow`.
-- Each entry is a closure that re-syncs the visible widgets on one
-- sub-page from the DB. Master-toggle changes ("General" or nil)
-- cascade to every entry.
Schema.refreshers = {}

function Schema.NotifyPanelChange(category)
    if category == "General" or category == nil then
        for _, fn in pairs(Schema.refreshers) do pcall(fn) end
        return
    end
    local fn = Schema.refreshers[category]
    if fn then pcall(fn) end
end

function Schema.RegisterRefresher(category, fn)
    Schema.refreshers[category] = fn
end
```

**File:** `Config.lua:563`, `Config.lua:600`, `Config.lua:613`, `Config.lua:623-635`.

- Replace `PrettyChat.subRefreshers = {}` with use of `Schema.refreshers` (or `Schema.RegisterRefresher`).
- Replace `PrettyChat.subRefreshers[category] = buildGeneralBody(catCtx)` with `Schema.RegisterRefresher(category, buildGeneralBody(catCtx))`. Same for `buildCategoryBody`.
- Delete the `function ns.Schema.NotifyPanelChange(category)` re-binding at the bottom of `Config.lua`.

**Risk:** any external caller that was reading `PrettyChat.subRefreshers` directly. Repo-wide grep shows none.

### LLD-2 — Move `registerPanels()` from `PLAYER_LOGIN` bootstrap to `OnEnable` (F-002)

**File:** `Config.lua:637-642`.

**Before:**

```lua
local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("PLAYER_LOGIN")
bootstrap:SetScript("OnEvent", function(self)
    registerPanels()
    self:UnregisterAllEvents()
end)
```

**After:**

```lua
ns.Config = ns.Config or {}
ns.Config.RegisterPanels = registerPanels
```

**File:** `PrettyChat.lua:27-35` (`OnEnable`).

**Before:**

```lua
function PrettyChat:OnEnable()
    self.originalStrings = {}
    for cat, catData in pairs(PrettyChatDefaults) do
        for globalName in pairs(catData.strings) do
            self.originalStrings[globalName] = _G[globalName]
        end
    end
    self:ApplyStrings()
end
```

**After:**

```lua
function PrettyChat:OnEnable()
    self.originalStrings = {}
    for cat, catData in pairs(PrettyChatDefaults) do
        for globalName in pairs(catData.strings) do
            self.originalStrings[globalName] = _G[globalName]
        end
    end
    self:ApplyStrings()

    if ns.Config and ns.Config.RegisterPanels then
        ns.Config.RegisterPanels()
    end
end
```

**Risk:** `OnEnable` runs before the first frame draws but after Blizzard's `Settings` API is available; the registration sequence is the same as today's `PLAYER_LOGIN` path. The deferred-`OnShow` AceGUI render is unchanged.

### LLD-3 — Centralize side effects in `Schema.Set` (F-013, F-014)

**File:** `Schema.lua` row builders (lines 40-110).

Strip the `PrettyChat:ApplyStrings()` call from each row's `set` closure. Each `set` becomes pure DB write.

**File:** `Schema.lua:167-173` (`Schema.Set`).

**Before:**

```lua
function Schema.Set(path, value)
    local row = byPath[path]
    if not row then return false end
    row.set(value)
    Schema.NotifyPanelChange(row.category)
    return true
end
```

**After:**

```lua
function Schema.Set(path, value)
    local row = byPath[path]
    if not row then return false end
    row.set(value)
    PrettyChat:ApplyStrings()
    Schema.NotifyPanelChange(row.category)
    return true
end
```

**Risk:** any direct caller of `row.set(value)` that bypasses `Schema.Set` would lose the `ApplyStrings` post-write. Today there are none; the convention is "single write path". Add a one-line comment to row builders noting that callers must go through `Schema.Set`.

### LLD-4 — Drop `AceConfig-3.0` from TOC (F-010)

**File:** `PrettyChat.toc:18`. Delete the line. `Libs/AceConfig-3.0/` stays on disk (it's vendored; we may want it back later) but is no longer loaded.

**File:** `ARCHITECTURE.md:65`. Remove the "kept for future re-wiring" line.

**Risk:** none functional after LLD-1 removes the only consumer.

### LLD-5 — `buildSampleArgs` handles `%n$type` and `Test()` shares `RenderSample` (F-003, F-014, F-031)

**File:** `PrettyChat.lua:149-171`.

`buildSampleArgs(fmt)` updated pattern: `"%%(%d*%$?)[%-+ #0]*%d*%.?%d*([%a])"`. When the first capture is non-empty (`"2$"`), strip the `$`, parse the index, and fill `args[index] = sampleArg(ftype)` rather than appending. After the scan, fill any nil holes with `"?"` so `unpack` works. Compute `#args` as `max(seen_indices, append_count)`.

**File:** `PrettyChat.lua:195-224` (`Test`).

Replace inline `buildSampleArgs` + `pcall(string.format, …)` with `ns.RenderSample(fmt)`. On failure, emit a grey "(format error: …)" line so the user sees the broken row. Footer reports both `printed` and `errored` counts.

**Risk:** the new pattern needs unit-style scrutiny for edge cases (`%%2$s` literal escape, `%5.2f`, etc.). Test in-game against `LOOT_ITEM_SELF` (positional-free) and against a synthetic `%2$s/%1$d` case.

### LLD-6 — `ns.Const.Color` table (F-021)

**File:** `Constants.lua`. Add:

```lua
Const.Color = {
    gold   = "|cffffd700",
    grey   = "|cffaaaaaa",
    red    = "|cffff5050",
    yellow = "|cffffff00",
    white  = "|cffffffff",
    cyan   = "|cff00ffff",  -- the [PC] prefix color
    reset  = "|r",
}
```

**Files:** `PrettyChat.lua:5` (move `PREFIX` to use `Const.Color.cyan`), `PrettyChat.lua:235-236` (`cmd`/`note` use `Const.Color.yellow` / `Const.Color.white`), `Config.lua:13-16` (replace local constants with `ns.Const.Color.*` references).

**Risk:** load order — `Constants.lua` loads before `PrettyChat.lua`. Verified in TOC.

### LLD-7 — Drop `enabled = true` from `defaults.profile`; trust `nil → true` (F-015, F-039)

**File:** `PrettyChat.lua:13-18`.

**Before:**

```lua
local defaults = {
    profile = {
        enabled    = true,
        categories = {},
    },
}
```

**After:**

```lua
local defaults = {
    profile = {
        -- `enabled` (master toggle) and per-category `enabled` flags
        -- are not in the defaults table — IsAddonEnabled / IsCategoryEnabled
        -- treat `nil` as default-true. This keeps SavedVariables empty
        -- until the user changes something.
        categories = {},
    },
}
```

**Risk:** existing users with `enabled = true` already serialized into `PrettyChatDB.lua` are unaffected — the read helper handles both `true` and `nil`. New / wiped profiles will have a leaner SavedVariables.

### LLD-8 — Cross-registered globals tooltip (F-011)

**File:** `Schema.lua` after `buildStringRows` loop.

Compute `Schema.crossRegisteredGlobals = { LOOT_ITEM_CREATED_SELF = {"Loot", "Tradeskill"}, … }` by iterating rows of kind `string_format` and grouping by `globalName`. Expose on `Schema`.

**File:** `Config.lua:355-465` (`buildStringRow`).

When `Schema.crossRegisteredGlobals[globalName]` exists, decorate the `enable` checkbox tooltip with "This global is also registered under <other categories>; the last category to apply wins on `/reload`."

**Risk:** none — pure additive UI text.

### LLD-9 — Misc low-priority fixes

- **F-023 (`formatValue`):** swap `('"%s"'):format(v)` for `('%q'):format(v)`.
- **F-017:** in `expandMainCategory`, on the `pcall` returning `false`, set a flag `PrettyChat._expandFailed = true` and have `OpenConfig` print a one-time grey notice when the flag is set.
- **F-027:** add a single comment block at the top of `patchAlwaysShowScrollbar` listing the AceGUI internal field names it touches and the AceGUI version verified against.
- **F-028:** sync `GlobalStrings/GlobalStrings.toc`'s `## Interface:` line with the parent TOC.
- **F-030:** decide — either `git rm --cached TODO.md` (and remove from `.gitignore`) or remove `TODO.md` from the working tree.
- **F-032:** capture the bool return of `Settings.OpenToCategory` and fall back to a chat notice on `false`.
- **F-035:** add prefix-match to `Schema.ResolveCategory` (only if no exact match — keeps current behavior).
- **F-037:** rephrase `docs/file-index.md:9` and `README.md:47-54` to talk about "rows" or "registrations" (clarifies the cross-category double registration).

