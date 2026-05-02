# Smoke tests

There are no automated tests for PrettyChat — the addon's behavior depends on WoW client state (`_G[GLOBALNAME]`, AceDB profile, the live chat frame, the Settings panel) that can't be exercised outside the game. Validation is manual, in-game, against this checklist.

Run the **quick recipe** for routine work. Run the **full suite** before tagging a release, after touching `OnEnable` / `ApplyStrings` / `Schema.lua`, or after a WoW client patch.

If you can only reason about a change from code and cannot test it in WoW, say so explicitly — don't claim it works.

## Quick recipe

For a routine change (one new format string, a doc edit, a CSS-level panel tweak):

1. `/reload` — file-load-time builders re-run.
2. `/pc test` — dump a synthesized sample of every format string. Output ignores enable toggles, so this works even when the addon is disabled.
3. Trigger one real chat event (loot an item, gain XP, repair an item, etc.) and read the actual chat line.
4. Open `/pc config`, walk to the affected category sub-page, exercise the toggle and edit boxes for the changed row.

If all four pass, you're good for routine work. The full suite below catches the rest.

## Full suite

Tests are grouped by subsystem. Each test has an ID (`T-NN`), a one-line **Why** line stating the invariant it guards, **Setup**, **Steps**, and **Expected**. A failing test means a regression — track down the cause before merging.

### B — Boot and load

#### T-01 — Clean load with default profile

> Why: `OnInitialize` + `OnEnable` run without errors and the snapshot captures every Blizzard original.

- Setup: delete `WTF/Account/<acct>/SavedVariables/PrettyChatDB.lua` (or use a fresh character).
- Steps: launch WoW with PrettyChat enabled. Observe the load-screen-to-character-select transition.
- Expected: no Lua errors. After login, `/pc test` prints sample lines for every category. No `[PC] schema not ready yet` messages.

#### T-02 — Reload on a populated profile

> Why: AceDB rehydrates user overrides + per-category enabled flags + disabledStrings without losing entries.

- Setup: starting from a clean profile, edit one Loot format via the panel and disable one string via its per-string toggle.
- Steps: `/reload`. Then `/pc list Loot`.
- Expected: the edited format and the disabled-string state are both still present. `_G[<edited>]` reflects the user's override; `_G[<disabled>]` matches Blizzard's original.

#### T-03 — Slash registration

> Why: `/pc` and `/prettychat` both dispatch through `OnSlashCommand`.

- Steps: `/pc help` and `/prettychat help`.
- Expected: identical output from both. Header shows `v<VERSION>` matching the TOC. All eight commands listed (`help`, `config`, `list`, `get`, `set`, `reset`, `resetall`, `test`).

### O — Override pipeline (the three enable layers)

#### T-10 — Master toggle off restores every original

> Why: `General.enabled = false` short-circuits `ApplyStrings` to the restore branch for every string.

- Setup: enable PrettyChat normally.
- Steps:
  1. `/pc test` — note the formatted sample lines.
  2. `/pc set General.enabled false`.
  3. Loot an item, gain XP, repair gold.
  4. `/pc set General.enabled true`.
- Expected: between steps 2 and 4, every chat line uses Blizzard's original format (no `[PC]` color-coded layout). After step 4, formatting returns. Customizations persist (the master toggle does not erase them).

#### T-11 — Per-category toggle off

> Why: `<Category>.enabled = false` skips that category's strings only.

- Steps: `/pc set Loot.enabled false`. Loot one item AND gain XP.
- Expected: loot line uses Blizzard's original; XP line still uses PrettyChat's format. Re-enable: `/pc set Loot.enabled true` — loot reformatting returns.

#### T-12 — Per-string toggle off

> Why: `disabledStrings[NAME] = true` skips that one string only.

