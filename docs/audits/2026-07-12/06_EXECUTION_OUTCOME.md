# 06 — Execution Outcome

Outcome of executing the remediation designed in [04_TECHNICAL_DESIGN.md](./04_TECHNICAL_DESIGN.md) and ordered in [05_EXECUTION_PLAN.md](./05_EXECUTION_PLAN.md). Unlike 01–05 (a read-only audit), **this engagement changed code.** All edits are left **unstaged on `master`** — no commits, no pushes (per the project's hard rules).

**Standard:** Ka0s WoW Addon Standard v1.0.0 (2026-07-12).
**Final gate:** `lua tests/run.lua` → **44 passed, 0 failed** · `luacheck .` → **0 warnings / 0 errors in 8 files**.

---

## 1. Result at a glance

All **29** deviations are resolved: **26 fixed**, **2 documented deliberate deviations** (PC-25, PC-27), **1 optional intentionally skipped** (PC-28). An 8-agent adversarial verification workflow independently confirmed the fixes against the real working tree (see §4).

| Sprint | PC-IDs | Status |
|--------|--------|--------|
| S0 — Toolchain & test gate | PC-01, PC-02, PC-03 | ✅ fixed |
| S1 — TOC, casing, media | PC-08, PC-09, PC-10, PC-11, PC-12, PC-13, PC-24, PC-27 | ✅ fixed (PC-27 = documented deviation) |
| S2 — Missing standard modules | PC-04, PC-05, PC-06, PC-07 | ✅ fixed |
| S3 — Namespace & determinism | PC-14, PC-15, PC-16 | ✅ fixed |
| S4 — Docs & hygiene | PC-17, PC-18, PC-19, PC-20, PC-25, PC-26, PC-29 | ✅ fixed (PC-25 = documented exception) |
| S5 — Panel polish | PC-21, PC-22, PC-23, PC-28 | ✅ fixed (PC-23 = justified; PC-28 skipped) |

### Per-deviation detail

| ID | Sev | What was done |
|----|-----|---------------|
| PC-01 | MUST | Added `tests/` headless harness: `run.lua` (micro-framework + non-zero exit), `loader.lua` (TOC-order source loader via `loadfile`+`setfenv`), `wow_mock.lua` (mock WoW env), and suites `test_schema` / `test_render` / `test_apply` / `test_database`. |
| PC-02 | MUST | Added `.luacheckrc` (`std=lua51`; excludes `libs/ GlobalStrings/ audit/ tests/ reviews`; declares `PrettyChatDB` + `StaticPopupDialogs`). |
| PC-03 | MUST | Added `.pkgmeta` (`package-as: PrettyChat`; ignores `audit/ docs/ tests/ reviews …`; **no** `externals`). |
| PC-04 | MUST | `Compat.lua` → `ns.Compat.GetAddOnMetadata` (C_AddOns vs legacy). Both call sites (`PrettyChat.lua`, `Config.lua`) routed through it. |
| PC-05 | MUST | `Locale.lua` → `ns.L` English-key metatable + enUS manifest (33 strings). Wrapped Config.lua UI strings and PrettyChat.lua `COMMANDS` descriptions in `L[…]`. |
| PC-06 | MUST | `ns.State.debug` (session-only) + `ns.Debug(tag, fmt, …)` (zero-alloc when off, `ns.Print` fallback). Added `/pc debug [on\|off\|toggle]`. |
| PC-07 | MUST | `Database.lua` → `SCHEMA_VERSION=1`, `global.schemaVersion` default, `RunMigrations(db)` called right after `AceDB:New` in `OnInitialize`. |
| PC-08 | MUST | `PrettyChat.toc` reordered to the §2.1 canonical block; `IconTexture` cased; `OptionalDeps: Ace3, LibStub, CallbackHandler-1.0` added. |
| PC-09 | MUST | `## X-Standard:` added. |
| PC-10 | MUST | `## X-Curse-Project-ID: 919766` added. `## X-Wago-ID` **intentionally omitted** (no real id yet — see §5). |
| PC-11 | MUST | `# Libraries (must load first)` + `# Addon` section comments added to the file listing. |
| PC-12 | MUST | `Libs/` → `libs/` on disk; TOC lib paths lowercased; `.luacheckrc` updated. **Git note in §5.** |
| PC-13 | MUST | `media/logos/` created; `prettychat.logo.*` moved in; `LOGO_PATH` (`Config.lua`) updated. |
| PC-14 | MUST | `PrettyChatDefaults` → `ns.Defaults`, `PrettyChatGlobalStrings` → `ns.GlobalStrings`. All readers updated; the `split_globalstrings.py` template changed and the 10 chunks regenerated (`local _, ns = ...`). Zero raw `_G` globals remain. |
| PC-15 | MUST | Load-time validator in `Schema.lua`: resolves every row path against `ns.Defaults`, loud `ns.Print` warn on a miss, counts stashed on `Schema.validation`. |
| PC-16 | MUST | `ApplyStrings` rewritten to iterate `CATEGORY_ORDER` + sorted names → deterministic cross-registered apply (documented last-writer). |
| PC-17 | MUST | Root `CLAUDE.md` shrunk to a stub; brief moved to `docs/agent-context.md`. |
| PC-18 | MUST | `ARCHITECTURE.md` → `docs/ARCHITECTURE.md`, rewritten to the §15.3 section set (Overview, Module Map, Settings Schema, Slash Commands, Event Subscriptions, Taint Notes, Known Limitations). |
| PC-19 | MUST | README `## Testing` section added. |
| PC-20 | MUST | README badge row gained a Ka0s Standard badge/link; non-canonical `## Notes` folded into `### Behavior` under Usage. |
| PC-21 | SHOULD | `ns.PREFIX` / `Const.PREFIX` in `Constants.lua`; `ns.Print` reads it. |
| PC-22 | SHOULD | `Const.BUTTON_PAIR_REL = 0.492` applied to the Test / Reset-all pair. |
| PC-23 | SHOULD | 40/60 per-string layout justified with an in-code §6.6 deviation comment. |
| PC-24 | SHOULD | `libs/AceConfig-3.0/` deleted (no live consumer). |
| PC-25 | SHOULD | `GlobalStrings/` recorded in `CLAUDE.md` as a deliberate §1.1 generated-data exception. |
| PC-26 | MUST | `CLAUDE.md` stub declares **Tier 1 (flat)** + links the standard. |
| PC-27 | SHOULD | Rainbow `## Title:` + `aDd1kTeD2Ka0s` author casing **kept** (your decision) and documented as a deliberate §2.1 brand deviation in `CLAUDE.md`. |
| PC-28 | SHOULD | `ns`→`NS` rename **intentionally skipped** (optional/cosmetic per design). |
| PC-29 | SHOULD | `TODO.md` deleted; two backlog items migrated to GitHub issues **#1** (Update default format strings) and **#2** (Custom replacements section). |

---

## 2. Decisions you made up front (applied)

- **Work location:** directly on `master`, all edits **unstaged**.
- **PC-27:** keep the rainbow title + brand author casing (now documented as a deliberate deviation).
- **PC-10:** omit `## X-Wago-ID` — flagged as open below.
- **PC-29:** create real GitHub issues (#1, #2 on `tusharsaxena/prettychat`), then delete `TODO.md`.

---

## 3. Test harness

The addon previously had **no automated tests**. It now has a headless harness under `tests/` that runs under **stock Lua 5.1** with no WoW client — it loads the addon's own `.lua` sources into a mock WoW environment and exercises the real schema / render / apply / migration logic.

### Files

| File | Role |
|------|------|
| `tests/run.lua` | Entry point + micro test framework (`t.eq/neq/truthy/falsy/nilv`). Resolves the repo root from `arg[0]`, runs each suite in `pcall`, prints `N passed, M failed`, and **exits non-zero on any failure** (so it gates commits). |
| `tests/loader.lua` | Loads sources in `PrettyChat.toc` order (`Compat → Locale → Constants → Defaults → Database → PrettyChat → Schema → Config`) via `loadfile` + `setfenv` to the mock env, calling each chunk as `chunk(addonName, ns)`. Runs the AceAddon lifecycle (`OnInitialize` → seed pristine `_G` originals → `OnEnable`) and returns `{ env, ns, addon }`. Each call is a fresh, isolated instance. |
| `tests/wow_mock.lua` | Builds the mock `_G`: standard Lua library passthrough, `_G = env` (so `_G[GLOBALNAME]` writes are observable), Blizzard stubs (`CreateFrame`, `Settings`, `C_AddOns`, `DEFAULT_CHAT_FRAME`, …), and **real** LibStub/Ace fakes — AceDB deep-copies defaults into real `profile`/`global` tables so schema + apply logic is genuinely exercised, not stubbed. |
| `tests/test_schema.lua` | Path resolution, category resolution, `Get`/`Set` round-trips, the **single write path** side effect (a `Set` pushes the override into `_G`), auto-clear on default match, and the PC-15 load-time validator (`Schema.validation.failed == 0`). |
| `tests/test_render.lua` | `ns.RenderSample`: `%s`/`%d`, `%%` escapes, graceful nil-on-error (`%y`), empty/nil input, and a real Loot default rendering. (Positional `%n$s` is a WoW `string.format` extension → asserted to degrade gracefully under stock Lua, not to render.) |
| `tests/test_apply.lua` | The master → category → per-string enable cascade (each layer off restores the Blizzard original), and PC-16 determinism (a cross-registered global resolves to the last `CATEGORY_ORDER` registrant, stable across repeated applies). |
| `tests/test_database.lua` | PC-07: fresh DB stamped at `SCHEMA_VERSION`, idempotent re-run, tolerates a `db` with no `global`, and upgrades an older DB. |

### How to run

```sh
# from the repo root
lua tests/run.lua     # exits 0 on success, non-zero on any failed assertion
luacheck .            # static analysis (config in .luacheckrc)
```

Both are the **§14A commit gate** — run them before every commit. Requires `lua5.1` and `luacheck` on PATH (both already present in this environment).

### What the harness deliberately does NOT cover

The mock frames are inert no-ops, so **nothing renders the Blizzard Settings panel or AceGUI widgets**. Anything visual, taint-sensitive, or dependent on WoW's extended `string.format` (positional specifiers) must be validated **in-game** — see the smoke tests below.

---

## 4. Independent verification (multi-agent workflow)

After the build, an 8-agent adversarial workflow (`verify-standards-remediation`) re-checked every PC-ID against the real tree (6 per-group verifiers + a regression hunter + a completeness critic), running `lua tests/run.lua` / `luacheck .` themselves.

- **27/29 confirmed fixed** with `file:line` evidence on first pass.
- **Regression hunter:** **no** runtime-breaking issues (load order, missed readers, cascade behaviour, chunk template under both TOCs all clean).
- **Findings then remediated in this session:**
  - PC-27 keep was undocumented → added the deliberate-deviation note to `CLAUDE.md`.
  - `docs/module-map.md` + `docs/file-index.md` still listed the pre-remediation module set / load order → updated (new modules, corrected order, namespace table).
  - PC-05 was partial (PrettyChat.lua strings unwrapped) → wrapped the `COMMANDS` help descriptions + extended the Locale manifest.

Re-ran the gate after each fix: still 44 passed / luacheck clean.

---

## 5. Open items & follow-ups (need your action)

1. **Git case-flip for `libs/` (PC-12).** The rename is correct **on disk** (`libs/` lowercase) and in the TOC, but because `core.ignorecase=true` on this `/mnt/d` filesystem and edits were left unstaged, **git still tracks `Libs/`**. To record the case flip in history at commit time, run:
   ```sh
   git mv -f Libs libs
   ```
   (or `git config core.ignorecase false` then re-add). Until then, a packager cloning from git would still see `Libs/`.
2. **`## X-Wago-ID` (PC-10).** Intentionally omitted — add `## X-Wago-ID: <id>` to `PrettyChat.toc` once you have the real Wago project id.
3. **PC-05 residual (minor).** The most static PrettyChat.lua strings are wrapped; a few highly-interpolated slash/usage/`Test` strings remain plain English. Behaviourally identical (English-key fallback); wrap opportunistically if you want 100% coverage.
4. **Commit.** Everything is unstaged on `master`. Review `git status` / `git diff`, then commit when ready (the `libs/` case flip above is the only step git can't already see).

---

## 6. Working-tree state

Unstaged on `master` — nothing committed or pushed.

- **New files:** `.luacheckrc`, `.pkgmeta`, `Compat.lua`, `Locale.lua`, `Database.lua`, `tests/` (7 files), `docs/ARCHITECTURE.md`, `docs/agent-context.md`, `media/logos/` (3 logos).
- **Deleted:** `ARCHITECTURE.md` (moved), `Libs/AceConfig-3.0/`, `media/screenshots/prettychat.logo.*` (moved), `TODO.md`.
- **Modified:** `PrettyChat.toc`, `PrettyChat.lua`, `Schema.lua`, `Config.lua`, `Constants.lua`, `Defaults.lua`, `CLAUDE.md`, `README.md`, `GlobalStrings/*` (template + 10 chunks + README + toc), and topic docs under `docs/`.
- **Not visible to git** (ignorecase): the `Libs/`→`libs/` case flip — see §5.1.

---

## 7. Manual smoke tests (run in-game)

Install the working tree into `Interface/AddOns/PrettyChat`, launch WoW (Retail / Midnight `120007`), and walk these. Each names the invariant it guards. The full reference suite is [docs/smoke-tests.md](../../smoke-tests.md).

### A. Boot & load order (PC-08/11/12/14/04/05/06/07)
1. `/reload`. **Expect:** no Lua errors on load (esp. none about `ns.Compat`, `ns.L`, `ns.Defaults`, `ns.Database`, or a `nil` global). A clean boot proves the new modules load in the right TOC order.
2. `/pc` → the help list prints with the cyan `[PC]` prefix and shows the new **`/pc debug`** verb. **Guards:** `ns.PREFIX` (PC-21), `COMMANDS` incl. debug (PC-06), `ns.L`-wrapped descriptions (PC-05).

### B. Override pipeline & master toggle (PC-16, cascade)
3. Loot an item (or trigger any loot line). **Expect:** the reformatted `Loot | … | You | + item` layout.
4. `/pc set General.enabled false` → loot again. **Expect:** Blizzard's **original** line. Re-enable: `/pc set General.enabled true` → reformatted again. **Guards:** master toggle wins; `ApplyStrings` restore path.
5. `/pc set Loot.enabled false` → loot → original; re-enable. Then `/pc set Loot.LOOT_ITEM_SELF.enabled false` → that one string reverts while others stay formatted. **Guards:** 3-layer cascade.

### C. Cross-registered determinism (PC-16)
6. `/reload` several times, each time checking a crafted-item-created line (`LOOT_ITEM_CREATED_SELF`, shared by Loot + Tradeskill). **Expect:** the **same** formatting every reload (Tradeskill's, the later `CATEGORY_ORDER` entry) — never flip-flopping. Hover the per-string Enable checkbox on both pages → tooltip warns about the shared global.

### D. Settings panel (PC-13/22/23, single write path)
7. `/pc config` (out of combat). **Expect:** the panel opens under **Ka0s Pretty Chat**; the parent page shows the **logo** (proves `media/logos/` + `LOGO_PATH`), tagline, and slash list.
8. On **General**: the **Test** and **Reset all to defaults** buttons sit side-by-side, evenly filling the row (PC-22). Click **Test** → a per-category Original-vs-Formatted sample dump.
9. On any category page: a per-string row shows Enable / GLOBALNAME / Reset on the left, Original / New / Preview on the right (40/60, PC-23). Edit a **New** format, press Enter → **Preview** updates. Run `/pc get <Category>.<GLOBALNAME>.format` → matches. **Guards:** single write path (panel ↔ slash).
10. In combat (or `/run InCombatLockdown` context), `/pc config` should **refuse** with a grey notice — never taint the panel.

### E. Slash CLI & new verbs (PC-05/06)
11. `/pc debug on` → "debug logging enabled"; `/pc debug` toggles; `/pc debug off`. **Guards:** PC-06 seam + `/pc debug`.
12. `/pc list Loot`, `/pc get Loot.LOOT_ITEM_SELF.enabled`, `/pc set Loot.enabled true`, `/pc reset Loot`, `/pc test category Loot`. **Expect:** all behave as before the remediation (no regression).

### F. Original-format display & GlobalStrings (PC-14)
13. On a category page, the **Original** box shows Blizzard's real default for each string. **Guards:** `ns.GlobalStrings` (the renamed table) still populates and resolves — proves the regenerated chunks + `local _, ns = ...` template load under the main TOC.

### G. Positional formats (harness gap → verify here)
14. `/pc test` on a category whose strings use positional `%n$s` (non-enUS-style). **Expect:** they render correctly in-game (WoW's extended `string.format`), even though the headless harness can't. If any errors, its `%`-signature drifted from Blizzard's.

### H. Persistence & migrations (PC-07)
15. Change a few settings, `/reload`, confirm they persist. Then inspect `PrettyChatDB` in SavedVariables → a `global.schemaVersion = 1` entry is present. **Guards:** `Database.RunMigrations` stamping.

> If any test fails, map it to the invariant above and to [docs/ARCHITECTURE.md](../../ARCHITECTURE.md) (Settings Schema / Taint Notes / Known Limitations), then re-run `lua tests/run.lua` to see whether the headless suite catches it.
