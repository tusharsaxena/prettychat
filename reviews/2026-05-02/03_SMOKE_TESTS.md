# Smoke tests — 2026-05-02 review milestones

Targeted in-game checklist for verifying commit `8326ad3` (M0–M8 from `04_EXECUTION_PLAN.md`). This is **not** a replacement for `docs/smoke-tests.md` — it's a focused subset organised by which milestone the test guards, plus new probes for behaviour that the standing suite doesn't cover (positional `%n$` args, prefix-match in `ResolveCategory`, cross-registered tooltip text, lean SavedVariables shape).

Run order is critical-path: each phase exits on green before the next starts. A red light identifies the suspect milestone immediately.

## Pre-flight

- [ ] **Wipe the saved profile.** Quit WoW. Delete `WTF/Account/<acct>/SavedVariables/PrettyChatDB.lua` (and `.bak` siblings). This is required by T-50 / S-7-NEW; many other tests benefit from a clean slate.
- [ ] **Enable script errors.** `/console scriptErrors 1` (or have BugSack loaded). The whole point is to surface Lua errors that the addon would otherwise swallow.
- [ ] **Confirm the build.** `/dump GetBuildInfo()` — record the client version in case anything fails.

## Phase 1 — Boot (catches M3, M5, and any load-order regression)

If any of these fail, **stop**. The addon isn't loading cleanly and later phases will be misleading.

- [ ] **B-1**: Launch WoW with PrettyChat enabled. Watch the load-screen-to-character-select transition. **Expected:** no Lua errors. *(Existing T-01.)*
  - **If red:** suspect M3 (`OnEnable` calls `ns.Config.RegisterPanels`) or M5 (TOC load order). Check `PrettyChat.lua:47-49` and `PrettyChat.toc`.
- [ ] **B-2**: `/dump LibStub("AceConfigRegistry-3.0", true)`. **Expected:** `nil` (the lib is no longer loaded). *(Verifies M5.)*
  - **If non-nil:** the AceConfig-3.0 line crept back into `PrettyChat.toc` somehow.