- Steps: `/pc set Loot.LOOT_ITEM_SELF.enabled false`. Loot an item *yourself*, then loot one as a *group member* (or `/pc test` and inspect both `LOOT_ITEM_SELF` and `LOOT_ITEM` lines).
- Expected: `LOOT_ITEM_SELF` reverts to Blizzard's original; `LOOT_ITEM` still uses PrettyChat's format. Re-enable: returns to formatted.

#### T-13 — Layer priority: addon > category > string

> Why: any layer being off wins; only "all three on" produces user-formatted output.

- Steps: turn off the master while the per-category and per-string are on. Then turn on the master but turn off one per-string. Then turn everything on.
- Expected: phase 1 — every line is Blizzard's original (master wins). Phase 2 — that one string is Blizzard's original, others are formatted. Phase 3 — every line is formatted.

#### T-14 — Snapshot persists across `/reload`

> Why: `originalStrings` is rebuilt at every `OnEnable`, so a `/reload` mid-session refreshes the snapshot from current `_G`.

- Steps: `/pc set General.enabled false` so every original is restored. `/reload`. Inspect chat behavior.
- Expected: chat lines still use Blizzard's originals. `/pc set General.enabled true` — formatting returns immediately.

### S — Settings panel

#### T-20 — `/pc config` lands on the parent landing page

> Why: `OpenConfig` calls `Settings.OpenToCategory(self.optionsCategoryID)` against the parent ID.

- Steps: `/pc config`.
- Expected: panel opens with "Ka0s Pretty Chat" selected in the left rail and the parent landing page visible (logo + tagline + slash command list). The page header reads `Ka0s Pretty Chat` (no breadcrumb prefix).

#### T-21 — Sub-category tree auto-expands

> Why: `expandMainCategory(self.optionsCategory)` walks `SettingsPanel:GetCategoryList():GetCategoryEntry(cat):SetExpanded(true)` inside `pcall`.

- Steps: starting from the closed addon list, `/pc config`.
- Expected: the left rail shows every sub-page (`General`, `Loot`, `Currency`, `Money`, `Reputation`, `Experience`, `Honor`, `Tradeskill`, `Misc`) without the user clicking the disclosure arrow.
- Failure mode: tree stays collapsed. Cause: a future patch renamed `GetCategoryList` / `GetCategoryEntry` / `SetExpanded`. The `pcall` wrapper prevents an error, but the auto-expand silently no-ops. Falls back to manual click.

#### T-22 — Sub-page header breadcrumb

> Why: sub-pages prefix titles via `TITLE_PREFIX = "Ka0s Pretty Chat  |  "`.

- Steps: open each sub-page in turn.
- Expected: page header reads `Ka0s Pretty Chat  |  Loot`, `Ka0s Pretty Chat  |  Currency`, etc. Atlas divider underneath in the same gold as the title.

#### T-23 — Per-string block layout

> Why: `buildStringRow` renders `Heading + 3 × Flow row (40/60)`.

- Steps: open Loot. Pick any string.
- Expected layout:
  ```
  ─── <strData.label> ───
  [Enable]            | Original [disabled EditBox]
  GLOBALNAME (grey)   | New      [editable EditBox]
  [Reset]             | Preview  [disabled EditBox]
  ```
  Left column = 40% width. Right column = 60%, EditBoxes have their `Original` / `New` / `Preview` labels above the input.

#### T-24 — Preview EditBox renders color escapes

> Why: `InputBoxTemplate`'s FontString processes `|c…|r` natively, so `previewInput:SetText(rendered)` shows colored output.

- Steps: open Loot, find `LOOT_ITEM_SELF`. Read the Preview row.
- Expected: the rendered sample shows colored (red `Loot`, green `You`, etc.), NOT raw `|cffff0000Loot|r` text.
- If you see the raw escape codes literally, `InputBoxTemplate`'s color-rendering behavior changed and we need a Label-in-a-frame fallback.

#### T-25 — Reset button is always visible

