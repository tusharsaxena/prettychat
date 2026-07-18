# 03 — Evidence

`file:line` citations backing each deviation in `02_DEVIATIONS.md` and the key compliance claims. Line numbers are as read on 2026-07-18.

## Deviation evidence

### PC-30 — `:NewAddon` not passed the NS table (`architecture-§2`, MUST)
- `core/PrettyChat.lua:8` — `local PrettyChat = LibStub("AceAddon-3.0"):NewAddon("PrettyChat", "AceConsole-3.0")` — first arg is the **name string**, not `ns`.
- `core/PrettyChat.lua:14-16` — `function ns.Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end` — the custom printer lives on `ns`, a **separate table** from the AceAddon object, which is why AceConsole's `:Print` embed (landing on `PrettyChat`, not `ns`) does not clobber it today.
- `modules/Override.lua:8`, `settings/Schema.lua:3`, `settings/Slash.lua:9`, `settings/Panel.lua:3` — every module re-acquires the addon via `LibStub("AceAddon-3.0"):GetAddon("PrettyChat")`, confirming the two-object split.

### PC-31 — CLAUDE.md missing the Standards-compliance section (`documentation-§2/§6`, #34, MUST)
- `CLAUDE.md:1` — H1 is `# CLAUDE.md` (standard wants `# CLAUDE.md — Ka0s Pretty Chat`).
- `CLAUDE.md:15-21` — the standards-compliance substance lives under `## Non-negotiable guardrails` as a bullet ("Standards compliance — flag every deviation"), **not** as the mandated `## Standards compliance (read first)` section. No heading with that exact title exists in the file.

### PC-32 — agent-context.md Hard rules omit the standard (`documentation-§3/§6`, #34, MUST)
- `docs/agent-context.md:11-13` — `## Hard rules` opens with "**Single write path.**", not the conform-to-the-standard rule.
- Repo grep: `grep -c WowAddonStandards docs/agent-context.md` → **0** (the standards-repo URL appears nowhere in the full agent brief). Contrast `CLAUDE.md` → 2 occurrences.

### PC-33 — TOC file-listing section order (`toc-file-§5`, #28, MUST)
- `PrettyChat.toc:15-57` — section comment order is `# Libraries` (15) → `# Core` (23) → `# Defaults` (33) → `# Locales` (36) → `# GlobalStrings` (39) → `# Modules` (51) → `# Settings` (54). Canonical order is Libraries → **Locales** → Core → Defaults → Modules → Settings; `# Locales` is misplaced after Core/Defaults and `# GlobalStrings` is non-canonical.
- Cross-reference tension: `layout.md:49` (load order) lists `defaults/* → locales/*`, conflicting with `toc-file.md:87`'s section order — noted in the fix direction.

### PC-34 — printer / sink not secret-safe (`events-frames-taint-§8`, #35, MUST)
- `core/PrettyChat.lua:14-16` — `ns.Print` concatenates `PREFIX .. msg` with no secret-safe stringifier.
- `core/DebugLog.lua:306-310` — `ns.Debug` does `fmt:format(...)` on `...` with no secret guard.
- `core/Util.lua:1-24` — no `IsConcatSafe` / `SafeToString` helper exists (the entire file: `trim`, `note`, `cmd` only).

### PC-35 — call sites bypass the shared printer (`events-frames-taint-§8`, MUST)
- `modules/Override.lua:221,223` — `DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. note(...))`.
- `modules/Override.lua:252,253,256,260,264,266,280,289` — repeated direct `DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. ...)` in `Test()`.
- `settings/Schema.lua:187-189` — `ns.Print("|cffff5050[schema]|r unresolved path …")` hand-writes a tag/colour ahead of the printer.

### PC-36 — README Settings-panel not a table (`documentation-§1` item 6, MUST)
- `README.md:44-58` — `### Settings panel` is a paragraph followed by a `*`-bulleted list of the nine subcategories; there is no `Tab | Covers` markdown table. (Contrast `### Slash commands` at `README.md:31-42`, which correctly uses a `Command | What it does` table.)

### PC-39 — profile defaults not in defaults/Profile.lua (`savedvariables-§2`, SHOULD)
- `core/PrettyChat.lua:18-29` — `local defaults = { profile = { categories = {} } }` declared inline in a `core/` file.
- `defaults/` contains only `Defaults.lua` (per-string reference data); no `Profile.lua` exists (`ls defaults/`).

### PC-38 — help header em-dash (`slash-commands-§4`, SHOULD)
- `settings/Slash.lua:64` — `ns.Print(note("v" .. VERSION .. " — slash commands (") …)` inserts ` — ` between the version and "slash commands".

### PC-37 — packaging ships GlobalStrings source dump (`packaging`, SHOULD)
- `.pkgmeta:5-12` — `ignore:` lists `docs`, `tests`, `.luacheckrc`, `.gitignore`, `.gitattributes`, `*.bak`, `TODO.md` — no `GlobalStrings/GlobalStrings.lua`, `GlobalStrings/split_globalstrings.py`, `GlobalStrings/GlobalStrings.toc`, or `GlobalStrings/README.md`.
- `ls -la GlobalStrings/` — `GlobalStrings.lua` = 1,596,658 bytes (source dump); `split_globalstrings.py` = 7,559 bytes; `GlobalStrings.toc` = 410 bytes; `README.md` = 2,204 bytes; runtime chunks `GlobalStrings_001..010.lua` are loaded by `PrettyChat.toc:40-49` and must ship.

