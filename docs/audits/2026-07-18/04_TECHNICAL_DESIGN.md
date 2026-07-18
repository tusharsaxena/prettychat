# 04 — Technical Design (Remediation)

How to close each open gap in `02_DEVIATIONS.md`. Design only — no code is changed by this audit. Each change is keyed to its deviation ID and follows the addon's own guardrails (single write path, `ns.Print` seam, `ns.L` wrapping, green test + lint gate before commit). Remediation is a **separate** engagement that executes `05_EXECUTION_PLAN.md`.

Ordering principle: the documentation-only edits (PC-31/32/36) and pure metadata edits (PC-37/38) are low-risk and independent. The two architectural MUSTs (PC-30, PC-34/35) touch the print/registration seams and are covered by existing suites, so they go behind a TDD step. The documented deviations (PC-10/23/25/27) need a **user decision**, not code.

---

## PC-31 — CLAUDE.md Standards-compliance section (docs-only)
- **Touch:** `CLAUDE.md`.
- **Change:** Retitle H1 to `# CLAUDE.md — Ka0s Pretty Chat`. Insert a `## Standards compliance (read first)` section immediately after the adherence line, using the canonical wording from `documentation-§6` (the two-choice classification: accepted deviation vs. change-the-standard, closing with "when in doubt, treat conformance as a hard requirement and ask"). Keep the existing accepted-deviation bullets (they satisfy the "record it in the addon" half of the rule).
- **Risk:** none (prose). **Test impact:** none.

