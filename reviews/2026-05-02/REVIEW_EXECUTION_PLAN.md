# Execution plan — Ka0s Pretty Chat review

Companion to `REVIEW_FINDINGS.md` and `REVIEW_PROPOSED_CHANGES.md`. Ordered milestones with human-checkpoints between, so a multi-agent execution can drive the work without surprises.

There are no automated tests for PrettyChat — every milestone exits on `docs/smoke-tests.md` runs (the listed groups, not the full suite). Pre-release does the full suite once.

---

## Milestone M0 — Pre-flight cleanup (low-risk, parallelizable)

Tightens up a handful of self-contained Low findings before any structural changes touch the same files. Everything in M0 is one-file-and-done; agents can run in parallel.

| Task | Owner | Implements | Files |
|------|-------|------------|-------|
| M0-T1 | docs-cleanup | F-028 | `GlobalStrings/GlobalStrings.toc` (sync `## Interface:` to `120000,120001,120005`) |
| M0-T2 | docs-cleanup | F-030 | `TODO.md`, `.gitignore` (decision: keep tracked → remove from `.gitignore`; or untrack → `git rm --cached`) |
| M0-T3 | docs-cleanup | F-035, F-037 | `README.md`, `docs/file-index.md` (rephrase counts; add prefix-match note) |
| M0-T4 | lua-microfix | F-023 | `PrettyChat.lua:242-247` (`formatValue` → `%q`) |
| M0-T5 | lua-microfix | F-032 | `PrettyChat.lua:56-61` (capture `Settings.OpenToCategory` return; chat notice on false) |
| M0-T6 | lua-microfix | F-017 | `PrettyChat.lua:42-61` (`expandMainCategory` failure flag + one-time `OpenConfig` notice) |
| M0-T7 | lua-microfix | F-027 | `Config.lua:65-163` (header comment listing AceGUI internals touched) |

**Concurrency:** all M0 tasks touch disjoint code regions; run in parallel. M0-T4 + M0-T5 + M0-T6 all touch `PrettyChat.lua` but in non-overlapping line ranges — safe to merge sequentially even if drafted concurrently.

**Done when:** `git diff` is small, no behavior change visible to the user, smoke-test quick recipe passes.

**Checkpoint:** human (or coordinator) verifies the diffs read cleanly before M1 starts.

**Suggested commit:** one commit per task family, e.g. `chore(toc): sync sub-addon Interface line` (M0-T1), `chore(docs): clarify rows-vs-globals count` (M0-T3), `fix(slash): %q-quote string values in /pc list output` (M0-T4), etc.

---

## Milestone M1 — Centralize the chat-color palette (low-risk, foundational)

Foundation for later themes — multiple tasks read color constants. Land this first so subsequent milestones touch one source.

| Task | Owner | Implements | Files |
|------|-------|------------|-------|
| M1-T1 | lua-refactorer | F-021 (LLD-6) | `Constants.lua` (add `Const.Color`), `PrettyChat.lua` (replace `PREFIX`, `cmd`, `note`), `Config.lua` (replace `GOLD`/`GREY`/`RED`/`RESET` locals) |

**Concurrency:** single task, three files all referencing the new table. Must serialize.

**Done when:** every chat output line uses `ns.Const.Color.*`; smoke-test T-03 (slash help shows `[PC]` cyan prefix and yellow command names) passes; no visual diff in panel.

**Checkpoint:** human verifies `/pc help` and `/pc list` output colors unchanged.

**Suggested commit:** `refactor(color): centralize chat-color escapes on ns.Const.Color`.

---

## Milestone M2 — Drop dead `NotifyPanelChange` body, install dispatch in Schema (covers Theme 1)

Resolves the design ambiguity of "two implementations". Must precede M5 (drop AceConfig) since the Schema body's `LibStub("AceConfigRegistry-3.0", true)` call is the last live reference.

| Task | Owner | Implements | Files |
|------|-------|------------|-------|
| M2-T1 | lua-refactorer | F-001, F-012, F-020 (LLD-1) | `Schema.lua` (add `Schema.refreshers` + `Schema.RegisterRefresher`; rewrite `NotifyPanelChange`), `Config.lua` (drop `PrettyChat.subRefreshers`, drop the bottom `function ns.Schema.NotifyPanelChange` re-binding, route registrations through `Schema.RegisterRefresher`) |

**Concurrency:** single task, two files tightly coupled. Must serialize.

**Done when:** smoke-tests T-40 (slash mutation reflects in open panel), T-41 (master change cascades to all sub-pages), T-42 (panel mutation reflects in `/pc get`) all pass. `/pc reset Loot` while Loot panel is open shows widgets refresh in-place.

**Checkpoint:** human runs `Cross-surface sync (X)` smoke-test group; verifies no flicker, no stale widgets.

**Suggested commit:** `refactor(schema): consolidate NotifyPanelChange dispatch in Schema; drop Config replacement path`.

---

## Milestone M3 — Move Config bootstrap into OnEnable (covers Theme 2)

