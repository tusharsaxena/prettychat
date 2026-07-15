# File index

Where each responsibility lives in the source tree. Match this map to the actual files before editing — `PrettyChat.toc` is the source of truth for load order.

## Source tree (Tier-2 modular)

Source `.lua` is grouped under `core/`, `defaults/`, `locales/`, `modules/`, and `settings/`.

### `core/`

| File | Responsibility |
|------|----------------|
| `core/Compat.lua` | `ns.Compat` — version-shim seam. `Compat.GetAddOnMetadata` (C_AddOns vs legacy global). Loads first among addon files. |
| `core/Constants.lua` | Layout constants on `ns.Const` (panel padding / header height / Defaults-button width / spacers / `BUTTON_PAIR_REL`), the `Color` palette (incl. the slash-output `azure` / `listHead` codes), `ns.Const.FONT_MONO` (vendored JetBrains Mono path for the debug console), and `ns.PREFIX` (shared cyan `[PC]` tag). Side-effect-free; loads early so later files can read `ns.Const.*` without an existence check. |
| `core/Namespace.lua` | Identity bootstrap — publishes `ns.name` and `ns.version` (read from the TOC via `ns.Compat`) so no module re-queries metadata. |
| `core/State.lua` | Publishes `ns.State` — session-only runtime state (`{ debug = false }`); never persisted, reset every reload/login. |
| `core/Util.lua` | Publishes `ns.Util` — pure string helpers `trim` / `note` / `cmd` shared by the slash dispatcher. Loads after Constants (reads `ns.Const.Color`). |
| `core/Database.lua` | `ns.Database` — `SCHEMA_VERSION`, `global.schemaVersion` default, and `RunMigrations(db)` (empty migration set today). Merged into AceDB + run in `PrettyChat:OnInitialize`. |
| `core/DebugLog.lua` | Publishes `ns.DebugLog` (the on-screen debug console — a monospace DIALOG-strata window with a `Debug: ON/OFF` header toggle + Copy/Clear buttons) and `ns.Debug(tag, fmt, …)` (the gated, zero-alloc-when-off sink that routes to the console). The `DebugLog:SetEnabled(on)` seam is the single owner of the session debug flag. |
| `core/PrettyChat.lua` | AceAddon entry. Registers the object, defines `ns.Print`, runs `OnInitialize` (DB + `ns.Database` migrations + slash registration) and `OnEnable` (snapshot Blizzard originals → `ApplyStrings` → `RegisterPanels`), and owns the combat-gated `OpenConfig`. The override engine and slash dispatch live in `modules/Override.lua` and `settings/Slash.lua`. |

### `defaults/`, `locales/`

| File | Responsibility |
|------|----------------|
| `defaults/Defaults.lua` | The `ns.Defaults` table — canonical per-category format strings, labels, and per-category `enabled` flag. Single source of truth for what categories and strings exist. Eight categories with **81 rows over 79 unique globals** (Loot 19, Currency 4, Money 8, Reputation 14, Experience 20, Honor 6, Tradeskill 8, Misc 2 — `LOOT_ITEM_CREATED_SELF` and `LOOT_ITEM_CREATED_SELF_MULTIPLE` are registered under both Loot and Tradeskill, see [override-pipeline.md](./override-pipeline.md)). |
| `locales/enUS.lua` | `ns.L` — English-key localization metatable (`__index` returns the key) + seeded enUS UI-string manifest. Wrap new user-facing strings in `L[…]`. |

### `modules/`, `settings/`