### PC-10 — X-Wago-ID missing on a published addon (`toc-file-§1`, MUST, documented)
- `PrettyChat.toc:13` — `## X-Curse-Project-ID: 919766` present; **no** `## X-Wago-ID` line follows.
- `CLAUDE.md:9` — "`## X-Wago-ID` is intentionally omitted until a real Wago id is available (do not commit a placeholder)."

### PC-23 — per-string editor 40/60 layout (`options-ui-§6`, SHOULD, documented)
- `settings/Panel.lua:398-399` — `local LEFT_W = 0.4 / RIGHT_W = 0.6`.
- `settings/Panel.lua:380-396` — code comment justifying the domain-specific three-row editor as a deliberate deviation from the 50/50 grid.

### PC-25 — GlobalStrings root generated-data folder (`layout-§1`, MUST, documented)
- `ls -d GlobalStrings/` at repo root; `PrettyChat.toc:39-49` loads `GlobalStrings\GlobalStrings_001..010.lua`.
- `CLAUDE.md:7` — the documented generated-data root exception.

### PC-27 — Title/Author branding (`toc-file-§1`, SHOULD, documented)
- `PrettyChat.toc:2` — `## Title: Ka0s |cffff0000P|cffff9900r|cffffff00e|…|r` (rainbow escapes).
- `PrettyChat.toc:4` — `## Author: aDd1kTeD2Ka0s`.
- `CLAUDE.md:9` — the documented brand-mark deviation.

### PC-28 — `ns` vs `NS` (`architecture-§1`, `naming-cheatsheet`, SHOULD)
- Every source file header, e.g. `core/PrettyChat.lua:1`, `settings/Schema.lua:1`, `modules/Override.lua:1` — `local addonName, ns = ...` (lowercase `ns`). `naming-cheatsheet.md:11` prescribes `NS`.

## Compliance evidence (claims that PASS — sampled)

- **Eager category registration / lazy body** — `core/PrettyChat.lua:63-64` (`ns.Config.RegisterPanels()` in `OnEnable`); `settings/Panel.lua:638-642,660-677` (`OnShow`-gated body builds).
- **Combat-gated config open, canonical refusal** — `core/PrettyChat.lua:101-104` (`InCombatLockdown()` grey notice "cannot open settings during combat — Blizzard's category-switch is protected"; no defer-and-replay).
- **Defaults button is AceGUI Button** — `settings/Panel.lua:202-209` (`AceGUI:Create("Button")` → `frame:SetParent(panel)` → reparented `TOPRIGHT`).
- **Always-visible scrollbar** — `settings/Panel.lua:68-166` (`patchAlwaysShowScrollbar`, `FixScroll` rebind keeping the bar shown+inert).
- **Schema-as-single-source + single write path** — `settings/Schema.lua:251-262` (`Schema.Set` → `row.set` → `ApplyStrings` → `NotifyPanelChange` → `[Set]` debug line); `settings/Schema.lua:180-191` (load-time path validation).
- **In-place panel refresh (no anti-pattern #39)** — `settings/Schema.lua:231-244` (`refreshers` + `NotifyPanelChange`); `settings/Panel.lua:511-527` (per-widget `refresh` closures via `SetValue`/`SetText`).
- **slash-commands-§5 colour scheme** — `settings/Slash.lua:21-23` (`FormatKV` gold key / white value), `:121-127` (green header, azure group), via shared `Schema.FormatValue` (`settings/Schema.lua:213-223`).
- **`version` verb** — `settings/Slash.lua:40-41` (`ns.Print("v" .. VERSION)`).
- **Debug console shape** — `core/DebugLog.lua:73-79` (`DIALOG` strata, 700×344), `:145-147` (`UISpecialFrames`), `:129,216` (`FONT_MONO`), `:154-164` (two pure formatters), `:275-295` (`SetEnabled` seam: colour ack + `[Debug]` bracket + `[Init]` summary).
- **Session-only debug flag** — `core/State.lua:6` (`ns.State = { debug = false }`, never in SavedVariables).
- **Compat routing** — `core/Compat.lua:11-19`; callers `core/Namespace.lua:7`, `settings/Slash.lua:12`, `settings/Panel.lua:14`.
- **Localization keyed on tokens** — `defaults/Defaults.lua` / `modules/Override.lua:51-85` key on `GLOBALNAME` constants, never localized display strings (`localization-§4`).
- **Taint-free chat formatting** — `core/PrettyChat.lua:51-57` + `modules/Override.lua:51-89` override `_G[GLOBALNAME]`, never hook `AddMessage` (`events-frames-taint-§5`).
- **Gates green** — `lua tests/run.lua` → "PrettyChat tests: 37 passed, 0 failed"; `luacheck .` → "0 warnings / 0 errors in 14 files"; `docs/test-cases.md` total = 37 = README `[Tests]` badge.
- **Standards reference present (2 of 4 places)** — `PrettyChat.toc:12` (`X-Standard`); `README.md:6` (standard badge). Missing from `CLAUDE.md` section (PC-31) and `docs/agent-context.md` Hard rules (PC-32).
