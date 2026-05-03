# Review findings — Ka0s Pretty Chat

**Verdict:** **minor issues**. The addon is ship-ready. No critical taint or data-loss concerns; no deprecated-API usage that will break on a near-future patch. Findings are concentrated on dead/vestigial code, two real correctness gaps in `buildSampleArgs` / `Test()`, an event registration that should move to `OnEnable`, a couple of UX inconsistencies, and convention/doc drift around the doc-of-record. Most are Low–Medium with one solidly High (the panel-rebuild-from-`PLAYER_LOGIN` race against `OnEnable` is fine in practice but the bootstrap design is fragile).

## Conventions detected

- `ns.Print` is the chat chokepoint (cyan `[PC]` prefix). Apply the "no raw `print(`" rule.
- `COMMANDS` table in `PrettyChat.lua` drives slash dispatch and `/pc help` from one source. Apply the "every documented command must be in the table" check.
- `ns.Schema.Set(path, value)` is the single write path. Apply the "no direct `db.profile.categories[...]` writes outside Schema" check.
- `Schema.lua` defines flat-row settings; rows do not currently carry a `tooltip` field as a convention (tooltip strings live inline in `Config.lua`), so no tooltip-row check applies.
- No `docs/CLAUDE_SECRET_VALUES.md` and no protected-API consumption in this addon — taint surface is limited to `Settings.OpenToCategory`, which is already gated by `InCombatLockdown`.
- `.gitattributes` declares `text=auto eol=crlf` for all text — checked, OK.

---

## High

### F-001 — `Schema.NotifyPanelChange` original implementation in `Schema.lua` is dead code [design][dead-code]

**Where:** `Schema.lua:152-162`.

**Problem:** `Schema.NotifyPanelChange` is declared in `Schema.lua` with a body that invokes `LibStub("AceConfigRegistry-3.0", true):NotifyChange("PrettyChat_<Category>")`. `Config.lua:628-635` *unconditionally replaces this function at file-load*, before any code path that could call it. The original body is unreachable, and the `PrettyChat_<Cat>` AceConfig apps it pretends to refresh are never registered anywhere.

**Impact:** Misleads any reader trying to understand the module: the comment in `Schema.lua` claims AceConfigDialog cache invalidation, but `Config.lua` is the actual implementation and uses a refresher dispatch. The vestigial `LibStub("AceConfigRegistry-3.0", true)` call is also why `AceConfig-3.0` is still in the TOC even though `ARCHITECTURE.md:65` itself says it's "not currently used at runtime — kept for future re-wiring without a TOC change". Either the original is the contract (and Config.lua should be a hook, not a replacement) or the original should be deleted and the contract documented in one place.

### F-002 — Bootstrap registers panels from `PLAYER_LOGIN`, not from `PrettyChat:OnEnable` [design][events]

**Where:** `Config.lua:637-642`.

**Problem:** `Config.lua` creates its own `CreateFrame("Frame"); RegisterEvent("PLAYER_LOGIN")` to call `registerPanels()`. The addon already uses Ace3 — `OnInitialize` and `OnEnable` are the canonical lifecycle hooks for an `AceAddon-3.0` object — yet `Config.lua` reaches for a parallel event-frame instead. Two consequences:

