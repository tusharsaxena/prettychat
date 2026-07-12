# Agent context — working notes for LLM-assisted sessions

Detailed working notes for Claude Code (and other LLM-assisted editors) on **Ka0s Pretty Chat**. The root [CLAUDE.md](../CLAUDE.md) is a stub that points here. User-facing reference: [README.md](../README.md). Design overview + invariants: [ARCHITECTURE.md](./ARCHITECTURE.md).

## What this addon is

A WoW addon that reformats system chat messages (loot, currency, money, reputation, XP, honor, tradeskill, misc) by overriding Blizzard's `GlobalStrings.lua` format strings — not by parsing chat events. That makes it compatible with any chat UI (default Blizzard, ElvUI, Glass, …) without configuration. Settings live in a Blizzard-panel sub-page per category plus a schema-driven `/pc` slash CLI; both surfaces share one write path.

Tier-1 flat layout. Load order (`PrettyChat.toc`): libraries → `Compat → Locale → Constants → Defaults → Database → GlobalStrings chunks → PrettyChat → Schema → Config`.

## Hard rules

- **Single write path.** Every settings mutation goes through `ns.Schema.Set(path, value)` — both panel widget callbacks (`Config.lua`) and `/pc set` (`PrettyChat.lua`'s `setSetting`). Never write directly to `db.profile.categories[...]` from outside the row's `set()` closure. The single path runs `PrettyChat:ApplyStrings()` and `Schema.NotifyPanelChange()` so panel and slash never drift.
- **Master toggle wins.** When `General.enabled` is false, `ApplyStrings` restores every Blizzard original regardless of per-category and per-string state. Three enable layers, evaluated in order: addon → category → per-string. See [override-pipeline.md](./override-pipeline.md).
- **Format-specifier signatures must match Blizzard's.** Each Blizzard string has a fixed signature (`%s`, `%d`, `%.1f`, `%2$s`, …); replacements must consume the same conversions in the same order, or `string.format` errors at runtime. Copy from the panel's left (Original) edit box.
- **GlobalString overrides happen in `OnEnable`**, after Blizzard has populated `_G`. The pre-override snapshot in `OnEnable` (iterating `ns.Defaults` deterministically) is the only chance to capture pristine Blizzard values for the runtime "restore on disable" path. Never override `_G[GLOBALNAME]` from anywhere except `ApplyStrings`, which iterates `CATEGORY_ORDER` + sorted names so cross-registered globals apply deterministically (documented last-writer).
- **Cyan `[PC]` chat prefix on all addon output.** Routes through `ns.Print(msg)` in `PrettyChat.lua`, which prepends `ns.PREFIX` (`|cff00ffff[PC]|r `). **No raw `print(...)` calls.** `Test()` writes directly to `DEFAULT_CHAT_FRAME:AddMessage` but every body line still starts with `PREFIX`. Gated developer logging goes through `ns.Debug(tag, fmt, ...)` (session-only `ns.State.debug`, toggled by `/pc debug`).
- **User-facing strings go through `ns.L`.** `Locale.lua` exports an English-key metatable (missing keys fall back to English). Wrap new static UI strings in `L["…"]` and add them to the enUS manifest.
- **Never auto-stage, auto-commit, or auto-push.** After making code changes, leave them as **unstaged** working-tree edits and report what changed. Do NOT run `git add` / `git stage` / `git commit` / `git push` / `git restore --staged` without an explicit instruction. Read-only inspection is fine.
  - **Exception — `/wow-addon:commit`**: invoking that slash command IS the explicit instruction to commit (it runs its own y/n confirmation gate).
- **Never bump the version without an explicit instruction.** Do not edit `## Version:` in `PrettyChat.toc` or the README badges/changelog unless the user has explicitly asked. Releases are the user's call.

## Test gate

There is now a headless harness. **After every change, `lua tests/run.lua` must be green and `luacheck .` clean** (§14A commit gate).

- `tests/run.lua` loads the addon sources into a mock WoW env (`tests/wow_mock.lua`, `tests/loader.lua`) under stock Lua 5.1 and runs suites: `test_schema`, `test_render`, `test_apply`, `test_database`.
- `.luacheckrc` configures the lint (`std=lua51`; excludes `libs/ GlobalStrings/ audit/ tests/ reviews`).
- Manual in-game validation still matters — see [smoke-tests.md](./smoke-tests.md) (routine quick recipe + full suite for pre-release / post-patch / post-touch of `OnEnable` / `ApplyStrings` / `Schema.lua` / `Config.lua`).

## Namespace publishing pattern

Every file uses `local addonName, ns = ...`. Public surfaces on `ns`:

| Member | Set by | Used by |
|--------|--------|---------|
| `ns.Compat` | `Compat.lua` | `PrettyChat.lua`, `Config.lua` (metadata access) |
| `ns.L` | `Locale.lua` | `Config.lua`, `PrettyChat.lua` (UI strings) |
| `ns.Const` / `ns.PREFIX` | `Constants.lua` | `Config.lua` (layout/palette), `PrettyChat.lua` (prefix, palette) |
| `ns.Defaults` | `Defaults.lua` | `Schema.lua`, `PrettyChat.lua`, `Config.lua` |
| `ns.Database` | `Database.lua` | `PrettyChat.lua` (`OnInitialize` merges defaults + runs migrations) |
| `ns.GlobalStrings` | `GlobalStrings/` chunks | `Config.lua` (Original Format String display) |
| `ns.Print` / `ns.Debug` / `ns.State` | `PrettyChat.lua` | every file (chat output; gated logging) |
| `ns.Schema` | `Schema.lua` | `PrettyChat.lua` (slash), `Config.lua` (widgets) |
| `ns.RenderSample` | `PrettyChat.lua` | `Config.lua` (per-string Preview) |
| `ns.COMMANDS` | `PrettyChat.lua` | `Config.lua` (parent page slash list) |
| `ns.Config.RegisterPanels()` | `Config.lua` | `PrettyChat.lua` (`OnEnable`) |

The addon object itself (`PrettyChat`) is **not** on `ns`; reach it via `LibStub("AceAddon-3.0"):GetAddon("PrettyChat")`.

## Working environment

- **Dual-path WSL.** `/home/tushar/GIT/prettychat/` and `/mnt/d/Profile/Users/Tushar/Documents/GIT/prettychat/` are the same repo via symlink.
- **`.gitattributes`** forces CRLF on disk for all text files.
- **`.gitignore`** covers OS/editor cruft and `.claude/`. `libs/` is tracked (vendored Ace3). `GlobalStrings/`, `media/`, all `.lua` source, `tests/`, `.luacheckrc`, `.pkgmeta` are tracked.
- **Case-insensitive `/mnt/d`.** The `libs/` folder was renamed from `Libs/` on disk; because `core.ignorecase=true`, recording the case flip in git needs `git mv -f Libs libs` (the working tree is already lowercase).

## Doc index

Topic-specific detail lives in `docs/`. Read on demand.

| Topic | File |
|-------|------|
| Design overview + invariants (§15.3 sections) | [ARCHITECTURE.md](./ARCHITECTURE.md) |
| In/out scope + resolved decisions | [scope.md](./scope.md) |
| Per-file responsibility map | [file-index.md](./file-index.md) |
| Module roles + public APIs | [module-map.md](./module-map.md) |
| Snapshot → ApplyStrings → restore + 3-layer enable order | [override-pipeline.md](./override-pipeline.md) |
| Schema row kinds + single write path + auto-clear + AceDB shape | [schema.md](./schema.md) |
| Canvas-layout panel framework | [settings-panel.md](./settings-panel.md) |
| `COMMANDS` table + full command reference | [slash-commands.md](./slash-commands.md) |
| Dual-load story + splitter script | [global-strings.md](./global-strings.md) |
| Recipes (add string/category, fix a format) | [common-tasks.md](./common-tasks.md) |
| Quick recipe + full smoke-test suite | [smoke-tests.md](./smoke-tests.md) |