- [ ] **B-3**: `/pc help` immediately after login (before opening any panel). **Expected:** prints help with cyan `[PC]` prefix and yellow command names. *(Verifies M1 + M3.)*
  - **If red:** M1 (the `Color` table didn't load before `PrettyChat.lua` — check `Constants.lua` precedes `PrettyChat.lua` in TOC) or M3 (slash dispatch broke).
- [ ] **B-4**: `/pc test`. **Expected:** sample lines for every category print. Footer reads `end of test output (N strings shown)` (no `errored` clause). No `[PC] schema not ready yet`. *(Existing T-01 / T-52, plus M6 footer change.)*
- [ ] **B-5**: `/pc` and `/prettychat` both show identical help. *(Existing T-03.)*

## Phase 2 — Override pipeline (catches M4 — Schema.Set ApplyStrings move)

This is the highest-risk milestone because we relocated the apply-on-write side effect. Run **every** test in this phase before moving on.

- [ ] **O-1**: `/pc set General.enabled false`. Loot something / gain XP. **Expected:** Blizzard originals, not PrettyChat formats. `/pc set General.enabled true` — formatting returns. *(Existing T-10.)*
  - **If red:** M4 — `Schema.Set` no longer runs `ApplyStrings`. Check `Schema.lua:200-208`.
- [ ] **O-2**: `/pc set Loot.enabled false`. Loot, then gain XP. **Expected:** loot uses Blizzard's original; XP uses PrettyChat's format. *(Existing T-11.)*
- [ ] **O-3**: `/pc set Loot.LOOT_ITEM_SELF.enabled false`. `/pc test` and inspect `LOOT_ITEM_SELF` vs `LOOT_ITEM` lines. **Expected:** `LOOT_ITEM_SELF` is Blizzard's original; `LOOT_ITEM` is formatted. *(Existing T-12.)*
- [ ] **O-4**: Three-layer priority — master off (everything Blizzard); master on + per-string off (just that one Blizzard); all on (everything formatted). *(Existing T-13.)*
- [ ] **O-5**: `/pc set Loot.LOOT_ITEM_SELF.format ||cff00ff00CustomLoot||r %s`. Loot an item. **Expected:** chat shows `CustomLoot` in green + the link. *(Existing T-34, also exercises Schema.Set's apply path.)*
- [ ] **O-6**: Edit `LOOT_ITEM_SELF.format` to anything different via `/pc set`, then set it back to the **exact default** text. `/reload` and read `PrettyChatDB.profiles.Default.categories.Loot.strings`. **Expected:** the `LOOT_ITEM_SELF` key is absent (auto-clear). *(Existing T-43.)*

## Phase 3 — Cross-surface sync (catches M2 — Schema-owned dispatch)

The dispatch table moved from `PrettyChat.subRefreshers` (replaced from Config) to `Schema.refreshers` (registered from Config). These tests verify the new path works end-to-end.

- [ ] **X-1**: Open `/pc config`, navigate to Loot. Leave the panel open. From chat: `/pc set Loot.LOOT_ITEM_SELF.enabled false`. **Expected:** the panel checkbox flips to unchecked without reopening; the New input becomes disabled. *(Existing T-40.)*
  - **If red:** M2 — `Schema.RegisterRefresher` didn't get called on first OnShow, or `Schema.NotifyPanelChange` isn't dispatching. Check `Schema.lua:175-194` and `Config.lua:618-635`.
- [ ] **X-2**: Open `/pc config`, walk to Loot only (don't open Currency). Leave the panel open. `/pc set General.enabled false`. **Expected:** Loot page widgets visibly disable. Click Currency — its widgets render seeded from the live (disabled) state, no flicker, no stale check marks. *(Existing T-41 + master-cascade probe.)*
- [ ] **X-3**: Edit a value in the panel and press Enter. `/pc get` against the same path. **Expected:** chat shows the new value. *(Existing T-42.)*
- [ ] **X-4** *(NEW — M2 specific)*: Open `/pc config` → Loot. With Loot open, `/pc reset Loot`. **Expected:** the Loot page's per-string Enable + format inputs all snap back to defaults in-place (no panel reopen needed). *(Verifies the `ResetCategory` → `NotifyPanelChange` path against the new dispatch.)*

## Phase 4 — Settings panel (catches M3 bootstrap timing, panel basics)

- [ ] **S-1**: `/pc config` from a closed Settings panel. **Expected:** lands on the parent landing page; left rail shows every sub-page expanded (`General`, `Loot`, `Currency`, `Money`, `Reputation`, `Experience`, `Honor`, `Tradeskill`, `Misc`). *(Existing T-20 + T-21.)*
  - **If red on the auto-expand:** M0-T6 — check `PrettyChat.lua:58-72`. The new failure path prints a one-time grey notice; verify the notice is shown rather than silent.
- [ ] **S-2** *(NEW — M0-T5/T6)*: `/pc config` twice in a row from inside the open Settings panel. **Expected:** if auto-expand failed (e.g. on a future client patch), the grey "could not auto-expand" notice prints exactly **once** per session, not on every click.
- [ ] **S-3**: Per-string block layout — Heading + 3-row 40/60 grid. *(Existing T-23.)*
- [ ] **S-4**: Preview EditBox renders color escapes (not raw `|c…|r`). *(Existing T-24.)*
- [ ] **S-5**: Reset button always visible; Defaults header button skips the popup. *(Existing T-25 + T-26.)*
- [ ] **S-6**: Reset all to defaults → popup appears → Yes → master back to true, every override cleared. *(Existing T-27.)*
- [ ] **S-7**: Edit + commit on Enter; `||` ↔ `|` boundary. *(Existing T-28 + T-29.)*
- [ ] **S-8**: Combat lockdown guard — engage a target dummy, `/pc config` during combat. **Expected:** `cannot open settings during combat`. *(Existing T-37.)*

## Phase 5 — Slash command surface (catches M0-T3/T4 + M0 prefix-match)

- [ ] **L-1**: `/pc list` no-arg — ~170 lines, `[General]` first. *(Existing T-30.)*
- [ ] **L-2**: `/pc list loot` / `LOOT` / `Loot` / `nope`. First three identical, last shows `unknown category`. *(Existing T-31.)*
- [ ] **L-3** *(NEW — M0 prefix-match)*: `/pc list Loo`. **Expected:** matches `Loot` (unambiguous prefix). Then `/pc list L`. **Expected:** `unknown category 'L'` because `L` is ambiguous between `Loot` (well, only Loot starts with L — adjust if smoke shows otherwise; actual ambiguity test below). Then `/pc list E`. **Expected:** matches `Experience` (unambiguous). Then `/pc list re`. **Expected:** `unknown category 're'` because `re` matches both `Reputation`. (`re` is unambiguous because only `Reputation` starts with `re`; the genuine ambiguous case is hard to construct on the current category list — `M` matches `Money`, `Misc` so try `/pc list M`.) Final: `/pc list M`. **Expected:** `unknown category 'M'` (ambiguous — both Money and Misc start with `M`). *(Verifies M0's `Schema.ResolveCategory` prefix-match: unambiguous wins, ambiguous returns nil.)*
  - **If red:** check `Schema.lua:223-237`.
- [ ] **L-4**: `/pc get` for each row kind (`General.enabled`, `Loot.enabled`, `Loot.LOOT_ITEM_SELF.enabled`, `Loot.LOOT_ITEM_SELF.format`, `Nope.bogus.path`). *(Existing T-32.)*
- [ ] **L-5** *(NEW — M0-T4 `%q` quoting)*: `/pc set Loot.LOOT_ITEM_SELF.format Test "with quotes" and \backslash`. Then `/pc get Loot.LOOT_ITEM_SELF.format`. **Expected:** the printed value shows the embedded quotes and backslash properly escaped (e.g. `"Test \"with quotes\" and \\backslash"`), not as a broken unbalanced-quote line.
  - **If red:** M0-T4 — `formatValue` should use `('%q'):format(v)` at `PrettyChat.lua:298-303`.
- [ ] **L-6**: `/pc set` bool aliases — `true`/`false`/`on`/`off`/`yes`/`no`/`1`/`0`. `bogus` errors with the alias list. *(Existing T-33.)*
- [ ] **L-7**: `/pc set` for a format string — round-trip via `/pc get` and the panel. *(Existing T-34.)*
- [ ] **L-8**: `/pc reset Loot` — chat output `Loot reset to defaults`; `/pc list Loot` shows defaults. *(Existing T-35.)*
- [ ] **L-9**: `/pc resetall` — chat output `all settings reset to defaults`; `/pc get General.enabled` returns `true`. *(Existing T-36.)*
- [ ] **L-10**: `/pc bogus` → unknown command + help; `/pc` → help only. *(Existing T-38.)*

## Phase 6 — Render-sample parity (catches M6)

The big one. Positional `%n$` args, Test-via-RenderSample routing, error-line emission.

- [ ] **R-1**: `/pc test` on a clean profile. **Expected:** every category prints sample lines; footer `end of test output (N strings shown)` with **no errored clause**. Header carries `[PC]` prefix; sample bodies do not. *(Existing T-52, plus footer-shape check.)*
- [ ] **R-2** *(NEW — M6 error path)*: `/pc set Loot.LOOT_ITEM_SELF.format Wrong` (no `%s`). `/pc test`. **Expected:** the `LOOT_ITEM_SELF` line is replaced by a grey `(Loot.LOOT_ITEM_SELF format error: …)` line; footer reads `end of test output (N strings shown, 1 errored)`. *(Verifies the error-emission path Test() now goes through.)*
  - **If red:** M6 — Test() should route through `ns.RenderSample`, see `PrettyChat.lua:243-289`.
  - Reset with `/pc reset Loot` after this test.
- [ ] **R-3** *(NEW — M6 positional args)*: `/pc set Loot.LOOT_ITEM_SELF.format %2$s comes before %1$d`. Open `/pc config` → Loot → find the `LOOT_ITEM_SELF` row. **Expected:** the Preview EditBox shows `Sample comes before 42` (positional rearrangement honored — the `%2$s` slot got the string sample, `%1$d` got the integer sample). `/pc test` also prints the rearranged line without erroring.
  - **If red:** M6 — `buildSampleArgs` regex didn't capture `%n$`; check `PrettyChat.lua:192-220`. The pattern is `"%%(%d*%$?)[%-+ #0]*%d*%.?%d*([%a])"` and the positional capture is `posCap:sub(-1) == "$"`.
  - Reset with `/pc reset Loot` after this test.
- [ ] **R-4** *(NEW — M6 RenderSample parity)*: edit any format in the panel and press Enter. **Expected:** the Preview EditBox renders the same string that `/pc test` would print for that row. Both surfaces share `ns.RenderSample`.

## Phase 7 — Persistence (catches M7 — DB defaults convention)

- [ ] **P-1**: With a freshly-wiped profile and PrettyChat untouched (no settings changed), launch and `/reload`. Open `WTF/Account/<acct>/SavedVariables/PrettyChatDB.lua`. **Expected:** `PrettyChatDB.profiles.Default = { categories = {} }` — **no `enabled = true` key** at the profile root. *(Verifies M7 — `enabled = true` is no longer in the defaults table.)*
  - **If red:** check `PrettyChat.lua:13-23` — the `defaults.profile` table should only contain `categories = {}` and a comment.
- [ ] **P-2**: Without changing anything, `/pc test`. **Expected:** formatted output (i.e. `IsAddonEnabled()` correctly reads `nil → true`).
- [ ] **P-3**: `/pc set General.enabled false`. `/reload`. `/pc get General.enabled`. **Expected:** `false` (persisted). `/pc set General.enabled true`. `/reload`. `/pc get General.enabled`. **Expected:** `true` (persisted both directions).
- [ ] **P-4**: `/pc resetall`. Inspect `PrettyChatDB`. **Expected:** `enabled` key is removed; `categories = {}`; back to the lean shape.
- [ ] **P-5**: Make exactly one change (disable `Loot.LOOT_ITEM`). `/reload`. Inspect `PrettyChatDB`. **Expected:** `categories.Loot.disabledStrings = { LOOT_ITEM = true }`. No other entries. *(Existing T-50.)*

## Phase 8 — Cross-registered globals tooltip (catches M8)

- [ ] **C-1** *(NEW — M8)*: Open `/pc config` → Loot. Find the `LOOT_ITEM_CREATED_SELF` row. Hover the **Enable** checkbox. **Expected:** tooltip shows the standard "Use the rewritten format…" line followed (on a new line, in grey) by `Shared with Tradeskill — both registrations write the same Blizzard global; the last category to apply wins on /reload.`
- [ ] **C-2** *(NEW — M8)*: Open Tradeskill. Find the same `LOOT_ITEM_CREATED_SELF` row. Hover the Enable checkbox. **Expected:** tooltip footer reads `Shared with Loot — …`.
- [ ] **C-3** *(NEW — M8)*: Open Loot. Pick any string that is **not** cross-registered (e.g. `LOOT_ITEM_SELF`). Hover its Enable checkbox. **Expected:** standard tooltip only — no "Shared with" footer.
  - **If red:** check `Config.lua:387-401` (tooltip decoration) and `Schema.lua:140-159` (`Schema.crossRegisteredGlobals` build).
- [ ] **C-4**: Existing T-53 — edit Loot and Tradeskill copies of `LOOT_ITEM_CREATED_SELF.format` to visibly different strings. `/reload` a few times and trigger creation events. Document the order observed (the doc still says last-write-wins by `pairs()` order — M8 does not change behavior, only surfaces it).

## Phase 9 — Color centralization (catches M1)

Visual smoke — every color escape now sources from `ns.Const.Color`.

- [ ] **K-1**: `/pc help`. **Expected:** `[PC]` prefix is cyan; `/pc <name>` command names are yellow; descriptions are white.
- [ ] **K-2**: `/pc list Loot`. **Expected:** `[Loot]` header is white; setting paths and values are white; rendered without color glitches.
- [ ] **K-3**: `/pc test`. **Expected:** header/footer carry cyan `[PC]` prefix; sample bodies are unprefixed (real-chat appearance).
- [ ] **K-4**: Open `/pc config` → parent landing page. **Expected:** alias note `/prettychat is an alias for /pc` shows in grey; the slash-command list shows `/pc <name>` in yellow with white descriptions.
- [ ] **K-5**: Open `/pc config` → any sub-page → any per-string row. **Expected:** the GLOBALNAME caption (between Enable and Reset) is grey.
  - **If any red:** M1 — check `Constants.lua:42-51` for `Const.Color`, then the call sites: `PrettyChat.lua:5-11`, `PrettyChat.lua:288-289` (`cmd`/`note`), `Config.lua:7` (`local Color = Const.Color`), and `Config.lua:401, 423, 568, 575-577`.

## Synthetic edge probes (existing suite already covers; keep handy)

- T-14 (snapshot persists across `/reload`)
- T-22 (sub-page header breadcrumb `Ka0s Pretty Chat  |  <Cat>`)
- T-51 (format-specifier mismatch — drops or shows raw; superseded by R-2 here)
- T-53 (cross-category shared global behavior — see C-4)
- T-54 (disabled-state propagation to UI inputs)
- T-55 (unknown category name on slash reset)

## Failure protocol

1. Stop at the first red. Capture the steps, chat output, and any Lua error.
2. Map back to the suspect milestone using the **If red** notes inline above.
3. If the failure spans multiple milestones, suspect M2 first (the dispatch refactor touched the most call sites) or M4 (the apply-side-effect relocation).
4. Don't paper over a failure with a quick patch — find the root cause in the relevant `Schema.lua` / `Config.lua` / `PrettyChat.lua` section called out by the milestone.

## Sign-off

If every checkbox above is green, M9 (the plan's pre-release validation milestone) is satisfied. The commit `8326ad3` is ready to push.