> Why: refresh closure removed the conditional `Show()` / `Hide()` — Reset always shown; clicking it when value already equals the default is a harmless no-op via the schema's auto-clear.

- Steps: open a fresh Loot sub-page. Note that every per-string row has a Reset button visible. Click Reset on a row whose value matches the default.
- Expected: button stays visible; nothing changes (no error, no panel re-render visible to the user).

#### T-26 — Per-category Defaults button (header)

> Why: `catCtx.defaultsBtn:SetCallback("OnClick", ...)` calls `PrettyChat:ResetCategory(category)` directly — no popup.

- Setup: edit one Loot format and disable one Loot string via the panel.
- Steps: click **Defaults** in the Loot page header.
- Expected: the edit reverts to default; the disabled toggle re-enables; no popup confirmation appears. `/pc list Loot` shows everything at default.

#### T-27 — Reset all to defaults popup

> Why: General → Reset all to defaults shows `PRETTYCHAT_RESET_ALL` StaticPopup; on Yes, `PrettyChat:ResetAll()` clears master + every category.

- Setup: edit two formats across two categories, disable one string, set master to false.
- Steps: open General → click "Reset all to defaults" → click Yes.
- Expected: popup appears with the confirm text. After Yes: master is back to true (default), every override is cleared, every disabled string is re-enabled. `/pc list` shows only defaults.

#### T-28 — Edit + commit on Enter

> Why: `newInput:SetCallback("OnEnterPressed", ...)` calls `ns.Schema.Set(formatPath, value:gsub("||", "|"))`.

- Steps: open Loot. Pick `LOOT_ITEM_SELF`. Edit its New EditBox to a new value (e.g. add a leading `LOOT |` prefix). Press Enter.
- Expected: the value commits. The Preview EditBox updates to show the new format rendered with sample args. Loot an item — the chat line uses the new format.

#### T-29 — `||` ↔ `|` escape boundary

> Why: panel UI shows `||` in edit boxes; saved value uses single `|`. This keeps panel display consistent with `/pc set` (where chat input requires double pipes).

- Steps: open Loot → `LOOT_ITEM_SELF`. Inspect the New EditBox value.
- Expected: the displayed format uses `||cffff0000` (double pipes), NOT `|cffff0000` (single pipe). Now `/pc get Loot.LOOT_ITEM_SELF.format` — chat output shows the format with single pipes (raw stored form). Both surfaces are consistent in their respective conventions.

### L — Slash command surface

#### T-30 — `/pc list` no-arg

> Why: dumps every row across every category in `CATEGORY_ORDER` order.

- Steps: `/pc list`.
- Expected: ~170 lines starting with `[General]`, then `[Loot]`, etc. Each category section lists its `.enabled` row plus every `<NAME>.enabled` and `<NAME>.format` pair.

#### T-31 — `/pc list <Category>` (case-insensitive)

> Why: `Schema.ResolveCategory` lowercase-resolves to canonical PascalCase.

- Steps: `/pc list loot`, `/pc list LOOT`, `/pc list Loot`, `/pc list nope`.
- Expected: first three identical (Loot rows). Last shows `unknown category 'nope'. Valid: General, Loot, Currency, ...`.

#### T-32 — `/pc get` for each row kind

> Why: schema row closures handle `addon_enabled`, `category_enabled`, `string_enabled`, `string_format`.

- Steps:
  - `/pc get General.enabled` → bool
  - `/pc get Loot.enabled` → bool
  - `/pc get Loot.LOOT_ITEM_SELF.enabled` → bool
  - `/pc get Loot.LOOT_ITEM_SELF.format` → quoted string with raw single pipes
  - `/pc get Nope.bogus.path` → `setting not found` error
- Expected: each returns the right value or the right error. No Lua errors.

#### T-33 — `/pc set` bool aliases

> Why: `setSetting` accepts `true/false/on/off/1/0/yes/no`.

