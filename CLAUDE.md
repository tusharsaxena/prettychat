# CLAUDE.md — working notes for future sessions

Guidance for Claude Code (and other LLM-assisted editors) working on **Ka0s Pretty Chat**. Read this first before touching code.

## What this addon is

A WoW addon that reformats system chat messages (loot, currency, money, reputation, XP, honor, tradeskill, misc) by overriding Blizzard's `GlobalStrings.lua` format strings — not by parsing chat events. That makes it compatible with any chat UI (default Blizzard, ElvUI, Glass, …) without configuration. Settings live in a Blizzard-panel sub-page per category plus a schema-driven `/pc` slash CLI; both surfaces share one write path.

User-facing reference: [README.md](./README.md). Design overview + invariants: [ARCHITECTURE.md](./ARCHITECTURE.md).

## Hard rules

- **Single write path.** Every settings mutation goes through `ns.Schema.Set(path, value)` — both panel widget callbacks (`Config.lua`) and `/pc set` (`PrettyChat.lua`'s `setSetting`). Never write directly to `db.profile.categories[...]` from outside the row's `set()` closure. The single path runs `PrettyChat:ApplyStrings()` and `Schema.NotifyPanelChange()` so panel and slash never drift.
- **Master toggle wins.** When `General.enabled` is false, `ApplyStrings` restores every Blizzard original regardless of per-category and per-string state. Three enable layers, evaluated in order: addon → category → per-string. See [docs/override-pipeline.md](./docs/override-pipeline.md).
- **Format-specifier signatures must match Blizzard's.** Each Blizzard string has a fixed signature (`%s`, `%d`, `%.1f`, `%2$s`, …); replacements must consume the same conversions in the same order, or `string.format` errors at runtime. Copy from the panel's left (Original) edit box.
- **GlobalString overrides happen in `OnEnable`**, after Blizzard has populated `_G`. The pre-override snapshot in `OnEnable` is the only chance to capture pristine Blizzard values for the runtime "restore on disable" path. Never override `_G[GLOBALNAME]` from anywhere except `ApplyStrings`.
- **Cyan `[PC]` chat prefix on all addon output.** Routes through `ns.Print(msg)` in `PrettyChat.lua`, which prepends `|cff00ffff[PC]|r `. **No raw `print(...)` calls.** The one intentional exception is `Test()`'s sample lines themselves (emitted unprefixed so each preview looks like a real chat message); header/footer carry the prefix.
- **Never auto-stage, auto-commit, or auto-push.** After making code changes, leave them as **unstaged** working-tree edits and report what changed. Do NOT run `git add` (or `git stage`, `git commit`, `git push`, `git restore --staged`, etc.) without an explicit instruction. Read-only inspection (`git status`, `git diff`, `git log`) is fine.
  - **Exception — `/wow-addon:commit`**: invoking the `/wow-addon:commit` slash command IS the explicit instruction to commit. The skill runs its own "Commit with this message? (y/n/edit)" confirmation gate — a `y` reply *inside that flow* is the user's commit consent, and `git add` / `git commit` may proceed against the named files. Scoped narrowly: only the user-invoked skill (and any future similarly-named explicit-commit skills like `/wow-addon:amend`); a casual mention of a commit elsewhere does NOT qualify, and a commit I propose on my own initiative still requires plain-language explicit ask.
- **Never bump the version without an explicit instruction.** Do not edit `## Version:` in `PrettyChat.toc` or the README badges/changelog unless the user has explicitly asked. Releases are the user's call.

## Namespace publishing pattern

Every file uses the same idiom at the top:

```lua
local addonName, ns = ...
```

Public surfaces are exposed on `ns`:

| Member | Set by | Used by |
|--------|--------|---------|
| `ns.Print(msg)` | `PrettyChat.lua` | every file (chat output chokepoint) |
| `ns.Schema` | `Schema.lua` | `PrettyChat.lua` (slash dispatch), `Config.lua` (every widget get/set) |
| `ns.GlobalStringSearch` | `GlobalStringSearch.lua` | nobody at runtime today; kept for future debug tooling |

The addon object itself (`PrettyChat`, an `AceAddon-3.0` object) is **not** published on `ns`. Other files reach it via `LibStub("AceAddon-3.0"):GetAddon("PrettyChat")`.

## Working environment

- **Dual-path WSL.** `/home/tushar/GIT/prettychat/` and `/mnt/d/Profile/Users/Tushar/Documents/GIT/prettychat/` are the same repo via symlink. Either path works for git and file tools.
- **`.gitattributes`** forces CRLF on disk for all text files (overrides per-user `core.autocrlf`).
- **`.gitignore`** covers OS / editor cruft, `TODO.md`, `.claude/`. `Libs/` is tracked (vendored Ace3, standard WoW addon practice). `GlobalStrings/`, `media/`, all `.lua` source are tracked.
- **No automated tests.** Validation is manual, in-game. See [docs/smoke-tests.md](./docs/smoke-tests.md) for the quick recipe (routine work) and the full suite (pre-release / post-patch / post-touch of `OnEnable` / `ApplyStrings` / `Schema.lua` / `Config.lua`).

## Response style for this repo

- **Terse.** State the change, not the deliberation.
- **Use `file_path:line_number` references** when pointing at code.
- **Don't write summaries** the user can read from the diff.
- **No comments explaining *what* well-named code does.** Only add a comment when the *why* is non-obvious (subtle invariant, workaround for a specific Blizzard quirk, hidden constraint).
- **Don't create docs or planning files unless asked.**

## Doc index

Topic-specific detail lives in `docs/`. Read on demand — these are not auto-loaded.

| Topic | File | When to read |
|-------|------|--------------|
| In/out scope + resolved decisions | [docs/scope.md](./docs/scope.md) | Evaluating a feature request; deciding whether to add a category. |
| Per-file responsibility map | [docs/file-index.md](./docs/file-index.md) | "Which file owns X?" |
| Module roles + public APIs (`ns.Schema`, `ns.Print`, `ns.GlobalStringSearch`, `PrettyChat:Test`) | [docs/module-map.md](./docs/module-map.md) | Designing a cross-module change. |
| Snapshot → ApplyStrings → restore + 3-layer enable order | [docs/override-pipeline.md](./docs/override-pipeline.md) | Touching `OnEnable`, `ApplyStrings`, or any path that mutates `_G[GLOBALNAME]`. |
| Schema row kinds + single write path + auto-clear + AceDB shape | [docs/schema.md](./docs/schema.md) | Changing how a setting is stored / read / written; adding a new row kind. |
| Canvas-layout framework + unified header + virtual `General` + per-string row + Test + color palette | [docs/settings-panel.md](./docs/settings-panel.md) | Touching `Config.lua`, `Constants.lua`, or anything that renders in the settings panel. |
| `COMMANDS` table + full command reference + `\|\|` ↔ `\|` chat-input escape | [docs/slash-commands.md](./docs/slash-commands.md) | Adding a slash command; debugging `/pc set` for format strings. |
| Dual-load story (eager + LoD) + splitter script + when to re-run | [docs/global-strings.md](./docs/global-strings.md) | Patch-day chunk regeneration; touching `GlobalStrings/` or `GlobalStringSearch.lua`. |
| Recipes (add string, add category, fix a broken format, regenerate chunks) | [docs/common-tasks.md](./docs/common-tasks.md) | Routine modifications. |
| Quick recipe + full smoke-test suite (Boot / Override / Panel / Slash / Sync / Persistence groups) | [docs/smoke-tests.md](./docs/smoke-tests.md) | Verifying any change in-game; pre-release; post-patch. |