1. **Order ambiguity:** the Schema `Set` write path calls `Schema.NotifyPanelChange(category)` from the moment the schema is built (file load). If a user re-binds a chat command and `/pc set …` fires before `PLAYER_LOGIN` (e.g. another addon's `ADDON_LOADED` handler), `PrettyChat.subRefreshers` is the empty table set at line 563 and the notify silently no-ops. That's the *intended* behavior (`pcall` swallows the missing entries), but it relies on subtle file-load ordering rather than a documented invariant.
2. **Two lifecycle owners:** `PrettyChat.lua` runs `OnInitialize`/`OnEnable`; `Config.lua` runs its own `PLAYER_LOGIN` handler. Anyone debugging panel-init order has to reason about both.

**Impact:** Fragility. The bootstrap also never `UnregisterEvent`s a non-`AceEvent` frame (it does `UnregisterAllEvents` after first fire — fine, but only fine because `PLAYER_LOGIN` fires once per session). Routing through `PrettyChat:OnEnable` (which already runs after `PLAYER_LOGIN` for a non-LoD addon) collapses the two owners into one and makes the order explicit.

### F-003 — `buildSampleArgs` does not handle positional `%n$` conversions [logic][i18n]

**Where:** `PrettyChat.lua:164-171`.

**Problem:** The pattern `"%%[%-+ #0]*%d*%.?%d*([%a])"` does **not** match `%2$s` / `%1$d` style positional conversions, which WoW's modified Lua's `string.format` *does* support and which Blizzard's locale strings frequently use (e.g. `"%2$s does %1$d damage."` for word-order rearrangement in deDE/frFR/zhTW). For an English Blizzard string today, every shipped default in `Defaults.lua` uses positional-free `%s/%d/%.1f`, so this is currently latent. But:

- A user on a non-enUS client who copies their Blizzard original into the panel may get `%2$s` style format strings.
- The Test/preview path will silently emit fewer placeholder args than the format consumes, and `pcall(string.format, ...)` will fail. `Test()` swallows the failure (`pcall ... if ok`) and the line is dropped from the count silently. Worse, the per-string Preview EditBox (`ns.RenderSample`) shows the raw `string.format` error string rather than the rendered sample.

**Impact:** Latent on enUS today; surfaces immediately for any non-English user whose Blizzard originals use positional args. Also surfaces if `Defaults.lua` is ever extended to a Blizzard string that uses them (`ERR_QUEST_REWARD_*` variants for some locales already do).

---

## Medium

### F-010 — `AceConfig-3.0` is loaded by the TOC but never used [design][perf]

**Where:** `PrettyChat.toc:18`, `Libs/AceConfig-3.0/`. Confirmed by repo-wide grep: no `AceConfig:RegisterOptionsTable`, no `AceConfigDialog:Open`, no `AceConfigDialog:AddToBlizOptions`, and no live consumer of `AceConfigRegistry-3.0` after F-001 is resolved. `ARCHITECTURE.md:65` already acknowledges this ("not currently used at runtime — kept for future re-wiring without a TOC change").

**Impact:** Adds a non-trivial library to startup memory and load time for a "future maybe". The decision to keep it is documented but not justified by an actual consumer. Either ship a JIRA-style note in `TODO.md` linking to the planned re-wiring or drop the load.

### F-011 — Shared global `LOOT_ITEM_CREATED_SELF` / `_MULTIPLE` is registered twice and silently last-write-wins [logic]

**Where:** `Defaults.lua:37-44` (Loot) and `Defaults.lua:327-334` (Tradeskill). Documented at `docs/override-pipeline.md:110-116` as a known quirk, intentional, "do not fix without a triggering complaint". The schema builds two distinct rows that both target `_G[LOOT_ITEM_CREATED_SELF]`; `ApplyStrings` writes both during its `pairs(PrettyChatDefaults)` iteration; whichever runs last wins, and `pairs()` order is non-deterministic.

**Impact:** Editing the format on the Loot sub-page can silently lose to the Tradeskill sub-page on the next reload. The existing doc note disclaims responsibility, but the *user* facing this has no in-panel signal that another category is overwriting their value. At minimum, the per-string row in both categories should carry a tooltip noting the cross-registration and recommending the user edit one and disable the other. Better: collapse to a single registration with a UI-level "this string is shared across N contexts" hint.

### F-012 — `Schema.lua`'s `Schema.NotifyPanelChange` uses `LibStub("AceConfigRegistry-3.0", true)` despite no AceConfig app registration [design][dead-code]

**Where:** `Schema.lua:153`. Pair to F-001. Even if F-001 reframes the function as a hook chain rather than a replacement, the AceConfigRegistry call has no consumer because the addon does not call `AceConfig:RegisterOptionsTable("PrettyChat_<Cat>", …)` anywhere. This is the strongest evidence that F-010 (drop AceConfig-3.0) is right.

### F-013 — `Schema.Set` runs `ApplyStrings` twice per panel-widget commit [perf][design]

**Where:** `Schema.lua:50-51, 67-68, 86-87, 107-108` (each row `set` closure runs `ApplyStrings`) plus `Schema.Set` itself does not, but the row already did. Then `Schema.NotifyPanelChange(category)` triggers Config.lua's refresher dispatch, which calls `pcall(fn)` for the affected sub-page's refresh, which itself calls `PrettyChat:GetStringValue` / `IsAddonEnabled` etc. — read-only, so no double-write.

**Looking again:** `ApplyStrings` runs **once** per `Schema.Set` (via the row's `set`). The risk I want to flag is different: every row's `set` closure individually calls `PrettyChat:ApplyStrings()`. If a future code path bulk-mutates many rows (say, a "load preset" feature), the addon will run `ApplyStrings` once per row rather than once per batch. Today's surface only writes one row per user action, so the cost is bounded — but the design embeds an "apply per write" rule in N places (one per row kind) rather than centralizing it in `Schema.Set`.

**Impact:** Maintenance hazard. If `Schema.Set` ever needs a "batch" overload, it has to either coordinate with every row's `set` (invert the dependency) or accept the N-times cost. Cleaner to have `row.set` *only* mutate the DB and leave `ApplyStrings` + `NotifyPanelChange` as the post-write side-effects in `Schema.Set`.

### F-014 — `Test()` and `RenderSample` duplicate `buildSampleArgs` / `pcall(string.format, …)` [design]

**Where:** `PrettyChat.lua:164-171` (`buildSampleArgs`), `PrettyChat.lua:177-183` (`ns.RenderSample`), `PrettyChat.lua:210-217` (Test inline call to `buildSampleArgs` + `pcall(string.format, …)`).

**Problem:** `Test()` re-implements what `ns.RenderSample` already does — it calls `buildSampleArgs(fmt)` then `pcall(string.format, fmt, unpack(args))` rather than calling `ns.RenderSample(fmt)` and using its return. The two paths ought to be one.

**Impact:** Future fixes (e.g. F-003's positional-arg handling) have to be applied in two places, and a divergence will silently break the test/preview parity that the architecture promises.

### F-015 — `defaults` table in `PrettyChat.lua:13-18` declares `enabled = true` and `categories = {}` but the runtime convention treats *absence* as default-true [design]

**Where:** `PrettyChat.lua:13`, paired with `PrettyChat.lua:71-75` (`IsAddonEnabled`) which reads `if self.db.profile.enabled == nil then return true end`.

**Problem:** AceDB merges the defaults table into `db.profile`, which means `self.db.profile.enabled` is never `nil` after `OnInitialize` runs — the defaults always populate it. The `nil → true` branch in `IsAddonEnabled` therefore can never fire from real flow; it's defensive code that suggests the author wasn't sure. Same for `IsCategoryEnabled` at `PrettyChat.lua:77-83`: `catDB.enabled ~= nil` is the runtime check, but defaults don't put `enabled` into per-category sub-tables (since `categories = {}` is the default and AceDB doesn't recursively populate user-keyed sub-tables).

This is *also* why `ResetCategory` for `"General"` does `self.db.profile.enabled = nil` (`PrettyChat.lua:122`) — but AceDB will then re-populate it from the defaults table on next read, so the `nil` write is immediately undone. The user observes "default true" only because the defaults table happens to say `true`. If someone ships a future client where the addon-wide default flips to `false`, the `nil` reset would suddenly NOT restore to true.

**Impact:** The "treat absence as default-true" pattern and the "AceDB defaults table" pattern are at war. Pick one. Either drop `enabled = true` from the defaults table and rely on the `nil → true` guard, or drop the `nil → true` guard and trust the defaults table.

### F-016 — `Schema.NotifyPanelChange` cascade for "General" iterates `PrettyChat.subRefreshers` via `pairs` [design]

**Where:** `Config.lua:629-631`. When master toggle (`General.enabled`) changes, every sub-page's refresher runs. Sub-pages that have never been opened have *no* entry in `subRefreshers` (the body builder only runs on `OnShow`). That's correct — but it means the cascade is incomplete: open the panel, open Loot only, never open Currency, then `/pc set General.enabled false`. The Loot page refreshes; Currency doesn't (no entry yet). On next Currency open, `buildCategoryBody` runs and `refresh()` is called immediately, so the user sees correct state — but only because `OnShow` always runs on first open.

**Impact:** Subtle but correct today. Worth a one-line comment in `Config.lua:628` documenting the lazy-build interaction.

### F-017 — `expandMainCategory` reaches into `SettingsPanel` private API without a fallback path [design][ux]

**Where:** `PrettyChat.lua:42-54`. The function is `pcall`-wrapped and silently no-ops on failure (correct), but if Blizzard renames `GetCategoryList` / `GetCategoryEntry` / `SetExpanded` in a patch, the user gets a closed sub-tree with no chat notice. The smoke tests doc (`smoke-tests.md` T-21) lists this as a known failure mode.

**Impact:** Not a bug. Worth surfacing a one-time `ns.Print` notice when the auto-expand fails (debug-only) so the user can manually click and we can see breakage in user reports rather than silently absorbing it.

### F-018 — `Schema.lua`'s `Schema = {}` and `ns.Schema = Schema` is the publishing pattern, but `buildAddonEnabledRow` and the loop around it run as side effects of file-load [design]

**Where:** `Schema.lua:115-132`. The schema is built at the top level of the file, not behind a callable `Schema.Build()`. This couples the file's load order to the side effect; if anyone ever introduces a unit-test harness or wants to rebuild after a runtime defaults change, there is no entry point.

**Impact:** Organization. Wrap the build in a `Schema.Build()` and call it from the bottom of the file (or from `OnInitialize`). The behavior is unchanged; the seams are documented.

---

## Low

### F-020 — `Schema.lua:153` comment block (lines 148-151) describes a behavior the function no longer performs after F-001 [naming][comments]

**Where:** `Schema.lua:148-151`. Says "NotifyPanelChange invalidates the AceConfigDialog cache for one category", which is false today (Config.lua replaces the function with a refresher dispatch). Misleading.

### F-021 — `cmd()` and `note()` color-helpers are file-local in `PrettyChat.lua` but duplicate the color escapes used in `Config.lua`'s `GOLD/GREY/RED/RESET` [naming]

**Where:** `PrettyChat.lua:235-236`, `Config.lua:13-16`. Two flavors of "wrap text in a color escape": one as a function (slash output), one as concatenated strings (panel labels). Convergent purpose, divergent shape. A small `ns.Color = { gold = …, grey = …, … }` table on `ns.Const` (or its own module) would give both files one source.

### F-022 — `printHelp(self)` accepts a `self` it never uses [naming]

**Where:** `PrettyChat.lua:289`. Same for `runResetAll(self)` (line 400). These take `self` for API uniformity with the dispatcher, which is fine — but a one-line comment would explain why.

### F-023 — `formatValue(v)` quotes strings with `%q`-equivalent but does not escape backslashes or embedded quotes [naming][logic]

**Where:** `PrettyChat.lua:242-247`. `('"%s"'):format(v)` does not escape `"` or `\` inside `v`. For format strings that contain `"`, the `/pc list` / `/pc get` output will look broken (unbalanced quotes). Today's defaults don't contain `"`, but a user-edited override could.

**Fix:** use `%q` (`('%q'):format(v)`).

### F-024 — `Defaults.lua` is a global table assignment with no `local _, ns = ...` line [naming][design]

**Where:** `Defaults.lua:1`. Every other Lua file in the addon starts with `local addonName, ns = ...`. `Defaults.lua` writes `PrettyChatDefaults = {…}` directly. Stylistic outlier; the global is intentional (cross-file) but the missing namespace handshake makes the file read as an oddball.

### F-025 — `LOGO_PATH` in `Config.lua:21-22` hard-codes `"Interface\\AddOns\\" .. addonName .. "\\..."` rather than using `addonName` from `... ` directly [naming]

Already does that. Withdraw.

### F-026 — `attachTooltip` declares an `OnLeave` closure (`hide`) for both `SetCallback` and `HookScript` paths but the AceGUI path's `SetCallback("OnLeave", …)` overrides any prior callback set by AceGUI's widget [design]

**Where:** `Config.lua:48-54`. Some AceGUI widgets (Buttons, CheckBoxes) don't ship default `OnEnter`/`OnLeave` callbacks, so this is fine in practice — but `SetCallback` is "set", not "hook"; if AceGUI ever ships default tooltip handling for these widgets, our callback will replace it. Worth a one-line comment that we're aware of the override semantics.

### F-027 — `patchAlwaysShowScrollbar` mutates AceGUI internal fields directly (`scrollframe`, `content.original_width`, `scrollbar`) [design]

**Where:** `Config.lua:65-163`. The patch reaches into AceGUI's `ScrollFrame` widget internals (`scroll.scrollframe`, `scroll.scrollbar`, `scroll.content`, `scroll.localstatus`, `scroll.updateLock`) — all of which are private to the AceGUI ScrollFrame implementation. The header comment acknowledges this ("Mirrors KickCD's Helpers.PatchAlwaysShowScrollbar"). The `OnRelease` restoration is correct.

**Impact:** When AceGUI updates its ScrollFrame widget (which happens on Ace3 upstream releases), this patch may silently stop working. The pattern is well-established in the WoW addon community, but a one-line "if this breaks, the AceGUI ScrollFrame internals changed" note would speed diagnosis.

### F-028 — `PrettyChat.toc` `## Interface:` is `120000,120001,120005` while `GlobalStrings/GlobalStrings.toc` is `120000` only [toc]

**Where:** `PrettyChat.toc:1`, `GlobalStrings/GlobalStrings.toc:1`. The sub-addon TOC is dormant (no live `LoadAddOn` consumer per `docs/global-strings.md:10`), so the mismatch is harmless today. If the sub-addon is ever re-activated, the narrower interface line will cause the client to flag it as out-of-date for `120001`/`120005` users.

### F-029 — `GlobalStrings/` chunk files emit one `=` assignment per line with no `do…end` block to scope locals [perf]

**Where:** `GlobalStrings/GlobalStrings_001.lua` and siblings. Each chunk file is a flat list of `PrettyChatGlobalStrings["KEY"] = "value"` lines. For ~22,879 entries across 10 files that's fine — Lua's chunk compile is fast — but the assignment-per-line pattern means each line generates a `SETTABLE` opcode. `local t = PrettyChatGlobalStrings` at the top of each chunk and `t["KEY"] = "value"` would shave the repeated upvalue resolution. Marginal at runtime; matters at load-time on the lowest-end machines.

### F-030 — `TODO.md` is committed in the past and `.gitignore`-d going forward [naming]

**Where:** `TODO.md`, `.gitignore:15`. The file is in the working tree (so it was tracked at some point) but `TODO.md` is in `.gitignore`. Either it shouldn't be in the working tree (rm + commit) or it shouldn't be in `.gitignore`. Today the user sees a tracked file that any new edits won't show in `git status` for changes — confusing.

### F-031 — `ns.RenderSample` returns `nil, errorMessage` on failure but `Test()` discards both branches the same way (drops the line) [logic]

**Where:** `PrettyChat.lua:177-183` (`RenderSample`) and `PrettyChat.lua:210-217` (`Test`). `RenderSample` carefully returns the error message for the panel to surface in the Preview EditBox (good). `Test` calls `pcall(string.format, ...)` directly and silently drops failures. Should call `ns.RenderSample` and emit `"|cffaaaaaa(format error: " .. err .. ")|r"` for the failed line, so the user can see *which* string is broken instead of a footer reporting `N-1 strings shown` with no breakdown.

### F-032 — `OpenConfig` swallows the case where `Settings.OpenToCategory` returns false (sub-category not found) [logic][ux]

**Where:** `PrettyChat.lua:56-61`. `Settings.OpenToCategory` returns a bool indicating whether the navigation succeeded. The current code ignores it. If the addon's category somehow isn't registered (Config.lua's bootstrap raced or was suppressed), the user sees nothing happen.

### F-033 — `docs/override-pipeline.md:108` says "No combat guards. `ApplyStrings` is unprotected; `_G` writes don't taint." but `OnEnable` runs `ApplyStrings` and there's no docstring noting that `_G` writes from a non-secure context CAN propagate taint to the consumer if the variable is later read inside a secure code path [comments]

**Where:** `docs/override-pipeline.md:108`. Strictly speaking this is correct — `_G[LOOT_ITEM_SELF]` is consumed by `ChatFrame_MessageEventHandler`, which is non-secure. So no taint. Worth being explicit that the *category* of variable matters.

### F-034 — `OnInitialize` registers chat commands but no `OnEnable` re-registration guard [events]

**Where:** `PrettyChat.lua:23-24`. `RegisterChatCommand` is idempotent on Ace3, so this is fine — but if an Ace3 update ever changes that semantic, the addon doesn't notice. A one-line note in the head comment.

### F-035 — README's "Why do some lines still look like Blizzard's defaults?" FAQ row mentions `/pc list <Category>` for diagnosis but the dispatcher only accepts case-insensitive *exact* names — partial-match like `/pc list Loo` returns "unknown" [ux]

**Where:** `README.md:73`, `Schema.lua:186-193`. Minor docs nuance. The `ResolveCategory` is exact-lowercase-equality. Document or implement prefix-match.

### F-036 — `Defaults.lua:11` `LOOT_CURRENCY_REFUND` default uses `+` for a refund [ux]

**Where:** `Defaults.lua:9-12`. The label is "Currency Refund" and the message structure is `Refund | You | + %s x%d`, but every other `*_REFUND` row in the file (LOOT_ITEM_REFUND, LOOT_ITEM_REFUND_MULTIPLE, LOOT_MONEY_REFUND, MONEY_REFUND) also uses `+ %s` even though semantically a refund is a credit. That's actually consistent — the user is *receiving* the refund — but `CURRENCY_LOST_FROM_DEATH` uses `- %s` (loss). The mental model is "+ = credited to me, - = debited from me". Inconsistent with the english reading of "refund" if you're already half-attentive. Worth a tooltip on these rows clarifying which side of the ledger they're on.

### F-037 — `docs/file-index.md:9` reads "Eight categories with 81 strings total (Loot 19, Currency 4, Money 8, Reputation 14, Experience 20, Honor 6, Tradeskill 8, Misc 2)" — 19+4+8+14+20+6+8+2 = 81 ✓. But README.md:47 says "Loot — 19 strings", README.md:51 says "Experience — 20 strings", and panel renders sort-order matches. Consistent, but `LOOT_ITEM_CREATED_SELF` and `_MULTIPLE` are double-counted (registered in both Loot and Tradeskill — F-011). The "81 strings total" is actually 81 *registrations* across 79 unique globals [ux][docs]

**Where:** `docs/file-index.md:9`, `README.md:47-54`. Cosmetic; clarify "rows" vs. "globals".

### F-038 — `Constants.lua` does not have a `local addonName, ns = ...` line — it goes straight to `ns.Const = ns.Const or {}` [naming]

Wait — `Constants.lua:1` has `local addonName, ns = ...`. Withdraw — verified it's there.

### F-039 — `defaults.profile.categories = {}` sits in the defaults table but AceDB's defaults-merge of `{}` is a no-op for user-keyed sub-tables [naming]

**Where:** `PrettyChat.lua:16`. Cosmetic. The empty subtable in defaults documents intent but does nothing functional. A comment would help.

