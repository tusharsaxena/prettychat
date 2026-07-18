# 01 — Current State

**Addon:** Ka0s Pretty Chat (`PrettyChat`)
**Audit date:** 2026-07-18
**Audited against:** Ka0s WoW Addon Standard **v2.7.0 (2026-07-17)** — `standards/STANDARDS.md` plus every linked section file under `standards/standards/` and the `anti-patterns` list, fetched live from `https://github.com/tusharsaxena/WowAddonStandards` at run time.
**Deviation-ID prefix:** `PC-` (reused from the 2026-07-12 audit; recurring deviations keep their prior IDs).
**Gate status at audit time:** `lua tests/run.lua` → **37 passed, 0 failed**; `luacheck .` → **0 warnings / 0 errors in 14 files**. README `[Tests]` badge = `37/37` (matches `docs/test-cases.md` total).

This is a **read-only** snapshot. No addon code, TOC, config, or data was modified.

---

## What PrettyChat is

A chat-formatting addon that rewrites Blizzard's system messages (loot, currency, money, reputation, experience, honor, tradeskill, misc) by **overriding `_G[GLOBALNAME]` format strings** at `OnEnable` rather than by hooking chat events — the taint-free approach endorsed by `events-frames-taint-§5`. Settings are schema-driven; a Blizzard Settings canvas panel and a `/pc` slash surface share one write path.

## Section-by-section snapshot

### layout
Modular layout present: `core/`, `defaults/`, `locales/`, `modules/`, `settings/`, `libs/`, `media/`, `tests/`, `docs/`. Subfolders lowercase; Lua files PascalCase. Media in typed subfolders (`media/fonts/`, `media/logos/`, `media/screenshots/`). **Exception:** `GlobalStrings/` is a generated-data folder at the **repo root** (10 runtime chunk files + a 1.6 MB source dump + a Python splitter), outside the modular skeleton — documented as an accepted deviation in `CLAUDE.md` (**PC-25**). No single `.lua` exceeds 1500 LOC (largest: `settings/Panel.lua`, 688 lines).

### toc-file
`PrettyChat.toc:1-13` metadata block follows the canonical field order (Interface → Title → Notes → Author → Version → IconTexture → SavedVariables → OptionalDeps → DefaultState → Category-enUS → X-License → X-Standard → X-Curse-Project-ID). Single `## Interface: 120007`. `X-License: MIT`, `X-Standard:` present. `X-Curse-Project-ID: 919766` present; **`X-Wago-ID` omitted** though the addon is published on CurseForge (**PC-10**, documented). Title carries rainbow colour escapes and Author uses `aDd1kTeD2Ka0s` casing (**PC-27**, documented). File-listing uses `#` section comments but the **section order** places `# Locales` after `# Core`/`# Defaults` and inserts a non-canonical `# GlobalStrings` section, diverging from `toc-file-§5`'s Libraries → Locales → Core → Defaults → Modules → Settings (**PC-33**). Libraries are listed directly (each lib's packaged `.xml`) — no `embeds.xml` (compliant with `toc-file-§4`).

### library-stack
Vendored + committed under `libs/`: LibStub, CallbackHandler-1.0, AceAddon-3.0, AceDB-3.0, AceConsole-3.0, AceGUI-3.0. AceEvent-3.0 / AceTimer-3.0 are **not** vendored — the addon never `LibStub`s them (no message bus, no timers), so this is correct per `library-stack-§3` ("vendor what you use, nothing more"). No lib forks, no suite dependencies, no `.pkgmeta externals:`.

### architecture
Every file opens with `local addonName, ns = ...`; no `_G[addonName]` table. **The namespace upvalue is lowercase `ns`** (standard convention is `NS` — **PC-28**). AceAddon registration at `core/PrettyChat.lua:8` calls `NewAddon("PrettyChat", "AceConsole-3.0")` — **the NS table is not passed as the first arg**, so the bootstrap `ns` table and the AceAddon object are separate (**PC-30**). Modules reach the addon via `LibStub("AceAddon-3.0"):GetAddon("PrettyChat")`. Schema-as-single-source is implemented well (`settings/Schema.lua`): one `Schema.Set` write path drives DB + panel + slash + reset, with load-time path validation (`Schema.validation`). No message bus (single feature module) — N/A.

### savedvariables
`PrettyChatDB` single global; AceDB `:New` at `core/PrettyChat.lua:40`. `schemaVersion` declared in `core/Database.lua:19-23` (`global.schemaVersion = 0`), migration runner `Database.RunMigrations` present (empty steps, idempotent). **Profile defaults are declared inline in `core/PrettyChat.lua:18-29`**, not in a `defaults/Profile.lua`; the hardcoded per-string default values live in `defaults/Defaults.lua` (**PC-39**).

