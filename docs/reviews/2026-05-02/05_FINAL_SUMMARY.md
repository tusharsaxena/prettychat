# Final summary — 2026-05-02 review execution

This document closes out the review cycle that began with `01_FINDINGS.md` (43 findings, verdict: minor issues), `02_PROPOSED_CHANGES.md` (8 themes + 9 LLDs), and `04_EXECUTION_PLAN.md` (9 milestones M0–M9).

**Status:** all eight code/doc milestones (M0–M8) landed in a single commit. M9 is the in-game smoke-test pass, tracked in `03_SMOKE_TESTS.md`.

## Headline

| Item | Value |
|------|-------|
| Commit | `8326ad3` |
| Branch | `master` (1 commit ahead of `origin/master`) |
| Files touched | 14 (5 code + 9 docs) |
| Lines | +250 / −114 |
| Findings resolved | 18 of 43 (the actionable ones — see "Findings resolved" below) |
| Findings withdrawn during review | 3 (F-025, F-026, F-038 — incorrect premises) |
| Findings deferred | 1 (F-030 — premise was wrong; see "Deferred / no-op") |
| Findings explicitly out of scope | the rest are observational / convention-detection notes that need no change |

## What changed, by milestone

### M0 — Pre-flight cleanup (six low-risk fixes + one no-op)

Resolves: **F-017, F-023, F-027, F-028, F-032, F-035, F-037**.

