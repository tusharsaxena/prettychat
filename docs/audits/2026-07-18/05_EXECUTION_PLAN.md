# 05 — Execution Plan

Ordered, checkable remediation steps for the separate remediation engagement. Grouped into sprints by risk and coupling. Every code sprint ends on the green gate — `lua tests/run.lua` (37+ passing) **and** `luacheck .` (0 errors) — per `testing` / `versioning-git`; commit only on green, trunk-based, no auto-push. Documentation/metadata sprints still run the gate to prove nothing broke. IDs reference `02_DEVIATIONS.md`.

The addon's own guardrail applies throughout: any step that would itself introduce a new deviation, or resolve a **documented** deviation, must **stop and be flagged to the user** — do not resolve unilaterally.

---

## Sprint 0 — User decisions (no code) — do first, unblocks the rest

- [ ] **PC-33 standard conflict** — confirm with the user whether the `layout-§1` (`defaults → locales`) vs `toc-file-§5` (`Locales` before `Core`) conflict is (a) fixed in the addon (move `# Locales`), or (b) raised upstream as a standard reconciliation. Record the choice.
- [ ] **PC-10** — add `## X-Wago-ID` now (real id available?) or keep the accepted deviation.
- [ ] **PC-23** — keep the justified 40/60 editor or migrate to `wide=true`.
- [ ] **PC-25** — keep the GlobalStrings root exception or relocate.
- [ ] **PC-27** — keep the brand-mark Title/Author or normalise.
- [ ] **PC-28** — do the `ns` → `NS` rename now, later, or never.

## Sprint 1 — Documentation & metadata (low risk, independent)

- [ ] **PC-31** — retitle `CLAUDE.md` H1 to `# CLAUDE.md — Ka0s Pretty Chat`; add the `## Standards compliance (read first)` section (canonical `documentation-§6` wording).
- [ ] **PC-32** — prepend the conform-to-the-standard rule as the **first** `## Hard rules` bullet in `docs/agent-context.md`, with the repo URL and a pointer back to the CLAUDE.md section.
- [ ] **PC-36** — convert README `### Settings panel` to a `Tab | Covers` table (9 rows); keep any per-panel prose below it.
- [ ] **PC-37** — add `.pkgmeta` ignore entries for `GlobalStrings/GlobalStrings.lua`, `split_globalstrings.py`, `GlobalStrings/GlobalStrings.toc`, `GlobalStrings/README.md`; confirm the runtime `GlobalStrings_0NN.lua` chunks still package.
- [ ] Gate: `luacheck .` clean (no Lua changed; sanity only). Commit.

## Sprint 2 — Contained code edits (low risk)

- [ ] **PC-38** — remove the ` — ` from the help header (`settings/Slash.lua:64`); update any `test_slash.lua` assertion in the same change.
- [ ] **PC-39** — create `defaults/Profile.lua` (`ns.ProfileDefaults`), move the inline profile-defaults table out of `core/PrettyChat.lua`, wire `OnInitialize` to read it, add `defaults\Profile.lua` to the TOC `# Defaults` section. Keep the merged AceDB shape identical (`test_database.lua` stays green).
- [ ] **PC-33 (if Sprint 0 chose "fix in addon")** — move the `# Locales` block to immediately after `# Libraries` in `PrettyChat.toc`; note the `# GlobalStrings` ordering exception in `CLAUDE.md`.
- [ ] Gate: full suite green + `luacheck .` clean. In-client `/reload` smoke check (panel loads, `/pc list` works). Commit.

## Sprint 3 — Print/registration seam (moderate risk, TDD, coupled — do together)

Land PC-30, PC-34, PC-35 in one sprint; they converge on the chat printer.

- [ ] **PC-34 (first)** — add `ns.IsConcatSafe` / `ns.SafeToString` to `core/Util.lua` (probe `table.concat`, never `..`); route `ns.Print` and `ns.Debug`/`D:Add` line-building through `SafeToString`. Add `test_util.lua` cases (nil/bool/string/number + a fake secret → `<secret>`; probe uses `table.concat`).
- [ ] **PC-30** — change `NewAddon("PrettyChat", …)` to `NewAddon(ns, addonName, "AceConsole-3.0")`; keep the real printer at `ns.Util.print` and reclaim `ns.Print = ns.Util.print` right after registration. Add a `PrettyChat = ns` alias (or migrate `GetAddon` call sites). **Update `tests/wow_mock.lua`** so the AceAddon mock stamps a colliding `:Print` mixin (`|cff33ff99<self>|r:`); add a test asserting `ns.Print` still emits the cyan `[PC]` tag post-registration.
- [ ] **PC-35** — replace every `DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. …)` in `modules/Override.lua` `Test()` (and the `[schema]` line in `settings/Schema.lua:187`) with `ns.Print(…)` (drop the manual `PREFIX ..`; `ns.Print("")` for spacer lines). Update any print-capturing assertions in `test_render.lua`/`test_apply.lua`.
- [ ] Gate: full suite green (new secret-safe + printer-survival cases included) + `luacheck .` clean. In-client smoke: `/pc test`, `/pc debug on` in and out of combat, `/pc help` shows the cyan tag. Commit.

## Sprint 4 — Optional consistency

- [ ] **PC-28 (if Sprint 0 opted in)** — mechanical `ns` → `NS` rename across all `.lua` + the `.luacheckrc` `211/addonName` comment. Full suite green; large diff, isolate in its own commit.

---

## Definition of done

- Every **open** MUST (PC-30, PC-31, PC-32, PC-33*, PC-34, PC-35, PC-36) is closed or explicitly reclassified by the user as an accepted deviation recorded in `CLAUDE.md`. *(PC-33 may be reclassified as an upstream-standard change.)*
- Every **open** SHOULD (PC-37, PC-38, PC-39, PC-28) is closed or consciously deferred.
- The four-place standards reference (`documentation-§6`) is satisfied in all four places (TOC, README badge, CLAUDE.md section, agent-context Hard rules).
- Gates green; README `[Tests]` badge + `docs/test-cases.md` regenerated and in lockstep if the case count moved.
- Documented deviations (PC-10, PC-23, PC-25, PC-27) each carry a fresh user decision in `CLAUDE.md`.
- No version bump and no commit/push unless the user explicitly asks (per `CLAUDE.md` guardrails).
