# Architecture

Orient-yourself map for **Ka0s Pretty Chat**. This file is the high-level index; topic detail lives in `docs/`.

## What it does

A WoW addon that overrides Blizzard's `GlobalStrings.lua` format strings — `LOOT_ITEM_SELF`, `COMBATLOG_XPGAIN_*`, `FACTION_STANDING_INCREASED`, etc. — to reformat system chat lines (loot, currency, money, reputation, XP, honor, tradeskill, misc) into a color-coded `Category | Context | Source | +/- value` layout. WoW's chat code reads `_G[GLOBALNAME]` lazily on every line, so overrides take effect uniformly across any chat UI (default Blizzard, ElvUI, Glass, …) without per-message hooks. Eight format-bearing categories with 81 strings total, addressed via a flat schema + `/pc` slash CLI + Blizzard-panel sub-page per category.

## Subsystems at a glance

```
Defaults.lua  ─▶ PrettyChatDefaults (categories + format strings + per-cat enabled)
                    │
                    ├─▶ Schema.lua   ─▶ ns.Schema   (rows[], byPath[], single write path)
                    │                       │
                    │                       ├─▶ /pc set / get / list / reset    (PrettyChat.lua)
                    │                       └─▶ AceConfig widget get/set        (Config.lua)
                    │
                    └─▶ PrettyChat.lua ApplyStrings()
                                │
                                ▼
                          _G[GLOBALNAME]   ◀── WoW chat code reads lazily on every line
                                                (no addon hooks, no per-message rewriting)

GlobalStrings/   ─▶ PrettyChatGlobalStrings (Blizzard reference, ~22,879 entries)
                       │
                       ├─▶ Config.lua "Original Format String" disabled input
                       └─▶ ns.GlobalStringSearch  (FindByKey/Value — unused at runtime today)
```

| Subsystem | Lives in | Read |
|-----------|----------|------|
| Per-module APIs + roles | `PrettyChat.lua`, `Schema.lua`, `Config.lua`, `Defaults.lua`, `GlobalStringSearch.lua` | [docs/module-map.md](./docs/module-map.md) |
| Snapshot → ApplyStrings → restore; 3-layer enable order | `PrettyChat.lua` (`OnEnable`, `ApplyStrings`) | [docs/override-pipeline.md](./docs/override-pipeline.md) |
| Schema row kinds + single write path + auto-clear + AceDB shape | `Schema.lua` (`Schema.Set`, row closures) | [docs/schema.md](./docs/schema.md) |
| Sub-pages + virtual `General` + 12-widget row + Test + color palette | `Config.lua` | [docs/settings-panel.md](./docs/settings-panel.md) |
| `COMMANDS` table + full command reference + `\|\|` ↔ `\|` escape | `PrettyChat.lua` (`COMMANDS`, `OnSlashCommand`) | [docs/slash-commands.md](./docs/slash-commands.md) |
| Dual-load story (eager + LoD) + splitter script | `GlobalStrings/`, `PrettyChat.toc` | [docs/global-strings.md](./docs/global-strings.md) |
| Per-file responsibility map | — | [docs/file-index.md](./docs/file-index.md) |
| Routine recipes (add string, add category, fix a broken format) | — | [docs/common-tasks.md](./docs/common-tasks.md) |
| In/out scope + resolved decisions | — | [docs/scope.md](./docs/scope.md) |

## Invariants worth not breaking

- **Single write path.** `ns.Schema.Set(path, value)` is the only function that mutates settings. Both `/pc set` and AceConfig widget set-callbacks go through it; the row's `set()` writes the DB *and* runs `PrettyChat:ApplyStrings()` *and* `Schema.NotifyPanelChange()`. Direct writes to `db.profile.categories[...]` from outside Schema are forbidden.
- **Master toggle wins.** When `db.profile.enabled` is false, `ApplyStrings` restores every Blizzard original regardless of per-category and per-string state. Three enable layers, evaluated in order: addon → category → per-string. A string only renders with the user's format if all three are on.
- **`OnEnable` snapshots Blizzard originals before any override.** This is the only chance to capture pristine values for the runtime "restore on disable" path — the snapshot only covers strings mentioned in `PrettyChatDefaults` (~81 entries). Adding a new `globalName` requires a `/reload` for the snapshot to pick it up.
- **Format-specifier signatures must match Blizzard's.** Each Blizzard string has a fixed signature (`%s`, `%d`, `%.1f`, `%2$s`, …); replacements must consume the same conversions in the same order or `string.format` errors at runtime. Copy from the panel's left (Original) edit box.
- **`General` is a virtual category.** No entry in `PrettyChatDefaults`; built by a dedicated `BuildGeneralOptions()` in `Config.lua` and stored as `db.profile.enabled` at the profile root (not under `db.profile.categories`). It owns the addon-wide toggle, Test, and Reset All.
- **Auto-clear on default match.** For `string_format` rows, writing a value that equals the PrettyChat default clears the override entry instead of storing it. `db.profile.categories[Cat].strings` never collects "override that happens to equal the default".
- **`CATEGORY_ORDER` is the single source of truth for display order.** Lives in `Schema.lua`; imported by `Config.lua` (left-rail order) and `PrettyChat.lua` (`Test()` and `/pc list` iteration). Iterating `pairs(PrettyChatDefaults)` directly would give a non-deterministic order.
- **Cyan `[PC]` chat prefix on all addon output.** Routes through `ns.Print(msg)`. The one intentional exception is `Test()`'s sample lines themselves — emitted unprefixed so each preview looks like a real chat message. No raw `print(...)` calls anywhere.
- **No chat event hooks, no per-message rewriting.** PrettyChat overrides `_G[GLOBALNAME]` and lets WoW's chat code do the rest. Adding an event subscription or a chat-frame filter would change the addon's compatibility contract.

## External dependencies

All vendored under `Libs/`:

- LibStub
- CallbackHandler-1.0
- AceAddon-3.0
- AceDB-3.0
- AceConsole-3.0
- AceGUI-3.0
- AceConfig-3.0 (pulls in AceConfigRegistry / AceConfigCmd / AceConfigDialog)

`PrettyChat.toc`'s `## Interface:` line is `120000, 120001, 120005` (The War Within / Midnight / Retail). Classic / Classic Era are not yet supported.

## Load order

`PrettyChat.toc` is the source of truth. Order is dependency, not alphabetical:

1. Ace3 libraries — LibStub → CallbackHandler-1.0 → AceAddon-3.0 → AceDB-3.0 → AceConsole-3.0 → AceGUI-3.0 → AceConfig-3.0.
2. `GlobalStrings/GlobalStrings_001.lua` … `_010.lua` — populates `PrettyChatGlobalStrings` eagerly so the panel can resolve "Original" values without an explicit load step. See [docs/global-strings.md](./docs/global-strings.md) for why this is also packaged as a LoadOnDemand sub-addon.
3. `Defaults.lua` — populates `PrettyChatDefaults`.
4. `PrettyChat.lua` — creates the AceAddon object, defines `ns.Print`, registers slash commands. **Every later file assumes the addon object exists** (`LibStub("AceAddon-3.0"):GetAddon("PrettyChat")`).
5. `Schema.lua` — builds `rows` / `byPath` from `PrettyChatDefaults`. Closures bind to live values.
6. `Config.lua` — registers the parent options table + one sub-page per category (driven by `ns.Schema.CATEGORY_ORDER`).
7. `GlobalStringSearch.lua`.

If you add a new file, put it in the right place in `PrettyChat.toc`.