| Sub-task | File:line | Change |
|----------|-----------|--------|
| M0-T1 (F-028) | `GlobalStrings/GlobalStrings.toc:1` | `## Interface:` synced to `120000,120001,120005` to match parent TOC. |
| M0-T3 (F-037) | `docs/file-index.md:9` | "81 strings total" rephrased as "81 rows over 79 unique globals" with a parenthetical pointing at the Loot/Tradeskill cross-registration. |
| M0-T3 (F-037) | `README.md:53` | Tradeskill bullet adds the cross-registration note. |
| M0-T3 (F-035) | `README.md:35`, `Schema.lua:223-237` | README documents prefix-match support; `ResolveCategory` implements it (exact match wins; falls back to unambiguous case-insensitive prefix; ambiguous prefix returns `nil`). |
| M0-T4 (F-023) | `PrettyChat.lua:298-303` | `formatValue` switches `('"%s"'):format(v)` → `('%q'):format(v)` so strings with embedded `"` or `\` print correctly in `/pc list` / `/pc get`. |
| M0-T5 (F-032) | `PrettyChat.lua:75-86` | `OpenConfig` captures `Settings.OpenToCategory`'s return; on `false`, prints a grey "could not open settings panel — category not registered" notice instead of silently doing nothing. |
| M0-T6 (F-017) | `PrettyChat.lua:53-72, 75-86` | `expandMainCategory` returns `true`/`false` (was `void`); `OpenConfig` prints a one-time grey notice (`PrettyChat._expandWarned` flag) when auto-expand fails, so a future Blizzard rename surfaces in user reports. |
| M0-T7 (F-027) | `Config.lua:53-67` | Header comment lists the AceGUI ScrollFrame internals patched (`scrollframe`, `scrollbar`, `content.original_width`, `localstatus`, `scrollBarShown`, `updateLock`, `FixScroll`, `MoveScroll`, `OnRelease`) and notes the version verified against — the field list to diff on AceGUI upgrade. |

**Why bundled:** the seven sub-tasks touch disjoint regions and run in parallel cleanly. M0-T2 was investigated and dropped — see "Deferred / no-op" below.

### M1 — Centralize chat-color palette in `Const.Color`

Resolves: **F-021** (LLD-6).

- New table `Const.Color = { gold, grey, red, yellow, white, cyan, reset }` at `Constants.lua:42-51`.
- `PrettyChat.lua:5-6` defines `local Color = ns.Const.Color`, then `local PREFIX = Color.cyan .. "[PC]" .. Color.reset .. " "`.
- `cmd` and `note` (`PrettyChat.lua:288-289`) reference `Color.yellow` / `Color.white` instead of inline escapes.
- `PrettyChat.lua:243-289` (`Test`): header/footer/error lines use `PREFIX`, `note`, and `Color.grey` instead of inline `|cff…|r`.
- `PrettyChat.lua:80, 84` (`OpenConfig` notices) use `Color.grey` / `Color.reset`.
- `Config.lua:7` defines `local Color = Const.Color`; the four file-local constants (`GOLD/GREY/RED/RESET`) deleted. Three call sites (`Config.lua:401, 423, 568, 575-577`) reference `Color.*`. `GOLD` and `RED` were dead in `Config.lua` already and don't need new call sites.

**Why this lands first:** four later milestones (M3, M6 errors, M8 tooltip) emit colored chat or panel text. Centralizing the palette before they touch those surfaces means each milestone's diff is single-purpose.

### M2 — Schema owns `NotifyPanelChange` dispatch

Resolves: **F-001, F-012, F-020** (LLD-1).

- `Schema.lua:175-194` defines `Schema.refreshers = {}`, `Schema.RegisterRefresher(category, fn)`, and a rewritten `Schema.NotifyPanelChange(category)` that dispatches to the registered closures (master-toggle / nil cascades to every entry; per-category fires the matching closure if registered).
- `Config.lua:586-642` no longer creates `PrettyChat.subRefreshers`, no longer rebinds `ns.Schema.NotifyPanelChange`. Each sub-page's `OnShow` now calls `Schema.RegisterRefresher(category, refreshFn)` directly (`Config.lua:621, 634`).
- The dead `LibStub("AceConfigRegistry-3.0", true)` call in the old Schema body is gone — paving the way for M5.

**Risk mitigation:** sub-pages that have never been opened have no entry in `Schema.refreshers`. That's correct because their first `OnShow` builds widgets seeded from the live DB; there is nothing stale to refresh.

### M3 — Panel registration moved into `OnEnable`

Resolves: **F-002** (LLD-2).

- `Config.lua:644-645` exposes `ns.Config.RegisterPanels = registerPanels`. The PLAYER_LOGIN bootstrap frame is gone.
- `PrettyChat.lua:34-49` (`OnEnable`) calls `ns.Config.RegisterPanels()` after the snapshot/`ApplyStrings` pair, with an existence guard for load-order safety.
- Combat-lockdown guard for `Settings.*` is preserved — `OnEnable` doesn't run in combat for a non-LoD addon.
- The deferred-`OnShow` AceGUI render is unchanged: panels register at `OnEnable`, but body building still waits until first `OnShow` so AceGUI's `List` layout sees a non-zero container width.

### M4 — `Schema.Set` owns post-write side effects

Resolves: **F-013** (LLD-3).

- All four row `set` closures in `Schema.lua` (lines 50-52, 65-67, 80-86, 89-110) are now **pure DB writes** — no `PrettyChat:ApplyStrings()` call.
- `Schema.Set` (`Schema.lua:200-208`) runs `row.set(value)` then `PrettyChat:ApplyStrings()` then `Schema.NotifyPanelChange(row.category)`. Comment at `Schema.lua:37-41` documents the contract: callers must go through `Schema.Set`; never invoke `row.set(value)` directly.

**Why this matters:** a future `Schema.SetMany` / preset-load can apply once per batch instead of N times. The convention is now centralized in one function instead of duplicated across four row builders.

**Pre-existing direct-write paths checked:** `PrettyChat:ResetCategory` and `PrettyChat:ResetAll` at `PrettyChat.lua:143-167` continue to call `ApplyStrings + NotifyPanelChange` themselves — they bypass `Schema.Set` because they zero out whole sub-tables, not write through a row.

### M5 — Drop AceConfig-3.0 from TOC

Resolves: **F-010** (LLD-4).

- `PrettyChat.toc:17` line `Libs\AceConfig-3.0\AceConfig-3.0.xml` deleted. `Libs/AceConfig-3.0/` stays on disk for future re-wiring.
- `ARCHITECTURE.md:65-67` rewritten — removed AceConfig-3.0 from the dependency bullet list; new paragraph explains the lib is vendored but unloaded, with a re-add hint.
- `ARCHITECTURE.md:73` load-order section updated to remove AceConfig-3.0.
- `docs/module-map.md:101` updated similarly.

**Depends on M2:** the `LibStub("AceConfigRegistry-3.0", true)` call in the old Schema body was the last live consumer.

### M6 — Render-sample parity + positional `%n$` args

Resolves: **F-003, F-014, F-031** (LLD-5).

- `PrettyChat.lua:192-220` (`buildSampleArgs`):
  - New regex `"%%(%d*%$?)[%-+ #0]*%d*%.?%d*([%a])"` captures both the optional positional prefix (`"2$"`, `""`, etc.) and the conversion type.
  - When `posCap:sub(-1) == "$"`, the value goes to `args[index]`; otherwise it's appended.
  - Tracks `maxIdx` and fills positional gaps with `"?"` so `unpack` delivers a dense range.
  - Returns `(args, maxIdx)` — `RenderSample` uses `unpack(args, 1, n)` to avoid the `#args` length-with-holes ambiguity.
- `PrettyChat.lua:225-231` (`ns.RenderSample`) updated to consume the new return shape.
- `PrettyChat.lua:243-289` (`Test`) routes through `ns.RenderSample` instead of duplicating `buildSampleArgs + pcall(string.format, …)` inline. On failure, emits a grey `(<Cat>.<NAME> format error: <msg>)` line. Footer reports both counts: `end of test output (N strings shown[, K errored])` (the `K errored` clause is omitted when zero).
- The per-string Preview EditBox (`Config.lua:480`) already used `ns.RenderSample`; M6 brings `Test` into parity with it.

