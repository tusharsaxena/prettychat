# 03 — Evidence

`file:line` citations backing every deviation in `02_DEVIATIONS.md`. Line numbers are as of the audited working tree (2026-07-12). Compliance evidence is noted at the end.

## Deviation evidence

### PC-01 — no tests (§14A)
- Repo has no `tests/` directory (working-tree listing). No `run.lua` / `loader.lua` / `wow_mock.lua` / `test_*.lua` present.

### PC-02 — no `.luacheckrc` (§14)
- No `.luacheckrc` at repo root (working-tree listing).

### PC-03 — no `.pkgmeta` (§13)
- No `.pkgmeta` at repo root (working-tree listing).

### PC-04 — no `Compat.lua` (§11)
- No `Compat.lua` in repo. Deprecated/versioned API called directly: `PrettyChat.lua:7-8` `C_AddOns.GetAddOnMetadata(addonName, "Version")`; `Config.lua:13-14` `C_AddOns.GetAddOnMetadata(addonName, "Notes")`.

### PC-05 — no locale module (§8)
- No `Locale.lua` / `locales/`. Hardcoded English UI strings, e.g. `Config.lua:301` (`"Addon-wide controls…"`), `Config.lua:309` (`"Enable PrettyChat"`), `Config.lua:333` (`"Reset all to defaults"`), `Config.lua:280-281` popup text; slash strings throughout `PrettyChat.lua` (e.g. `:456`, `:500`).

### PC-06 — no debug seam (§12)
- No `ns.Debug`, no `ns.State.debug`, no console anywhere in source. `ns.Print` (`PrettyChat.lua:13-15`) is the only chat seam and is user-facing, not a gated debug sink.

### PC-07 — no `schemaVersion` / migration runner (§2.2, §5.1)
- Defaults table `PrettyChat.lua:17-28` — `profile.categories = {}` only; no `global.schemaVersion`. AceDB init `PrettyChat.lua:31`. No `Database.lua` in repo. Grep for `schemaVersion` across `*.lua`: no matches.

### PC-08 — TOC field order / casing / OptionalDeps (§2.1)
- `PrettyChat.toc:1-10`: order is Interface, Title, Version, Author, Notes, iconTexture, SavedVariables, DefaultState, Category-enUS, X-License. §2.1 requires Notes before Author, Version after Author, and `## IconTexture` (capitalised) — see `PrettyChat.toc:6` `## iconTexture:`. No `## OptionalDeps:` line present.

### PC-09 — TOC missing `X-Standard` (§2.1)
- `PrettyChat.toc:1-10`: no `## X-Standard:` line (grep count 0).

### PC-10 — TOC missing publish IDs (§2.1)
- Addon is published: `README.md:4` `![CurseForge Version](…/curseforge/v/919766)`. `PrettyChat.toc` has no `## X-Curse-Project-ID:` / `## X-Wago-ID:` (lines 1-10).

### PC-11 — TOC file listing lacks section headers (§2.5)
- `PrettyChat.toc:11-34`: file listing has no `#` comment section headers (no `# Libraries`, no `# Addon`).

### PC-12 — `Libs/` wrong case (§1.3)
- `git ls-files` shows library files under `Libs/…` (e.g. `Libs/AceAddon-3.0/…`); TOC references `Libs\…` (`PrettyChat.toc:12-17`). §1.3 requires lowercase `libs/`.

### PC-13 — logo not under `media/logos/` (§1.4)
- Logo assets loose in `media/screenshots/`: `media/screenshots/prettychat.logo.png`, `prettychat.logo.v2.jpg`, `prettychat.logo.v2.tga`. No `media/logos/` folder. Runtime path in `Config.lua:16-17` points at `media\screenshots\prettychat.logo.v2.tga`.

### PC-14 — global namespace tables (§4.1, #1)
- `Defaults.lua:1` `PrettyChatDefaults = {` (raw global). `GlobalStrings/GlobalStrings_001.lua:1` `PrettyChatGlobalStrings = PrettyChatGlobalStrings or {}` (raw global, repeated in all 10 chunks). Read by name globally, e.g. `PrettyChat.lua:39,106,142`; `Schema.lua:120`; `Config.lua:416,631`.

### PC-15 — no boot schema validation (§4.5)
- `Schema.lua:114-158` builds rows and derives `crossRegisteredGlobals` but performs no path-vs-defaults resolution check / loud warning at load; no validation count exposed.

### PC-16 — non-deterministic cross-registered apply (§9.5)
- `PrettyChat.lua:142-152` `ApplyStrings` iterates `for category, catData in pairs(PrettyChatDefaults)` and writes `_G[globalName]`. The conflict is acknowledged but unresolved: `Schema.lua:136-158` comment — "the last category to iterate wins on /reload, and pairs() order is non-deterministic."

### PC-17 — root `CLAUDE.md` is full brief, not stub (§15.2, #26)
- `CLAUDE.md` (root) carries "Hard rules", "Namespace publishing pattern", "Working environment", "Doc index" — the full agent brief, not the §15.2 stub (tier + standard link + pointer to `docs/`).

