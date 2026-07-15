# Architecture

Orient-yourself map for **Ka0s Pretty Chat**. This file is the high-level index; topic detail lives alongside it in `docs/`.

## Overview

A WoW addon that overrides Blizzard's `GlobalStrings.lua` format strings — `LOOT_ITEM_SELF`, `COMBATLOG_XPGAIN_*`, `FACTION_STANDING_INCREASED`, etc. — to reformat system chat lines (loot, currency, money, reputation, XP, honor, tradeskill, misc) into a color-coded `Category | Context | Source | +/- value` layout. WoW's chat code reads `_G[GLOBALNAME]` lazily on every line, so overrides take effect uniformly across any chat UI (default Blizzard, ElvUI, Glass, …) without per-message hooks. Eight format-bearing categories (81 strings total) are addressed via a flat schema + `/pc` slash CLI + a Blizzard-panel sub-page per category.

```
defaults/Defaults.lua  ─▶ ns.Defaults (categories + format strings + per-cat enabled)
                    │
                    ├─▶ settings/Schema.lua ─▶ ns.Schema  (rows[], byPath[], single write path)
                    │                       │
                    │                       ├─▶ /pc set / get / list / reset   (settings/Slash.lua)
                    │                       └─▶ Panel widget get/set           (settings/Panel.lua)
                    │
                    └─▶ modules/Override.lua ApplyStrings()
                                │
                                ▼
                          _G[GLOBALNAME]   ◀── WoW chat code reads lazily on every line
                                                (no addon hooks, no per-message rewriting)

GlobalStrings/   ─▶ ns.GlobalStrings (Blizzard reference, ~22,879 entries)
                       │
                       └─▶ settings/Panel.lua "Original Format String" disabled input
```

## Module Map

Modular layout (`core/`, `defaults/`, `locales/`, `modules/`, `settings/`) — the single Ka0s layout (`layout-§1`). Load order is `PrettyChat.toc` (dependency, not alphabetical): libraries first, then `core/Compat → core/Constants → core/Namespace → core/State → core/Util → core/Database → core/DebugLog → core/PrettyChat → defaults/Defaults → locales/enUS → GlobalStrings chunks → modules/Override → settings/Schema → settings/Slash → settings/Panel`.

| Module | Publishes on `ns` | Role |
|--------|-------------------|------|
| `core/Compat.lua` | `ns.Compat` | Version-shim seam. `Compat.GetAddOnMetadata` (C_AddOns vs legacy global). |
| `core/Constants.lua` | `ns.Const`, `ns.PREFIX` | Panel layout constants, `Const.Color` palette (incl. `azure` / `listHead` slash-output codes), `Const.BUTTON_PAIR_REL`, `Const.FONT_MONO` (vendored JetBrains Mono path), and the shared cyan `[PC]` chat prefix. Side-effect-free. |
| `core/Namespace.lua` | `ns.name`, `ns.version` | Identity bootstrap — records the addon name + version so any module can read them without re-querying the TOC. |
| `core/State.lua` | `ns.State` | Session-only runtime state (`{ debug = false }`); never persisted, reset every reload/login. |
| `core/Util.lua` | `ns.Util` | Pure string helpers `trim` / `note` / `cmd` shared by the slash dispatcher. |
| `core/Database.lua` | `ns.Database` | `SCHEMA_VERSION`, `global.schemaVersion` default, and `RunMigrations(db)` (empty migration set today). |
| `core/DebugLog.lua` | `ns.DebugLog`, `ns.Debug` | On-screen debug console (monospace window) + the gated `ns.Debug(tag, fmt, …)` sink; the `SetEnabled` seam is the single owner of the session debug flag. |
| `core/PrettyChat.lua` | `ns.Print` | AceAddon object + lifecycle (`OnInitialize` / `OnEnable`), the cyan `[PC]` chat printer, and the combat-gated `OpenConfig`. |
| `defaults/Defaults.lua` | `ns.Defaults` | Category → format-string default table (label + default per string; per-category `enabled`). |
| `locales/enUS.lua` | `ns.L` | Localization table with English-key fallback (`__index` returns the key). Seeds the enUS UI-string manifest. |
| `modules/Override.lua` | `ns.RenderSample` | The override engine — `ApplyStrings`, the enable-cascade predicates, `ResetCategory` / `ResetAll`, and the Test / sample renderer. |
| `settings/Schema.lua` | `ns.Schema` | Builds `rows`/`byPath` from `ns.Defaults`; single write path (`Schema.Set`), `Schema.FormatValue`, load-time path validator, cross-registered-global map. |
| `settings/Slash.lua` | `ns.COMMANDS` | The `/pc` dispatcher — ordered `COMMANDS` table, `OnSlashCommand`, and every `list` / `get` / `set` / `reset` / `test` / `debug` handler. |
| `settings/Panel.lua` | `ns.Config.RegisterPanels` | Canvas-layout parent + one sub-page per category; per-string editor rows. |