| File | Responsibility |
|------|----------------|
| `modules/Override.lua` | The override engine, attached to the shared addon object. Houses `ApplyStrings` (deterministic `CATEGORY_ORDER` + sorted iteration), `Test`, the read helpers (`GetStringValue` / `IsAddonEnabled` / `IsCategoryEnabled` / `IsStringEnabled` / `EnsureCategoryDB`), `ResetCategory` / `ResetAll`, and `ns.RenderSample(fmt)` shared with the panel's per-row sample line. |
| `settings/Schema.lua` | Builds a flat `rows` array and `byPath` lookup from `ns.Defaults` at file-load, plus a load-time path validator (`Schema.validation`) and the type-aware `Schema.FormatValue`. Exposes `ns.Schema` — the **single write path** shared by slash commands and panel widgets. Owns `CATEGORY_ORDER` (the canonical display order, including the virtual `General`). See [schema.md](./schema.md). |
| `settings/Slash.lua` | The `/pc` / `/prettychat` dispatcher. Owns the ordered `COMMANDS` table (`help`, `config`, `version`, `list`, `get`, `set`, `reset`, `resetall`, `test`, `debug`) that drives both dispatch and `/pc help`, `OnSlashCommand`, and every `runX` / `listSettings` / `getSetting` / `setSetting` handler. Slash `list` / `get` / `set` output uses the shared `FormatKV` + `Schema.FormatValue` for the mandated colour scheme (slash-commands-§5). Publishes `ns.COMMANDS`. See [slash-commands.md](./slash-commands.md). |
| `settings/Panel.lua` | Settings panel built directly on `Settings.RegisterCanvasLayoutCategory` / `RegisterCanvasLayoutSubcategory` with AceGUI body content. `buildGeneralBody` builds the virtual `General` page; `buildCategoryBody` + `buildStringRow` build each format-bearing page; `buildParentBody` renders the parent landing page. UI strings go through `ns.L`. Exposes `ns.Config.RegisterPanels` (called from `PrettyChat:OnEnable`); each sub-page's first `OnShow` calls `ns.Schema.RegisterRefresher(category, refreshFn)` so `Schema.NotifyPanelChange` can re-sync the page after a write. All widget callbacks delegate to `ns.Schema.Set/Get`. See [settings-panel.md](./settings-panel.md). |

## GlobalStrings sub-tree

| Path | Purpose |
|------|---------|
| `GlobalStrings/GlobalStrings.lua` | Bundled Blizzard reference (~1.6 MB, ~22,879 entries). **Not loaded by any TOC** — only used as input to `split_globalstrings.py`. |
| `GlobalStrings/GlobalStrings_001.lua` … `_010.lua` | Chunk files. Each emits `ns.GlobalStrings["KEY"] = "value"` assignments. Loaded *eagerly* by `PrettyChat.toc` and *also* packaged as a LoadOnDemand sub-addon — see [global-strings.md](./global-strings.md) for the dual-load story. |
| `GlobalStrings/GlobalStrings.toc` | LoD sub-addon TOC (`PrettyChat - GlobalStrings`, `LoadOnDemand: 1`). Loads the same chunks. |
| `GlobalStrings/split_globalstrings.py` | Splitter script. Re-run after a WoW patch updates `GlobalStrings.lua`; rewrites the chunk files and updates `GlobalStrings.toc`'s file list. |
| `GlobalStrings/README.md` | Splitter usage instructions (where to source the latest `GlobalStrings.lua`, how to regenerate). |

## Shared infrastructure

- `PrettyChat.toc` — Interface line (`120007`), version, SavedVariables (`PrettyChatDB`), section comments, and file load order. Order is dependency order, not alphabetical: `libs/` → `core/Compat` → `core/Constants` → `core/Namespace` → `core/State` → `core/Util` → `core/Database` → `core/DebugLog` → `core/PrettyChat` → `defaults/Defaults` → `locales/enUS` → GlobalStrings chunks → `modules/Override` → `settings/Schema` → `settings/Slash` → `settings/Panel`.
- `libs/` — vendored Ace3 + LibStub. Tracked in git (standard WoW addon practice).
- `media/` — local copies of the logo + before/after screenshots (the README references CDN URLs, not these — kept as source backups) and `media/fonts/` (vendored JetBrains Mono, OFL), which **is** loaded at runtime by `core/DebugLog.lua` via `ns.Const.FONT_MONO`.
- `.gitattributes` — forces CRLF on disk for all text files (overrides per-user `core.autocrlf`).
- `.gitignore` — OS / editor cruft + `TODO.md` + `.claude/`.
- `LICENSE` — MIT.

## Top-level docs

- `README.md` — user-facing.
- `CLAUDE.md` — stub (tier + standard link + pointer to `docs/`); full engineer brief in [agent-context.md](./agent-context.md).
- `docs/ARCHITECTURE.md` — design overview + invariants + doc index (§15.3 sections).
- `docs/*.md` — topic chunks (this file is one of them). Includes [smoke-tests.md](./smoke-tests.md), the manual in-game test suite. Automated headless coverage lives in `tests/` (`lua tests/run.lua`).