**Why this matters:** non-enUS Blizzard locales use positional `%n$type` heavily for word-order rearrangement. Before M6, the panel preview and `/pc test` would silently skip those rows or show raw `string.format` errors. After M6, both surfaces handle them and emit a useful error if a user-edited format is malformed.

### M7 — Drop redundant `enabled = true` default

Resolves: **F-015, F-039** (LLD-7).

- `PrettyChat.lua:13-23` defaults table no longer sets `enabled = true`. Comment documents the `nil → true` contract: `IsAddonEnabled` / `IsCategoryEnabled` already treat absence as default-true (`PrettyChat.lua:97-117`), so SavedVariables stays empty until the user explicitly disables something.
- `docs/schema.md:78-90` documents the contract as the canonical convention.

**Backward compatibility:** existing users with `enabled = true` already serialized into `PrettyChatDB.lua` are unaffected — the read helpers handle both `true` and `nil`. New / wiped profiles get a leaner SavedVariables file.

### M8 — Cross-registered globals tooltip

Resolves: **F-011** (LLD-8).

- `Schema.lua:140-159` builds `Schema.crossRegisteredGlobals` after the row loop. Iterates `string_format` rows, groups by `globalName`, keeps the entries with multiple categories. Today this is exactly `LOOT_ITEM_CREATED_SELF` and `LOOT_ITEM_CREATED_SELF_MULTIPLE` → `{Loot, Tradeskill}`.
- `Config.lua:386-405` (`buildStringRow`): when `Schema.crossRegisteredGlobals[globalName]` exists, the per-string Enable checkbox tooltip gets a grey footer line: `"Shared with <other categories> — both registrations write the same Blizzard global; the last category to apply wins on /reload."`
- Behavior unchanged. The only effect is informational — the user sees the conflict in-page rather than discovering it via lost edits.

### Doc sync (rolled into the same commit)

- `CLAUDE.md:17` — namespace publishing table updated: Config.lua "registers a per-sub-page refresh closure via `Schema.RegisterRefresher` on first `OnShow`" (was: "rebinds `Schema.NotifyPanelChange`").
- `ARCHITECTURE.md` — AceConfig-3.0 dropped from deps + load order; new paragraph explains the vendored-but-unloaded state.
- `README.md` — Tradeskill cross-registration note; `/pc list` prefix-match note.
- `docs/file-index.md` — clarified "rows vs globals" count.
- `docs/module-map.md` — new `Schema.RegisterRefresher` and `Schema.crossRegisteredGlobals` rows; AceConfig-3.0 dropped from load order; Config.lua role updated.
- `docs/schema.md` — `Schema.Set` code sample updated to show `ApplyStrings` in the central location; new paragraph on the row `set` closure / `Schema.Set` split; `RegisterRefresher` in the public-API table; `nil → true` contract documented in the SavedVariables shape section.
- `docs/settings-panel.md` — `OnEnable` registration replaces PLAYER_LOGIN bootstrap description; refresher-dispatch section rewritten to show the `Schema`-owned API; Test preview section updated to describe the `RenderSample` routing + error line + new footer; new paragraph in the Color palette section pointing to `ns.Const.Color` for addon UI escapes.
- `docs/smoke-tests.md` — T-40 description updated to reference `Schema.RegisterRefresher`.

## Findings resolved

The 18 findings closed by this commit:

| Finding | Title | Milestone |
|---------|-------|-----------|
| F-001 | `Schema.NotifyPanelChange` original is dead code | M2 |
| F-002 | Bootstrap registers panels from `PLAYER_LOGIN` | M3 |
| F-003 | `buildSampleArgs` does not handle positional `%n$` | M6 |
| F-010 | `AceConfig-3.0` loaded but never used | M5 |
| F-011 | Shared global registered twice without UI signal | M8 |
| F-012 | `LibStub("AceConfigRegistry-3.0", true)` has no consumer | M2 (and confirmed by M5) |
| F-013 | Per-row `ApplyStrings` should be centralized in `Schema.Set` | M4 |
| F-014 | `Test()` and `RenderSample` duplicate sample-args path | M6 |
| F-015 | `enabled = true` in defaults at war with `nil → true` read | M7 |
| F-017 | `expandMainCategory` silently no-ops on Blizzard rename | M0-T6 |
| F-020 | `Schema.NotifyPanelChange` comment describes obsolete behavior | M2 (comment replaced) |
| F-021 | `cmd`/`note` and `GOLD/GREY/RED/RESET` duplicate color escapes | M1 |
| F-023 | `formatValue` does not escape backslashes / quotes | M0-T4 |
| F-027 | `patchAlwaysShowScrollbar` reaches into AceGUI internals without a comment | M0-T7 |
| F-028 | `GlobalStrings/GlobalStrings.toc` Interface line out of sync | M0-T1 |
| F-031 | `Test()` discards format-error info | M6 |
| F-032 | `OpenConfig` swallows `Settings.OpenToCategory == false` | M0-T5 |
| F-035 | `Schema.ResolveCategory` is exact-match only despite README claim | M0-T3 |
| F-037 | "81 strings" double-counts cross-registered globals | M0-T3 |
| F-039 | `defaults.profile.categories = {}` is documentation-only | M7 (comment added) |