Topic detail: [module-map.md](./module-map.md), [file-index.md](./file-index.md).

## Settings Schema

`ns.Defaults` is the source data; `settings/Schema.lua` turns it into an ordered `rows` list keyed by dot path. Four row kinds:

- `General.enabled` — addon-wide master toggle (bool). `General` is a **virtual category** with no entry in `ns.Defaults`; stored as `db.profile.enabled` at the profile root.
- `<Category>.enabled` — per-category toggle (bool).
- `<Category>.<GLOBALNAME>.enabled` — per-string toggle (bool).
- `<Category>.<GLOBALNAME>.format` — per-string format string.

Every mutation goes through `ns.Schema.Set(path, value)` — the **single write path** used by both `/pc set` and the panel widgets. Row `set()` closures are pure DB writes; `Schema.Set` runs `PrettyChat:ApplyStrings()` + `Schema.NotifyPanelChange()`. `string_format` rows **auto-clear** on a default match (a value equal to the default deletes the stored override). At load, `Schema.validation` records that every row path resolves to a backing default (loud `ns.Print` warn on any miss). Settings persist in `PrettyChatDB` via AceDB on a single shared Default profile; `db.global.schemaVersion` is stamped by `Database.RunMigrations`. Detail: [schema.md](./schema.md).

## Slash Commands

`/pc` and `/prettychat` dispatch through one ordered `COMMANDS` table in `settings/Slash.lua` (help text is generated from the same table). Verbs: `help`, `config`, `version`, `list`, `get`, `set`, `reset`, `resetall`, `test`, `debug`. `ns.COMMANDS` is published so the parent panel renders the same list. Slash `list` / `get` / `set` output follows the mandated colour scheme (slash-commands-§5) via a shared `FormatKV` + `Schema.FormatValue`. Chat input requires `||` for a literal `|`. Detail: [slash-commands.md](./slash-commands.md).

## Event Subscriptions

**None by design.** PrettyChat registers no `RegisterEvent` / chat filters and hooks no chat frames — the entire mechanism is overriding `_G[GLOBALNAME]` and letting WoW's chat code read it lazily. The only lifecycle hooks are the AceAddon callbacks `OnInitialize` (DB + migrations + slash registration) and `OnEnable` (snapshot Blizzard originals → `ApplyStrings` → register panels). Adding an event subscription or chat filter would change the addon's compatibility contract. There is no message bus.

## Taint Notes

- `OpenConfig` guards on `InCombatLockdown()` before `Settings.OpenToCategory` — the protected category-switch taints the panel for the session if called under combat lockdown. The guard lives in `OpenConfig` (not just the slash dispatcher) so programmatic callers are also gated.
- `expandMainCategory` reaches into private `SettingsPanel` internals (`GetCategoryList`, `GetCategoryEntry`, `SetExpanded`) inside a `pcall`; a missing API surfaces a one-time grey notice rather than erroring.
- The always-show-scrollbar patch reaches into AceGUI ScrollFrame internals and restores stock behaviour on widget release so the shared AceGUI pool isn't polluted for other addons.
- No `SecureHook`, no protected-frame creation, no combat-sensitive writes beyond the guarded panel open.

## Known Limitations

- **Retail only.** `## Interface: 120007` (Midnight / Retail). Classic / Classic Era untested.
- **Snapshot is load-time.** `OnEnable` snapshots Blizzard originals only for strings mentioned in `ns.Defaults` (~81). Adding a new `globalName` needs a `/reload` for the snapshot to capture its pristine value.
- **Cross-registered globals: last-writer-wins.** A global registered under two categories (e.g. `LOOT_ITEM_CREATED_SELF` under Loot + Tradeskill) resolves to the **last** category in `CATEGORY_ORDER` — now deterministic (PC-16), surfaced in the per-string tooltip.
- **Positional format rendering is WoW-only.** `%n$s` specifiers rely on WoW's extended `string.format`; the headless test harness (stock Lua 5.1) can't render them and asserts graceful degradation instead.
- **Single shared profile.** Per-character / per-realm profile scoping is not exposed.

## External dependencies

Vendored under `libs/` (the BigWigs packager pulls nothing — no `externals`): LibStub, CallbackHandler-1.0, AceAddon-3.0, AceDB-3.0, AceConsole-3.0, AceGUI-3.0. (`AceConfig-3.0` was removed — no live consumer.)

## Testing

Headless harness under `tests/` (stock Lua 5.1, no client): `lua tests/run.lua` + `luacheck .`. Suites register named `test(name, fn)` cases; `lua tests/run.lua --list` prints the generated case inventory ([test-cases.md](./test-cases.md), testing-§5) — the authoritative pass count, mirrored by the README `tests` badge. Manual in-game validation: [smoke-tests.md](./smoke-tests.md). Full verification guide and the commit gate: [testing.md](./testing.md).
