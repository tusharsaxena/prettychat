# 04 — Technical Design (Remediation)

How to close each gap in `02_DEVIATIONS.md`. Read-only audit — nothing here is applied; this is the design the follow-up remediation engagement executes. Grouped by theme; each block names the files to touch, the shape of the change, and risks/ordering.

---

## A. Toolchain & test infrastructure — PC-01, PC-02, PC-03

The addon has **no local build/verify loop**, which blocks the §14A commit gate that every later change depends on. Do this first.

- **`.luacheckrc`** (PC-02): `std = "lua51"`, `max_line_length = false`, `codes = true`, `exclude_files = { "libs/", "audit/", "tests/" }`, `ignore = {"212/self","212/event"}`, `read_globals` incl. the Blizzard surface the addon uses (`Settings`, `C_AddOns`, `C_Timer`, `CreateFrame`, `StaticPopupDialogs`, `StaticPopup_Show`, `DEFAULT_CHAT_FRAME`, `GameTooltip`, `SettingsPanel`, `InCombatLockdown`, `YES`, `NO`, `unpack`, atlas/font globals), `globals = { "PrettyChatDB" }` plus — until PC-14 lands — `"PrettyChatDefaults"`, `"PrettyChatGlobalStrings"` (each with a justifying comment).
- **`.pkgmeta`** (PC-03): `package-as: PrettyChat`; `ignore:` `audit/ docs/ tests/ .luacheckrc .gitignore reviews "*.bak" TODO.md`; **no `externals:`** (libs stay vendored).
- **`tests/`** (PC-01): the §14A.1 harness — `run.lua` (micro-framework + TOC-order source loader + `os.exit` non-zero on fail), `loader.lua` (`loadfile` + `setfenv` to a mock env, calls `chunk(addonName, NS)`), `wow_mock.lua` (self-returning no-op frame, `CreateFrame`, `Settings.*`, `LibStub` with AceDB/AceAddon/AceConsole/AceGUI fakes, `C_AddOns`, `_G[GLOBALNAME]` string table). Suites: `test_schema.lua` (path resolution, `Get/Set`, single-write-path side effects), `test_render.lua` (`ns.RenderSample` positional/`%%`/error cases), `test_apply.lua` (master→category→string enable cascade + deterministic cross-registered apply for PC-16), `test_database.lua` (migration runner for PC-07).
- **Risk:** the mock must model real behaviour where it matters (e.g. `_G` string overrides, AceDB profile merge). Keep frame mocks no-op but make the DB + global-string table real tables so apply/schema logic is genuinely exercised.

## B. TOC normalisation — PC-08, PC-09, PC-10, PC-11, PC-27

Single-file edit to `PrettyChat.toc`. Rewrite the metadata block to the §2.1 exact order:

```
## Interface: 120007
## Title: Ka0s Pretty Chat
## Notes: Prettier chat messages
## Author: add1kted2ka0s
## Version: 1.3.0
## IconTexture: 2056011
## SavedVariables: PrettyChatDB
## OptionalDeps: Ace3, LibStub, CallbackHandler-1.0
## DefaultState: enabled
## Category-enUS: Chat & Communication
## X-License: MIT
## X-Standard: https://github.com/tusharsaxena/WowAddonStandards
## X-Curse-Project-ID: 919766
## X-Wago-ID: <lookup>
```

Then one blank line and the file listing under Tier-1 `# Libraries (must load first)` + `# Addon` section comments (PC-11), libs paths updated to lowercase `libs\…` once PC-12 lands. Keep the trailing newline. PC-27 (rainbow Title / author casing) is folded here — decide whether to keep the coloured title as a deliberate brand deviation (document it) or plain-text it. **Risk:** `## X-Wago-ID` needs the real Wago id; leave a placeholder task if unknown rather than a wrong value.

## C. Filesystem casing & media typing — PC-12, PC-13