### options-ui
Blizzard `Settings.RegisterCanvasLayoutCategory` + raw AceGUI; parent landing page + one subcategory per category (General first). Registration is eager (in `OnEnable`, after `Blizzard_Settings`/login — not deferred to `/config`). Bodies build lazily in `OnShow`. Combat lockdown handled in `PrettyChat:OpenConfig` with the canonical grey refusal notice and no defer-and-replay. **Defaults button is an AceGUI `Button`** (`settings/Panel.lua:202`) — compliant with the v2.7.0 `options-ui-§5` requirement. Always-visible scrollbar patch present (`patchAlwaysShowScrollbar`). Layout constants defined in `core/Constants.lua`. Panel refresh is in-place via per-widget refresher closures (`Schema.refreshers` / `NotifyPanelChange`) — no full-page rebuilds (avoids anti-pattern #39). **The per-string editor uses a bespoke 40/60 three-row layout** instead of the schema-driven 50/50 grid (**PC-23**, justified in code).

### standalone-windows / preview-mode / public-api
No main data-browser window (N/A beyond the debug console, which reuses a skin seam). No positionable on-screen display, so preview-mode is N/A (the `/pc test` chat preview is a different surface). No public API exposed — N/A.

### slash-commands
AceConsole `RegisterChatCommand("pc")` + `("prettychat")` alias. Ordered `COMMANDS` table drives dispatch and generated help; built-in `get/set/list/reset/resetall`, plus `config`, `version`, `test`, `debug`. `version` prints `[PC] v<version>`. Unknown verb prints `unknown command '<verb>'` + help. `list`/`get`/`set` use the mandated `slash-commands-§5` colour scheme via a shared `FormatKV` + `Schema.FormatValue`. No trailing colons. **Help header inserts " — " (`v1.4.0 — slash commands …`)** vs the canonical `v<version> slash commands …` (**PC-38**).

### localization
`ns.L` metatable with English-key fallback (`locales/enUS.lua`); enUS manifest of the user-facing surface. Only enUS shipped (additional locales opt-in). Game data is matched on the **non-localized `GLOBALNAME` token** (e.g. `LOOT_ITEM_SELF`), never on localized display text — compliant with `localization-§4`.

### events-frames-taint
Chat formatting via `_G[GLOBALSTRING]` override (taint-free, `events-frames-taint-§5`). **The shared chat printer `ns.Print` and the debug sink `ns.Debug` are not secret-safe** — no `IsConcatSafe`/`SafeToString` stringifier (**PC-34**). **`modules/Override.lua` `Test()` and related sites write directly to `DEFAULT_CHAT_FRAME:AddMessage`, bypassing the single `ns.Print` seam** (**PC-35**). Real-world secret exposure is nil (the addon never reads combat-protected values), but the standard requires the seam be secret-safe unconditionally.

### compat
`core/Compat.lua` present; `Compat.GetAddOnMetadata` shims `C_AddOns.GetAddOnMetadata` → legacy global. All metadata reads route through `ns.Compat`. No `WOW_PROJECT_ID` flavor branching. Compliant.

### debug-logging
On-screen console (`core/DebugLog.lua`, `PrettyChatDebugWindow`) on `DIALOG` strata, 700×344, `UISpecialFrames`, monospace font via `Const.FONT_MONO` (JetBrains Mono, OFL, vendored — sanctioned exception per `debug-logging-§2`; LSM registration deliberately omitted, documented in `CLAUDE.md`). Timestamped/tagged/coloured lines with the two pure formatters. Session-only flag (`ns.State.debug`), single `SetEnabled` seam with colour-coded ack + `[Debug]` bracket lines + `[Init]` session summary on enable. Copy/Clear present. Coverage traces `[Init]`/`[Migrate]`/`[Set]`/`[Reset]`/`[Config]`. Sink is zero-alloc when off but **not secret-safe** (rolled into **PC-34**).

### packaging
`.pkgmeta` present, `package-as: PrettyChat`, no `externals:`, ignores `docs`/`tests`/lockfiles. **Does not ignore the dev-only GlobalStrings source dump** (`GlobalStrings/GlobalStrings.lua` ~1.6 MB, `split_globalstrings.py`, `GlobalStrings.toc`, `GlobalStrings/README.md`), which would bloat the shipped package (**PC-37**).

### lint
`.luacheckrc` present: `std = "lua51"`, excludes `libs`/`GlobalStrings`/`docs/audits`/`docs/reviews`/`tests`, declares owned write globals with justifying comments. `luacheck .` clean. Compliant.

### testing
Headless Lua 5.1 harness (`tests/run.lua`, `loader.lua`, `wow_mock.lua`) + 6 suites; 37 cases, all green. `docs/test-cases.md` generated (`--list`), authoritative total 37. README `[Tests]` badge `37/37` in lockstep. Compliant.

### documentation
Root ships `README.md`, `CLAUDE.md`, `LICENSE`. README is player-facing, plain-language, canonical badge row (5 badges, correct order), logo, description, screenshots, usage, `## How it works`, FAQ, Troubleshooting, Issues, Version History. **README `### Settings panel` uses a bulleted list, not the mandated Tab | Covers table** (**PC-36**). `docs/` quartet present (`agent-context.md`, `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`) plus required generated `test-cases.md`. **`CLAUDE.md` lacks the mandated `## Standards compliance (read first)` section and the `# CLAUDE.md — Ka0s Pretty Chat` title form** (**PC-31**). **`docs/agent-context.md` `## Hard rules` does not open with the conform-to-the-standard rule and contains no reference to the standards repo at all** (**PC-32**). The four-place standards reference (`documentation-§6`) is therefore satisfied in only 2 of 4 places (TOC + README badge; missing from CLAUDE.md section and agent-context Hard rules) — anti-pattern #34.

### audit-review-history / versioning-git / naming-cheatsheet
Prior audit frozen under `docs/audits/2026-07-12/`; a review under `docs/reviews/2026-05-02/`. This run writes a new dated folder without touching prior runs. Semver in TOC (`1.4.0`). Naming mostly per cheatsheet except the `ns` vs `NS` upvalue (**PC-28**).