- Steps: try each alias on `Loot.enabled`. Then try `/pc set Loot.enabled bogus`.
- Expected: all valid aliases land. `bogus` prints `invalid bool 'bogus' (expected true/false/on/off/1/0/yes/no)`.

#### T-34 — `/pc set` for format string

> Why: `string_format` rows accept the rest of the line literally.

- Steps: `/pc set Loot.LOOT_ITEM_SELF.format ||cff00ff00CustomLoot||r %s`. Then loot an item.
- Expected: format saves (echo confirms). The loot line displays `CustomLoot` in green followed by the item link.

#### T-35 — `/pc reset <Category>`

> Why: `runReset` resolves the category and calls `ResetCategory`, clearing every override in that category.

- Setup: edit two Loot formats, disable one Loot string.
- Steps: `/pc reset loot`.
- Expected: chat output `Loot reset to defaults`. `/pc list Loot` shows everything at default.

#### T-36 — `/pc resetall`

> Why: `runResetAll` calls `ResetAll`, clearing master + every category.

- Setup: scatter changes across multiple categories, set master to false.
- Steps: `/pc resetall`.
- Expected: chat output `all settings reset to defaults`. `/pc get General.enabled` returns `true`. `/pc list` shows defaults everywhere.

#### T-37 — Combat lockdown guard on `/pc config`

> Why: `Settings.OpenToCategory` is taint-protected during combat.

- Steps: enter combat (engage a target dummy or attack a mob). While in combat: `/pc config`.
- Expected: chat prints `cannot open settings during combat`. Panel does NOT open. Leave combat — `/pc config` works.

#### T-38 — Unknown command + empty input

> Why: dispatcher falls back to `printHelp` for both.

- Steps: `/pc bogus`, then `/pc` (no args).
- Expected: `/pc bogus` prints `unknown command 'bogus'` followed by the help index. `/pc` (no args) prints just the help index.

### X — Cross-surface sync (panel ↔ slash)

#### T-40 — Slash mutation reflects in open panel

> Why: `Schema.Set` calls `Schema.NotifyPanelChange(category)` → dispatches to `PrettyChat.subRefreshers[category]` → re-syncs visible widgets.

- Steps: open `/pc config`, navigate to the Loot sub-page. Leave the panel open. From chat: `/pc set Loot.LOOT_ITEM_SELF.enabled false`. Look at the panel.
- Expected: the per-string Enable checkbox for `LOOT_ITEM_SELF` flips to unchecked without reopening the panel. The New input becomes disabled.

#### T-41 — Master change cascades to all sub-pages

> Why: `NotifyPanelChange("General")` runs every sub-page's refresher.

- Steps: open `/pc config`, walk to Loot. Leave it open. `/pc set General.enabled false`. Click each sub-page in turn (Loot, Currency, …).
- Expected: every per-string Enable + format input on every page shows as disabled. Re-enable the master — every input becomes interactable again.

#### T-42 — Panel mutation reflects in `/pc get`

> Why: panel widget callbacks call `ns.Schema.Set` exactly the same way `/pc set` does.

- Steps: edit a value in the panel and press Enter. From chat: `/pc get` against the same path.
- Expected: chat output shows the new value. Panel and slash share one write path.

#### T-43 — Auto-clear on default match

> Why: `string_format` row's `set` closure stores `nil` when the new value equals the PrettyChat default.

- Steps: edit `LOOT_ITEM_SELF.format` to anything different. Inspect `/pc get` (returns custom value). Then set it back to the exact default text. Inspect saved variables: `/reload` and check `PrettyChatDB.profile.categories.Loot.strings`.
- Expected: after the second set, `Loot.strings.LOOT_ITEM_SELF` is absent (or the entire `strings` table is missing). The override entry is auto-cleared.

### P — Persistence and edge cases

#### T-50 — Saved variables shape

> Why: only user-modified values are stored; defaults stay implicit.