### PC-18 — `ARCHITECTURE.md` at root (§15.3)
- `ARCHITECTURE.md` exists at repo root; no `docs/ARCHITECTURE.md` (working-tree listing of `docs/` shows only topic files: `common-tasks.md`, `file-index.md`, `global-strings.md`, `module-map.md`, `override-pipeline.md`, `schema.md`, `scope.md`, `settings-panel.md`, `smoke-tests.md`).

### PC-19 — README missing `## Testing` (§15.1)
- `README.md` headings: `# Ka0s Pretty Chat`, `## Screenshots`, `## Usage`, `## Notes`, `## FAQ`, `## Troubleshooting`, `## Issues and feature requests`, `## Version History` — no `## Testing`.

### PC-20 — README badge/order (§15.1, #28)
- `README.md:3-5` badge row: wow, CurseForge, license — **no** Ka0s Standard badge/link (grep for `WowAddonStandards` in README: 0 matches). `README.md:58` `## Notes` is a non-canonical section between Usage and FAQ.

### PC-21 — `PREFIX` not shared constant (§7.4)
- `PrettyChat.lua:6` `local PREFIX = Color.cyan .. "[PC]" .. Color.reset .. " "` — file-local, not `ns.PREFIX`. Consumed only via `ns.Print` (`PrettyChat.lua:13-15`) and `Test` (`PrettyChat.lua:261+`).

### PC-22 — paired buttons at 0.5 (§6.6/§6.8, #31)
- `Config.lua:326` `testBtn:SetRelativeWidth(0.5)`; `Config.lua:334` `resetAllBtn:SetRelativeWidth(0.5)`. No `BUTTON_PAIR_REL` constant in `Constants.lua`.

### PC-23 — bespoke per-string layout (§6.6)
- `Config.lua:363-364` `local LEFT_W = 0.4 / RIGHT_W = 0.6`; three `Flow` rows per string (`Config.lua:380-467`) instead of the paired 50/50 grid.

### PC-24 — AceConfig vendored unused (§3.3)
- `Libs/AceConfig-3.0/` present (dir listing) but not loaded in `PrettyChat.toc:12-17` and never `LibStub("AceConfig…")` (grep: no match in `*.lua`).

### PC-25 — `GlobalStrings/` source subfolder (§1.1)
- TOC loads source from a subfolder: `PrettyChat.toc:19-28` `GlobalStrings\GlobalStrings_00X.lua`. §1.1 "MUST NOT introduce subfolders for source" (borderline — generated data).

### PC-26 — tier not declared (§1)
- `CLAUDE.md` contains no tier declaration ("Tier 1"/"Tier 2").

### PC-27 — Title/Author styling (§2.1)
- `PrettyChat.toc:2` `## Title: Ka0s |cffff0000P|cffff9900r…|r` (rainbow escapes). `PrettyChat.toc:4` `## Author: aDd1kTeD2Ka0s` vs standard `add1kted2ka0s`.

### PC-28 — `ns` vs `NS` (§4.1, §18)
- `local addonName, ns = ...` header in every file (e.g. `PrettyChat.lua:1`, `Schema.lua:1`, `Config.lua:1`, `Constants.lua:1`). §18 cheatsheet: namespace upvalue `NS`.

### PC-29 — `TODO.md` present (§15.4)
- `TODO.md` exists in the working tree (content: "Done"/"Backlog" items). Git-ignored via `.gitignore` (`TODO.md`), so untracked — not shipped — but still present on a released addon.

## Compliance evidence (rules the addon meets — cited so claims aren't unsourced)

- **§4.5 single write path** — `Schema.lua:200-207` `Schema.Set` = validate/write via `row.set` → `ApplyStrings()` → `NotifyPanelChange()`; both panel (`Config.lua:312-314,388-390,437-439,507-509`) and slash (`PrettyChat.lua:514`) call it.
- **§6.1 non-deprecated registration** — `Config.lua:609,646` `Settings.RegisterCanvasLayoutCategory` / `RegisterCanvasLayoutSubcategory`; no `InterfaceOptions_AddCategory`.
- **§6.1 lazy body / eager category** — bodies built in `OnShow` (`Config.lua:603-607,625-642`); category registered eagerly in `OnEnable` (`PrettyChat.lua:50-52`).
- **§6.2 combat guard** — `PrettyChat.lua:84-87` `InCombatLockdown()` early-return in `OpenConfig`.
- **§6.10 always-visible scrollbar** — `Config.lua:68-166` `patchAlwaysShowScrollbar`.
- **§7.1/§7.3 slash** — AceConsole `RegisterChatCommand("pc"/"prettychat")` (`PrettyChat.lua:33-34`); ordered `COMMANDS` table + generated help (`PrettyChat.lua:362-393`); unknown-verb → help (`PrettyChat.lua:612-613`); no if/elseif chain.
- **§9.5 chat via global-string override** — `ApplyStrings` writes `_G[globalName]` (`PrettyChat.lua:138-153`); no `AddMessage` replacement, no chat-event filter.
- **§2.3 single Interface** — `PrettyChat.toc:1` `## Interface: 120007`; README `[wow]` badge `README.md:3` in lockstep.
- **§3.3 vendored, no externals** — libs committed under `Libs/`; no `.pkgmeta externals:` (no `.pkgmeta` at all — see PC-03).
- **License MIT** — `PrettyChat.toc:10` `## X-License: MIT`; `LICENSE` is MIT (not the forbidden All-Rights-Reserved).
</content>