## Findings withdrawn during the review (no change needed)

Documented in `01_FINDINGS.md` itself for transparency:

| Finding | Reason |
|---------|--------|
| F-025 | The premise — `LOGO_PATH` doesn't use `addonName` — was wrong; it already does. |
| F-026 | `attachTooltip`'s `SetCallback` semantics are fine for the AceGUI widgets actually in use. Worth a note but not a change. |
| F-038 | The premise — `Constants.lua` lacks a `local addonName, ns = ...` line — was wrong; it has one. |

## Deferred / no-op

| Finding | Reason |
|---------|--------|
| F-030 (`TODO.md` tracked vs. `.gitignore`) | Investigated during M0. `TODO.md` is **not currently tracked** — `git ls-files` returns no match. The reviewer thought it was tracked; the actual state is "untracked local notes file, correctly listed in `.gitignore`". No change needed; M0-T2 is a no-op. |

The remaining ~21 findings in `01_FINDINGS.md` are observational notes (convention detection at the top, "no `docs/CLAUDE_SECRET_VALUES.md`" style confirmations) that don't represent action items.

## Outstanding follow-ups

| Item | Severity | Notes |
|------|----------|-------|
| **M9 — full smoke-test pass** | Required before push | Tracked in `03_SMOKE_TESTS.md`. Phase 1 (boot) is the fast-fail gate; Phase 7 (persistence) requires a wiped `PrettyChatDB.lua`. |
| **Push `8326ad3`** | When you're ready | Branch is 1 commit ahead of `origin/master`. Per CLAUDE.md the user pushes — I won't. |
| **Cosmetic: backslash escapes in commit message body** | Cosmetic only | The single-quoted heredoc in `/wow-addon:commit` was over-escaped — `%n$type` rendered as `%n\$type` and `` `enabled = true` `` rendered as `` \`enabled = true\` ``. The commit content (and code) is correct; only the message text shows stray backslashes. Per CLAUDE.md no auto-amend; needs an explicit "amend the commit message" instruction if you want it cleaned up. |

## Key invariants confirmed unchanged

The five invariants from `CLAUDE.md` and `ARCHITECTURE.md`:

- **Single write path.** Still `ns.Schema.Set(path, value)`. M4 actually strengthens this by centralizing the `ApplyStrings` call.
- **Master toggle wins.** `ApplyStrings` logic at `PrettyChat.lua:126-141` untouched.
- **Format-specifier signatures must match Blizzard's.** Unchanged at the storage layer; M6 only improves the render-sample path's tolerance for positional args.
- **Cyan `[PC]` chat prefix on all addon output.** Now built from `Color.cyan + Color.reset`, value-identical.
- **`OnEnable` snapshots Blizzard originals before any override.** `PrettyChat.lua:34-49` — snapshot loop is exactly as it was; M3 only **appends** the `ns.Config.RegisterPanels()` call after `ApplyStrings`.

## Files touched (final)

```
ARCHITECTURE.md                 |   5 +-
CLAUDE.md                       |   2 +-
Config.lua                      |  71 ++++++++++++------------
Constants.lua                   |  15 +++++
GlobalStrings/GlobalStrings.toc |   2 +-
PrettyChat.lua                  | 118 +++++++++++++++++++++++++++++-----------
PrettyChat.toc                  |   1 -
README.md                       |   4 +-
Schema.lua                      |  82 +++++++++++++++++++++-------
docs/file-index.md              |   2 +-
docs/module-map.md              |  16 +++---
docs/schema.md                  |  14 +++--
docs/settings-panel.md          |  30 ++++++----
docs/smoke-tests.md             |   2 +-
14 files changed, 250 insertions(+), 114 deletions(-)
```

## Closing

The review identified one solidly High-impact issue (M2 — the dispatch ambiguity) and a number of Medium issues; all of them are resolved. There are no breaking changes to user-facing behavior — every change is either invisible (centralization, dead-code removal, internal refactors) or strictly additive (the cross-registration tooltip footer, the format-error grey line in `/pc test`, the unambiguous-prefix accept in `/pc list`).

Run the smoke tests in `03_SMOKE_TESTS.md` and push when green.