Builds on M2 (so Config.lua's bottom is already cleaner). Independent of M4 (which centralizes side effects in Schema.Set, not registration).

| Task | Owner | Implements | Files |
|------|-------|------------|-------|
| M3-T1 | lua-refactorer | F-002 (LLD-2) | `Config.lua` (drop `bootstrap` frame; expose `ns.Config.RegisterPanels`), `PrettyChat.lua` (`OnEnable` calls `ns.Config.RegisterPanels()`) |

**Concurrency:** single task, two files. Must serialize.

**Done when:** smoke-tests T-01 (clean load), T-20 (`/pc config` lands on parent), T-21 (sub-tree auto-expands), T-37 (combat lockdown guard) all pass. The deferred-`OnShow` AceGUI render is preserved.

**Checkpoint:** human verifies that `/pc help` works at the earliest possible moment after login (immediately after the `[PC]` register-chat-command output appears) — proves slash dispatch is live before panel registration runs (it always was, but the change must not regress this).

**Suggested commit:** `refactor(config): register panels from OnEnable instead of PLAYER_LOGIN bootstrap`.

---

## Milestone M4 — Centralize side effects in Schema.Set (covers Theme 3)

Reorganizes per-row `set` closures to be pure DB writes; `Schema.Set` becomes the single owner of `ApplyStrings + NotifyPanelChange`.

| Task | Owner | Implements | Files |
|------|-------|------------|-------|
| M4-T1 | lua-refactorer | F-013, partially F-014 (LLD-3) | `Schema.lua` (strip `PrettyChat:ApplyStrings()` from each `set` closure; add it to `Schema.Set`) |

**Concurrency:** independent of M2/M3 in terms of files (Schema.lua only). But sequencing M4 *after* M2 keeps the diff-read clean (M2 already touched Schema.lua).

**Done when:** smoke-tests `O` group (Override pipeline — T-10 through T-14) all pass; smoke-tests T-43 (auto-clear on default match) passes.

**Checkpoint:** human runs `O` group end-to-end. Critical because this milestone moves the apply-on-write side effect.

**Suggested commit:** `refactor(schema): move ApplyStrings call from row closures into Schema.Set`.

---

## Milestone M5 — Drop AceConfig-3.0 from TOC (covers Theme 4)

Depends on M2 having removed the last `LibStub("AceConfigRegistry-3.0", true)` call. Once landed, this is a one-line TOC edit.

| Task | Owner | Implements | Files |
|------|-------|------------|-------|
| M5-T1 | wow-toc-cleanup | F-010 (LLD-4) | `PrettyChat.toc` (delete the AceConfig line), `ARCHITECTURE.md:65` (remove "kept for future re-wiring") |

**Concurrency:** independent of M3/M4. Must follow M2.

**Done when:** smoke-tests T-01 (clean load — no Lua errors during the AceConfig load that no longer happens) passes; verify in `/dump LibStub("AceConfigRegistry-3.0", true)` that the lib is `nil` after the change.

**Checkpoint:** human runs full Boot (`B`) + Slash (`L`) groups. Belt-and-suspenders to catch any forgotten consumer.

**Suggested commit:** `chore(toc): drop unused AceConfig-3.0 from load order`.

---

## Milestone M6 — Render-sample parity + positional-arg support (covers Theme 5)

Two findings that share the `buildSampleArgs` / `Test` / `RenderSample` triangle. Address them together to avoid touching `PrettyChat.lua:149-224` twice.

| Task | Owner | Implements | Files |
|------|-------|------------|-------|
| M6-T1 | lua-refactorer | F-003, F-014, F-031 (LLD-5) | `PrettyChat.lua:149-224` (`buildSampleArgs` recognizes `%n$type`; `Test` calls `ns.RenderSample`; failure path emits a grey error line) |

**Concurrency:** independent of M2/M3/M4/M5. Single file. Can run in parallel with M5.

**Done when:** smoke-tests T-51 (format-specifier mismatch) and T-52 (sample arg coverage) pass. Add a manual probe: edit one format to use `%2$s %1$d` (synthetic), reload, run `/pc test`, confirm the rendered line shows args in positional order.

**Checkpoint:** human runs the manual `%2$s %1$d` probe.

**Suggested commit:** `fix(sample): handle positional %n$ conversions; route Test through RenderSample`.

---

## Milestone M7 — DB defaults convention cleanup (covers Theme 7)

Drops the `enabled = true` from `defaults.profile`. Behavior unchanged for both new and existing profiles because the read helpers already do `nil → true`.

| Task | Owner | Implements | Files |
|------|-------|------------|-------|
| M7-T1 | lua-refactorer | F-015, F-039 (LLD-7) | `PrettyChat.lua:13-18` (drop `enabled = true`; add a comment), `docs/schema.md` (document the `nil → true` convention as the contract; remove any contradictory phrasing) |

**Concurrency:** independent. Single file (plus docs). Can run in parallel with M6.

**Done when:** smoke-tests T-50 (saved variables shape) passes; new-profile install shows `PrettyChatDB.profiles.Default = { categories = {} }` (no `enabled` key).

**Checkpoint:** human deletes `WTF/.../PrettyChatDB.lua`, fresh-launches, runs `/pc test`, verifies formatted output (proves master-toggle defaults to true via `nil → true`), then disables-and-re-enables master and verifies persistence.

**Suggested commit:** `refactor(db): treat absent enabled as default-true; drop redundant default`.

---

## Milestone M8 — Cross-registered globals UI hint (covers Theme 8)

Pure additive UI text — adds a tooltip to the per-string row when the global is registered in more than one category.

| Task | Owner | Implements | Files |
|------|-------|------------|-------|
| M8-T1 | ux-cleanup | F-011 (LLD-8) | `Schema.lua` (compute `Schema.crossRegisteredGlobals` after row build), `Config.lua` (`buildStringRow` decorates the enable-checkbox tooltip when applicable) |

**Concurrency:** independent. Two files but disjoint line ranges from prior milestones.

**Done when:** smoke-test T-53 (cross-category shared global) re-run shows the tooltip on `LOOT_ITEM_CREATED_SELF` rows in both Loot and Tradeskill sub-pages, naming the other category.

**Checkpoint:** human visual inspection — open Loot, hover the `LOOT_ITEM_CREATED_SELF` enable checkbox, verify tooltip names "Tradeskill"; same for the other side.

**Suggested commit:** `feat(panel): tooltip cross-registered globals so users see the conflict`.

---

## Milestone M9 — Pre-release validation

Run the full `docs/smoke-tests.md` suite. No code changes; this milestone exists to make the human-checkpoint explicit.

| Task | Owner | Implements | Files |
|------|-------|------------|-------|
| M9-T1 | qa-lead | — | (none) |

**Done when:** every smoke test in B/O/S/L/X/P groups passes on a freshly-launched WoW client with a wiped `PrettyChatDB.lua`.

**Checkpoint:** human runs the full suite. Any failure pauses release.

**Suggested commit:** none — this milestone is verification, not change.

---

## Critical-path / concurrency map

```
       M0 (parallel within)
        │
        ▼
       M1 (color palette — touches PrettyChat.lua + Config.lua + Constants.lua)
        │
        ▼
       M2 (NotifyPanelChange — touches Schema.lua + Config.lua)
        │
        ├──▶ M3 (bootstrap — touches PrettyChat.lua + Config.lua)
        │
        ├──▶ M4 (Schema.Set centralization — touches Schema.lua only)
        │
        └──▶ M5 (drop AceConfig — touches TOC only)
                │
                ▼
              (M6, M7, M8 are independent of each other and of M3/M4/M5)
                │
                ▼
              M9 (full suite)
```

**Serialize because of file overlap:**

- M1 → M2 → M3: all touch `PrettyChat.lua` and/or `Config.lua`. Sequential.
- M2 → M5: M5 depends on M2 having dropped the only AceConfigRegistry caller.
- M2 → M4: not strictly required, but sequencing avoids a confusing two-pass diff on `Schema.lua`.

**Parallel-safe families:**

- All M0 tasks (disjoint files).
- M3 / M4 / M5 (after M2 lands): different files (`PrettyChat.lua + Config.lua` / `Schema.lua` / `PrettyChat.toc`). Can fan out.
- M6 / M7 / M8: independent of each other after M5 lands.

---

## Incremental commit strategy

One commit per milestone (not per task) keeps the history readable and gives `git bisect` clean targets. Within M0, group tasks into 3-4 commits by file family (TOC + docs / `PrettyChat.lua` micro-fixes / `Config.lua` micro-fix). Suggested commit messages are listed under each milestone above.

The user controls all `git add` / `git commit` per `CLAUDE.md` — this plan never auto-commits. Each milestone exits with un-staged working-tree edits and a chat summary; the user decides when (and whether) to stage and commit.

---

## Risk register

| Risk | Mitigation |
|------|------------|
| M2 mid-rollout: panel and slash drift because the dispatch is half-installed | Land M2 in one atomic edit; run `X` smoke-tests immediately. |
| M3 timing: `OnEnable` runs before the Settings API is ready in some unusual client init sequence | Keep the `if not (Settings and …)` early-return guard in `registerPanels`. If the guard ever returns, `/pc config` will fail loudly via M0-T5's no-op return-value handling. |
| M4 reordering: a future `Schema.SetBatch` consumer assumes per-row apply | Add a one-line comment in row builders documenting "no apply here — Schema.Set owns the side effect". |
| M6 positional-arg pattern misses an edge case (`%%2$s` literal escape) | Test against the synthetic case; add the `%%` strip step before pattern application (already present in `buildSampleArgs`). |
| M7 existing-profile users have stale `enabled = true` in SavedVariables | Harmless — the read helper accepts both `true` and `nil`. New profiles will have lean SavedVariables. |
| M8 tooltip wording reads as a bug report rather than a hint | Phrase as informational, not warning. Suggest "shared with Tradeskill" rather than "conflict with Tradeskill". |

