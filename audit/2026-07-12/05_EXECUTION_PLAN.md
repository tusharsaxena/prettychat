# 05 — Execution Plan

Ordered, checkable remediation steps for the follow-up engagement. Grouped into sprints; each step tied to its deviation ID(s). The hard invariant: **after every step, `lua tests/run.lua` is green and `luacheck .` is clean** (§14A commit gate). This audit changed no code — everything below is unstarted.

Legend: `[ ]` not started.

---

## Sprint 0 — Toolchain & test gate (unblocks everything)

- [ ] **S0.1** Add `.luacheckrc` (`std=lua51`, exclude `libs/ audit/ tests/`, declare the Blizzard read-globals and `PrettyChatDB` write-global; temporary `PrettyChatDefaults`/`PrettyChatGlobalStrings` globals with justifying comments until S3.1). — **PC-02**
- [ ] **S0.2** Add `.pkgmeta` (`package-as: PrettyChat`, ignore `audit/ docs/ tests/ reviews TODO.md`, **no** `externals:`). — **PC-03**
- [ ] **S0.3** Add `tests/run.lua` + `loader.lua` + `wow_mock.lua`; one trivial green suite. Confirm `lua tests/run.lua` exits 0 and `luacheck .` is clean. — **PC-01**
- [ ] **S0.4** Add suites `test_schema.lua`, `test_render.lua`, `test_apply.lua` capturing **current** behaviour (characterization) so later refactors are safe. — **PC-01**

## Sprint 1 — TOC, casing, media (metadata & filesystem)

- [ ] **S1.1** Rewrite `PrettyChat.toc` metadata block to §2.1 exact order; add `OptionalDeps`, `X-Standard`, `X-Curse-Project-ID: 919766`, `X-Wago-ID`; fix `IconTexture` casing. — **PC-08, PC-09, PC-10**
- [ ] **S1.2** Add `# Libraries (must load first)` + `# Addon` section-header comments to the file listing. — **PC-11**
- [ ] **S1.3** Rename `Libs/` → `libs/` (record the case flip in git); update TOC lib paths + `.luacheckrc` excludes. — **PC-12**
- [ ] **S1.4** Create `media/logos/`, move `prettychat.logo.*` into it, update `LOGO_PATH` (`Config.lua:16-17`) and README image ref. — **PC-13**
- [ ] **S1.5** Delete `Libs/AceConfig-3.0/` (unused). — **PC-24**
- [ ] **S1.6** (Decision) Keep or plain-text the rainbow `## Title:`; normalise `## Author:` casing. — **PC-27**

## Sprint 2 — Missing standard modules

- [ ] **S2.1** Add `Compat.lua`; route both `C_AddOns.GetAddOnMetadata` call sites through `ns.Compat`. Slot into TOC first in `# Addon`. — **PC-04**
- [ ] **S2.2** Add `Locale.lua` (`ns.L` English-key metatable); wrap the ~30 UI strings. Covering test optional (behaviour unchanged). — **PC-05**
- [ ] **S2.3** Add `Database.lua`: `global.schemaVersion = 1` + `ns:RunMigrations()` called after `AceDB:New`. Add `test_database.lua`. — **PC-07**
- [ ] **S2.4** Add `ns.State.debug` (session-only, default off) + `ns.Debug(tag, fmt, ...)` (zero-alloc when off, Tier-1 chat fallback); add `debug on|off|toggle` to `COMMANDS`. — **PC-06**

## Sprint 3 — Namespace & determinism (test-first; broad blast radius)

- [ ] **S3.1** Move `PrettyChatDefaults` → `ns.Defaults` and `PrettyChatGlobalStrings` → `ns.GlobalStrings` (incl. the `split_globalstrings.py` template + regenerated chunks); update all readers; drop the temporary luacheck globals from S0.1. — **PC-14**
- [ ] **S3.2** Rewrite `ApplyStrings` to iterate `CATEGORY_ORDER` + sorted names for deterministic cross-registered apply; extend `test_apply.lua` to assert deterministic winner. — **PC-16**
- [ ] **S3.3** Add load-time schema path-vs-defaults validator with loud warn + exposed counts; assert in `test_schema.lua`. — **PC-15**

## Sprint 4 — Docs & hygiene

- [ ] **S4.1** Shrink root `CLAUDE.md` to a stub declaring **Tier 1 (flat)**, linking the standard, pointing to `docs/`; move the brief into `docs/agent-context.md`. — **PC-17, PC-26**
- [ ] **S4.2** `git mv ARCHITECTURE.md docs/ARCHITECTURE.md`; align to the §15.3 section set. — **PC-18**
- [ ] **S4.3** README: add `## Testing`; add the Ka0s Standard link to the badge row; fold/retitle `## Notes` to restore canonical §15.1 order. — **PC-19, PC-20**
- [ ] **S4.4** Delete `TODO.md`; migrate its two items to GitHub issues. — **PC-29**
- [ ] **S4.5** Record the `GlobalStrings/` generated-data subfolder as a deliberate §1.1 exception in `CLAUDE.md` (or flatten it). — **PC-25**

## Sprint 5 — Panel polish (cosmetic, last)

- [ ] **S5.1** Add `ns.PREFIX` constant; have `ns.Print` read it. — **PC-21**
- [ ] **S5.2** Add `Const.BUTTON_PAIR_REL = 0.492`; apply to the Test / Reset-all pair. — **PC-22**
- [ ] **S5.3** Justify (comment) or refactor the per-string 40/60 layout toward the 50/50 grid. — **PC-23**
- [ ] **S5.4** (Optional) `ns` → `NS` rename for suite consistency. — **PC-28**

---

## Definition of done

- Every `PC-*` in `02_DEVIATIONS.md` is either fixed or carries a **documented, code-commented** deviation justification (SHOULD rows only).
- `lua tests/run.lua` green and `luacheck .` clean on the final commit of every sprint.
- A re-audit drops a **new** `audit/<date>/` folder (never edits this one) and reuses the `PC-` IDs for anything still open.
</content>