## PC-32 — agent-context Hard rules open with the standard (docs-only)
- **Touch:** `docs/agent-context.md`.
- **Change:** Prepend the canonical first Hard-rules bullet (`documentation-§6` #4): "**Conform to the Ka0s WoW Addon Standard** (https://github.com/tusharsaxena/WowAddonStandards) … STOP and flag … See the root CLAUDE.md 'Standards compliance' section." This restores the four-place reference (TOC + README badge already present).
- **Risk:** none. **Test impact:** none.

## PC-36 — README Settings-panel table (docs-only)
- **Touch:** `README.md` `### Settings panel`.
- **Change:** Replace the nine-item bullet list with a `Tab | Covers` table (one row per subcategory: General, Loot, Currency, Money, Reputation, Experience, Honor, Tradeskill, Misc). The current bullet prose can move under the table as optional per-panel prose (allowed by `documentation-§1` item 6).
- **Risk:** none. Keep plain-language, player-facing tone.

## PC-37 — .pkgmeta ignores GlobalStrings source (metadata-only)
- **Touch:** `.pkgmeta`.
- **Change:** Add ignore entries: `GlobalStrings/GlobalStrings.lua`, `GlobalStrings/split_globalstrings.py`, `GlobalStrings/GlobalStrings.toc`, `GlobalStrings/README.md`. Do **not** ignore the runtime `GlobalStrings_0NN.lua` chunks (loaded by the TOC — must ship). Verify the packager glob syntax handles the per-file paths (BigWigs packager supports path entries under `ignore:`).
- **Risk:** low — a mis-scoped glob could drop the runtime chunks. Sanity-check by listing what a package run would include.

## PC-38 — help-header format (1-line code edit)
- **Touch:** `settings/Slash.lua:64`.
- **Change:** Remove the ` — ` so the header reads `v<version> slash commands (…)` per `slash-commands-§4`.
- **Risk:** trivial. **Test impact:** if `test_slash.lua` asserts the header string, update that assertion in the same change (TDD).

## PC-39 — profile defaults into defaults/Profile.lua
- **Touch:** new `defaults/Profile.lua`; `core/PrettyChat.lua`; `PrettyChat.toc` file listing.
- **Change:** Move the inline `defaults = { profile = { categories = {} } }` table (`core/PrettyChat.lua:18-29`, including its explanatory comment) into `defaults/Profile.lua` as `ns.ProfileDefaults`. Have `OnInitialize` read `ns.ProfileDefaults` and merge with `ns.Database.defaults` as it does today. Add `defaults\Profile.lua` to the TOC `# Defaults` section (before `defaults\Defaults.lua` if load order matters; it does not — both are plain data).
- **Risk:** low. AceDB provisioning is exercised by `test_database.lua`; keep the merged shape identical.

## PC-33 — TOC section order
- **Touch:** `PrettyChat.toc` file listing only (no `.lua` moves).
- **Change:** Relocate the `# Locales` block (`locales\enUS.lua`) to sit immediately after `# Libraries`, matching `toc-file-§5`. Confirm `enUS.lua` has no dependency on Core/Defaults (it does not — it only builds `ns.L`). The `# GlobalStrings` section stays where it is (documented generated-data exception, PC-25) but should be called out in `CLAUDE.md` as an ordering exception too.
- **Note / user decision:** the standard's `layout-§1` load order (`defaults → locales`) conflicts with `toc-file-§5`'s section order (`Locales` before `Core`). **Flag this to the user** — it may be a signal the standard should reconcile the two rather than a defect to fix in the addon. If the user classifies it as "standard should change," raise it upstream and leave the TOC as-is (documented).
- **Risk:** low — pure load-order reshuffle; run the full suite + an in-client `/reload` smoke check afterward.

## PC-30 — pass NS to :NewAddon + reclaim the printer (architectural MUST)
- **Touch:** `core/PrettyChat.lua`; `tests/wow_mock.lua` (AceAddon mock); possibly `modules/Override.lua`, `settings/*` (they call `GetAddon("PrettyChat")` — still valid, but the object is now also `ns`).
- **Change:**
  1. `NewAddon(ns, addonName, "AceConsole-3.0")` — pass the namespace table.
  2. Because AceConsole's `:Print` mixin now lands **on `ns`**, it clobbers `ns.Print`. Reclaim it immediately after `NewAddon`: keep the real printer at `ns.Util.print` (or a private local) and assign `ns.Print = <that>` right after registration, per `architecture-§2` / anti-pattern #36.
  3. The `PrettyChat` local can become `ns` (or keep a `PrettyChat = ns` alias so the many `function PrettyChat:...` definitions and `GetAddon("PrettyChat")` calls need no churn).
- **TDD / mock fidelity:** update the AceAddon test mock so `NewAddon` **stamps a colliding `:Print`** (rendering `|cff33ff99<self>|r:`), then add a test asserting `ns.Print` still emits the cyan `[PC]` tag after registration (proves the reclaim). This is the anti-pattern #36 / #33 mock-fidelity rule.
- **Risk:** moderate — this is the addon's chat seam. The reclaim must run before any module prints. Fully headless-testable.
- **Sequencing:** do PC-34/PC-35 in the **same sprint** as PC-30, since all three converge on the printer.

## PC-34 — secret-safe output seam (MUST)
- **Touch:** `core/Util.lua`; `core/PrettyChat.lua` (`ns.Print`); `core/DebugLog.lua` (`ns.Debug` / `D:Add`).
- **Change:** Add `ns.IsConcatSafe(v)` (probe via `table.concat({v})` under `pcall`, **never** `..`) and `ns.SafeToString(v)` returning `"<secret>"` for a value a real `table.concat` would reject. Build every `ns.Print` and `ns.Debug` line from `ns.SafeToString` of each arg. The debug sink already funnels through `D:Add`; stringify there.
- **TDD:** `test_util.lua` (new or extended) asserting `SafeToString` on nil/bool/string/number and a fake "secret" (a table with a metatable whose `__concat`/`table.concat` raises) returns `<secret>`; and that `IsConcatSafe` probes `table.concat`, not `..`.
- **Risk:** low functionally (no live secrets today), but the change is on the hot print path — keep the fast path (already-safe scalars) allocation-free.

## PC-35 — funnel Test() through ns.Print (MUST)
- **Touch:** `modules/Override.lua` (`Test()` + label helpers); `settings/Schema.lua:187`.
- **Change:** Replace each `DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. …)` with `ns.Print(…)` (the printer prepends `PREFIX` and secret-stringifies — so drop the manual `PREFIX ..`). For the empty spacer lines (`PREFIX` alone), call `ns.Print("")`. In `Schema.lua:187`, drop the hand-written `|cffff5050[schema]|r` tag ahead of `ns.Print`; let the printer own the tag and pass the message body only.
- **TDD:** `test_render.lua` / `test_apply.lua` may capture printed lines — assert they still begin with the cyan `[PC]` tag and carry the same content.
- **Risk:** low. Depends on PC-34 landing first (so the funnel is secret-safe).

## PC-28 — `ns` → `NS` rename (SHOULD, optional)
- **Touch:** every `.lua` source header + body references.
- **Change:** Mechanical rename `ns` → `NS` for the namespace upvalue. Purely cosmetic suite-consistency; the luacheck `211/addonName` ignore comment references the idiom and would update too.
- **Risk:** low but broad diff; only worth doing if the user wants collection-wide naming consistency. Can be deferred indefinitely.

---

## Documented deviations — user decision, no code design

- **PC-10 (X-Wago-ID):** add once a real Wago listing exists; otherwise keep the `CLAUDE.md`-recorded accepted deviation. No placeholder.
- **PC-23 (40/60 editor):** keep the in-code-justified deviation, or migrate to a `wide=true` full-width editor. Re-confirm against v2.7.0.
- **PC-25 (GlobalStrings root folder):** keep the documented generated-data exception, or relocate under a typed subfolder. Cosmetic.
- **PC-27 (Title/Author branding):** keep the documented brand-mark deviation, or normalise.

Each of these is exactly the "accepted deviation vs. change the standard" choice the `CLAUDE.md` guardrail reserves for the user — the remediation engagement must **not** resolve them unilaterally.