- Setup: clean profile, then change exactly one thing (e.g. disable `Loot.LOOT_ITEM`).
- Steps: `/reload`. Open `WTF/Account/<acct>/SavedVariables/PrettyChatDB.lua`.
- Expected: `PrettyChatDB.profiles.Default.categories.Loot.disabledStrings = { LOOT_ITEM = true }`. No other entries under Loot. No `enabled = true` keys (those are nil → default-true).

#### T-51 — Format-specifier mismatch

> Why: a wrong-signature replacement errors at `string.format`. The Test command's `pcall` skips it; live chat may drop the line.

- Setup: `/pc set Loot.LOOT_ITEM_SELF.format Wrong` (no `%s` where Blizzard uses one).
- Steps: `/pc test`, then loot an item.
- Expected: Test's footer reports `N strings shown` where `N` is one less than usual (the bad format is silently skipped). The actual loot line either drops or shows raw.

#### T-52 — Sample arg coverage in `/pc test`

> Why: `buildSampleArgs` should produce typed placeholders (`"Sample"` for `%s`, `42` for `%d/%i/%u/%x/%o`, `1.5` for `%f/%g/%e`, `65` for `%c`, `"?"` for unknowns).

- Steps: `/pc test`.
- Expected: every category prints sample lines. Headers/footers carry the `[PC]` prefix; sample bodies do NOT (they look like real chat).

#### T-53 — Cross-category shared global (`LOOT_ITEM_CREATED_SELF`)

> Why: this key is registered under both `Loot` and `Tradeskill`. Iteration order in `ApplyStrings` is non-deterministic — last writer wins.

- Setup: edit `Loot.LOOT_ITEM_CREATED_SELF.format` and `Tradeskill.LOOT_ITEM_CREATED_SELF.format` to visibly different strings. `/reload` a few times and trigger creation events.
- Expected: live chat shows whichever category's iteration won that load. Documented behavior — see [override-pipeline.md](./override-pipeline.md#known-quirk-globals-shared-across-categories). Do not "fix" without a triggering complaint.

#### T-54 — Disabled state propagates to UI inputs

> Why: when master OR category is off, per-string Enable should be disabled; when any of the three layers is off, New input is disabled.

- Steps: open Loot. Toggle `Enable Loot` off in the page body.
- Expected: every per-string Enable checkbox on the page becomes disabled (greyed). Every New EditBox becomes disabled. The Original EditBox remains as it was (already disabled). Reset button stays clickable.

#### T-55 — Unknown category name on slash reset

> Why: `runReset` validates against `CATEGORY_ORDER` via `ResolveCategory`.

- Steps: `/pc reset Bogus`.
- Expected: chat prints `unknown category 'Bogus'. Valid: General, Loot, ...`. No state change.

## When to run what

| Trigger | Run |
|---------|-----|
| Routine code change | Quick recipe |
| Touched `OnEnable` / `ApplyStrings` / `Schema.lua` | Quick recipe + B + O groups |
| Touched `Config.lua` | Quick recipe + S + X groups |
| Touched slash command surface in `PrettyChat.lua` | Quick recipe + L + X groups |
| Pre-release / pre-tag | Full suite |
| Post WoW client patch | Full suite + regenerate `GlobalStrings/` per [global-strings.md](./global-strings.md#regenerating-chunks-after-a-wow-patch) |

## Reporting a failure

If a test fails:

1. Capture the exact steps, the chat output, and any Lua error (BugSack or `/console scriptErrors 1`).
2. Note the WoW client build (`/dump GetBuildInfo()`).
3. Determine which invariant in [ARCHITECTURE.md § Invariants worth not breaking](../ARCHITECTURE.md#invariants-worth-not-breaking) the failure violates.
4. File or update an issue per [README.md § Issues and feature requests](../README.md#issues-and-feature-requests). Don't ship a "fix" that just makes the test pass — root-cause first.
