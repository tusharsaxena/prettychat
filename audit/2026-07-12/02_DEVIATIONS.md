# 02 — Deviations

**Standard:** Ka0s WoW Addon Standard **v1.0.0 (2026-07-12)**
**Prefix:** `PC-` (stable across future runs; a deviation that recurs keeps its ID)
**Severity:** MUST = non-negotiable; SHOULD = strongly preferred. `partial` = the rule is met in spirit but not to the letter.

**Counts:** MUST failures: **21** · SHOULD failures: **8** (2 partial). Evidence for every row is in `03_EVIDENCE.md`; fixes are designed in `04_TECHNICAL_DESIGN.md` and ordered in `05_EXECUTION_PLAN.md`.

| ID | § | Severity | Deviation | Fix direction |
|----|---|----------|-----------|---------------|
| PC-01 | §14A, #24 | MUST | No `tests/` harness; no headless coverage of schema / sample-renderer / apply pipeline; addon not developed TDD. | Add `tests/` (run.lua, loader.lua, wow_mock.lua) + suites for Schema, RenderSample, ApplyStrings, migrations. |
| PC-02 | §14 | MUST | No `.luacheckrc`. | Ship root `.luacheckrc` (`std=lua51`, exclude `libs/ audit/ tests/`, declare `PrettyChatDB` write global). |
| PC-03 | §13, #7 | MUST | No `.pkgmeta`. | Ship root `.pkgmeta` (`package-as: PrettyChat`, ignore `audit/ docs/ tests/`, **no** `externals:`). |
| PC-04 | §11, #10 | MUST | No `Compat.lua`; `C_AddOns.GetAddOnMetadata` called directly. | Add `Compat.lua`; route metadata (and any future deprecated API) through `ns.Compat`. |
| PC-05 | §8, #2 | MUST | No locale module; all UI strings hardcoded English inline. | Add `Locale.lua` exporting `ns.L` metatable (English-key fallback); wrap user-facing strings in `L[...]`. |
| PC-06 | §12, #18 | MUST | No debug seam (no `ns.Debug` sink / gated session flag). | Add a zero-alloc-when-off `ns.Debug(tag, fmt, ...)` gated on a session-only `ns.State.debug`; Tier-1 chat fallback per §12.7. |
| PC-07 | §2.2, §5.1 | MUST | No `schemaVersion` in defaults; no `Database.lua` migration runner. | Declare `global.schemaVersion` in defaults; add `Database.lua` with a `RunMigrations()` runner (empty body ok). |
| PC-08 | §2.1, #28 | MUST | TOC field order departs from §2.1; `## iconTexture` mis-cased; `## OptionalDeps` absent. | Reorder to the §2.1 canonical block; fix `IconTexture`; add `OptionalDeps: Ace3, LibStub, CallbackHandler-1.0`. |
| PC-09 | §2.1, §15 | MUST | TOC missing `## X-Standard:`. | Add `## X-Standard: https://github.com/tusharsaxena/WowAddonStandards`. |
| PC-10 | §2.1 | MUST | Published addon but TOC lacks `## X-Curse-Project-ID` and `## X-Wago-ID`. | Add both IDs (Curse project 919766 + Wago ID). |
| PC-11 | §2.5, #28 | MUST | TOC file listing has no `#` section-header comments. | Add Tier-1 `# Libraries` + `# Addon` section comments in load order. |
| PC-12 | §1.3 | MUST | Library folder is `Libs/` (PascalCase), not lowercase `libs/`. | Rename `Libs/` → `libs/`; update TOC paths. |
| PC-13 | §1.4, #25 | MUST | Logo art lives loose in `media/screenshots/`; no typed `media/logos/`. | Move `prettychat.logo.*` → `media/logos/`; update `LOGO_PATH` in `Config.lua`. |
| PC-14 | §4.1, #1 | MUST | `PrettyChatDefaults` / `PrettyChatGlobalStrings` created as raw `_G` globals. | Move both onto `ns` (`ns.Defaults`, `ns.GlobalStrings`); update all readers. |
| PC-15 | §4.5 | MUST | No boot-time validation that every schema `path` resolves against defaults. | Walk schema at load; loud warn on unresolved path; expose count for the test harness. |
| PC-16 | §9.5 | MUST | `ApplyStrings` iterates `pairs(PrettyChatDefaults)` — cross-registered globals apply non-deterministically (last-writer-wins). | Iterate an **ordered** table (`CATEGORY_ORDER` + sorted names) so cross-registered writes are deterministic. |
| PC-17 | §15.2, #26 | MUST | Root `CLAUDE.md` carries the full agent brief instead of being a stub. | Reduce root `CLAUDE.md` to a stub (tier + standard link + pointer to `docs/`); move the brief into `docs/`. |
| PC-18 | §15.3 | MUST | `ARCHITECTURE.md` lives at repo root; no `docs/ARCHITECTURE.md`. | Move/rename to `docs/ARCHITECTURE.md` with the §15.3 section set. |
| PC-19 | §15.1 | MUST | README has no `## Testing` section. | Add `## Testing` (harness `lua tests/run.lua`, `luacheck .`, link `docs/smoke-tests.md`). |
| PC-20 | §15.1, #28 | MUST | README badge row omits the Ka0s Standard link; non-canonical `## Notes` section breaks canonical order. | Add standard badge/link to badge row; fold `## Notes` into Description or an allowed section. |
| PC-21 | §7.4 | SHOULD | Chat tag is a file-local `PREFIX`, not a shared `ns.PREFIX` constant. | Expose `ns.PREFIX` in `Constants.lua`; have `ns.Print` and any module read it. |
| PC-22 | §6.6, §6.8, #31 | SHOULD | Paired action buttons (Test / Reset all) use `SetRelativeWidth(0.5)`, not `BUTTON_PAIR_REL` (0.492). | Add `Const.BUTTON_PAIR_REL = 0.492`; use it for cell-filling paired buttons. |
| PC-23 | §6.6 | SHOULD (partial) | Per-string editor uses a bespoke 40/60 three-row layout, not the schema-driven 50/50 two-column grid. | Justify the domain-specific layout in a code comment, or migrate to the paired 50/50 grid. |
| PC-24 | §3.3 | SHOULD | `AceConfig-3.0` vendored but never loaded/`LibStub`'d (dead weight). | Remove `Libs/AceConfig-3.0/` (no Profiles page uses it). |
| PC-25 | §1.1 | SHOULD (partial) | `GlobalStrings/` is a source subfolder; Tier-1 must stay flat. | Keep as generated-data exception documented in `CLAUDE.md`, or flatten the loader; note the deliberate deviation. |
| PC-26 | §1 | MUST | Tier is not declared in `CLAUDE.md`. | State "Tier 1 (flat)" in the root `CLAUDE.md` stub. |
| PC-27 | §2.1 | SHOULD | `## Title:` uses rainbow colour escapes; `## Author:` casing (`aDd1kTeD2Ka0s`) differs from standard `add1kted2ka0s`. | Plain `Ka0s Pretty Chat` title (or justify); normalise author casing. |
| PC-28 | §4.1, §18 | SHOULD | Namespace upvalue is `ns`; standard convention is `NS`. | Optional rename to `NS` across files for suite consistency. |
| PC-29 | §15.4, #27 | SHOULD | `TODO.md` present in the working tree (git-ignored) on a released addon. | Delete `TODO.md`; migrate its two backlog items to GitHub issues. |
</content>