- **PC-12:** `git mv Libs libs` (WSL/Windows is case-insensitive — do a two-step rename `Libs → libs_tmp → libs` if git won't record the case flip), update `PrettyChat.toc` lib paths, and `.luacheckrc` `exclude_files`.
- **PC-13:** create `media/logos/`, `git mv` the three `prettychat.logo.*` files into it, update `LOGO_PATH` (`Config.lua:16-17`) and any README image ref. Keep runtime `.tga` + source `.jpg/.png` side by side (§6.5).
- **Ordering:** do B and C together (both touch TOC paths) so the TOC is rewritten once.

## D. Namespace & determinism — PC-14, PC-16, PC-15

These share the apply/data path and should land as one reviewed change.

- **PC-14:** replace the `PrettyChatDefaults` global with `ns.Defaults` (set in `Defaults.lua`), and `PrettyChatGlobalStrings` with `ns.GlobalStrings` (chunks append to `ns.GlobalStrings`). Update readers in `PrettyChat.lua` (`:39,106,142,298,540`), `Schema.lua` (`:68,105,120,418`), `Config.lua` (`:416,631`). The GlobalStrings chunk header changes from `PrettyChatGlobalStrings = PrettyChatGlobalStrings or {}` to `local _, ns = ...; ns.GlobalStrings = ns.GlobalStrings or {}` — regenerate via `GlobalStrings/split_globalstrings.py` so the template, not just the output, changes.
- **PC-16:** rewrite `ApplyStrings` (`PrettyChat.lua:138-153`) to iterate `ns.Schema.CATEGORY_ORDER` and, within each category, a **sorted** name list — so cross-registered globals (`LOOT_ITEM_CREATED_SELF`) resolve deterministically (documented last-writer). Cover with `test_apply.lua`.
- **PC-15:** add a load-time validator in `Schema.lua` that resolves every `row.path`'s backing default and prints a loud `ns.Print` warning per miss; stash the checked/failed counts on `Schema` for `test_schema.lua` to assert.
- **Risk:** PC-14 is broad (touches generated chunks). Do it test-first (harness from block A must be green first) so the `_G`→`ns` move can't silently break the override path.

## E. Missing standard modules — PC-04, PC-05, PC-06, PC-07

New flat files (Tier-1), added to the TOC `# Addon` section in dependency order (`Compat` → `Locale` → `Constants` → `Defaults` → `Database` → `PrettyChat` → `Schema` → `Config`).

- **PC-04 `Compat.lua`:** `ns.Compat` wrapping `GetAddOnMetadata` (C_AddOns vs legacy). Replace the two inline `C_AddOns.GetAddOnMetadata` call sites.
- **PC-05 `Locale.lua`:** `ns.L = setmetatable({}, {__index=function(_,k) return k end})`; seed enUS keys for the ~30 UI strings; wrap call sites in `Config.lua` / `PrettyChat.lua`. English-key scheme (§8.2) means missing keys fall back to English — zero behaviour change.
- **PC-06 `ns.Debug`:** session-only `ns.State.debug` (default off, never in SV); `ns.Debug(tag, fmt, ...)` gated on the first line (zero-alloc off). Tier-1 no-window fallback (§12.7): route to `ns.Print` with the tag. Add a `debug on|off|toggle` verb to `COMMANDS`.
- **PC-07 `Database.lua`:** `ns.defaults.global.schemaVersion = 1`; `ns:RunMigrations()` called after `AceDB:New` in `OnInitialize`; empty-but-present body per §5.1.

## F. Docs & packaging hygiene — PC-17, PC-18, PC-19, PC-20, PC-26, PC-29, PC-24, PC-25

- **PC-17 + PC-26:** shrink root `CLAUDE.md` to a stub (declares **Tier 1 (flat)**, links the standard, points to `docs/`); move the current brief body into `docs/` (e.g. `docs/agent-context.md`).
- **PC-18:** `git mv ARCHITECTURE.md docs/ARCHITECTURE.md`; ensure the §15.3 section set (Overview, Module Map, Settings Schema, Slash Commands, Event Subscriptions, Taint Notes, Known Limitations). Message-bus section N/A (no bus).
- **PC-19 + PC-20:** add `## Testing` to README; add the standards link to the badge row; fold `## Notes` into Description (or retitle to an allowed §15.1 section) to restore canonical order.
- **PC-24:** delete `Libs/AceConfig-3.0/` (no Profiles page consumes it).
- **PC-25:** either flatten `GlobalStrings/` into root-level generated files, or (preferred, lower-churn) keep the subfolder and record it in `CLAUDE.md` as a **deliberate generated-data exception** to §1.1.
- **PC-29:** delete `TODO.md`; migrate its two backlog items ("Update defaults", "Custom replacements section") to GitHub issues.

## G. Panel polish — PC-21, PC-22, PC-23, PC-28

Low-risk, cosmetic-tier.

- **PC-21:** `Const.PREFIX` / `ns.PREFIX` in `Constants.lua`; `ns.Print` reads it.
- **PC-22:** `Const.BUTTON_PAIR_REL = 0.492`; apply to the Test / Reset-all pair (`Config.lua:326,334`) and any future cell-filling paired button.
- **PC-23:** either add a code comment justifying the 40/60 domain layout as a deliberate §6.6 deviation, or refactor to the paired 50/50 grid. Justification is the pragmatic call — the three-row original/new/preview shape is domain-driven.
- **PC-28:** optional `ns`→`NS` rename for suite consistency; cosmetic, do last or skip.

---

## Ordering constraints (summary)

1. **A (toolchain/tests)** first — establishes the green commit gate every later change must pass.
2. **B+C (TOC + casing/media)** together — both rewrite TOC paths.
3. **E (new modules)** — Compat/Locale/Database/Debug slot into the TOC from B.
4. **D (namespace + determinism)** — test-first against harness from A; broadest blast radius.
5. **F (docs/hygiene)** — independent, can interleave.
6. **G (panel polish)** — last, cosmetic.

Each landed change must leave `lua tests/run.lua` green and `luacheck .` clean (§14A commit gate).
</content>
