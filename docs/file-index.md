# File index

Where each responsibility lives in the source tree. Match this map to the actual files before editing — `PrettyChat.toc` is the source of truth for load order.

## Top-level Lua

| File | Responsibility |
|------|----------------|
| `Compat.lua` | `ns.Compat` — version-shim seam. `Compat.GetAddOnMetadata` (C_AddOns vs legacy global). Loads first among addon files. |
| `Locale.lua` | `ns.L` — English-key localization metatable (`__index` returns the key) + seeded enUS UI-string manifest. Wrap new user-facing strings in `L[…]`. |
| `Constants.lua` | Layout constants on `ns.Const` (panel padding / header height / Defaults-button width / spacers / `BUTTON_PAIR_REL`), the `Color` palette, and `ns.PREFIX` (shared cyan `[PC]` tag). Side-effect-free; loads early so `Config.lua` can read `ns.Const.*` without an existence check. |
| `Defaults.lua` | The `ns.Defaults` table — canonical per-category format strings, labels, and per-category `enabled` flag. Single source of truth for what categories and strings exist. Eight categories with **81 rows over 79 unique globals** (Loot 19, Currency 4, Money 8, Reputation 14, Experience 20, Honor 6, Tradeskill 8, Misc 2 — `LOOT_ITEM_CREATED_SELF` and `LOOT_ITEM_CREATED_SELF_MULTIPLE` are registered under both Loot and Tradeskill, see [override-pipeline.md](./override-pipeline.md)). |
| `Database.lua` | `ns.Database` — `SCHEMA_VERSION`, `global.schemaVersion` default, and `RunMigrations(db)` (empty migration set today). Merged into AceDB + run in `PrettyChat:OnInitialize`. |
| `PrettyChat.lua` | AceAddon entry. `OnInitialize` (DB + `ns.Database` migrations + slash registration), `OnEnable` (snapshot Blizzard originals → `ApplyStrings`). Houses `ApplyStrings` (deterministic `CATEGORY_ORDER` + sorted iteration), `Test`, the read helpers (`GetStringValue` / `IsAddonEnabled` / `IsCategoryEnabled` / `IsStringEnabled` / `EnsureCategoryDB`), `ResetCategory` / `ResetAll`, the ordered `COMMANDS` table (incl. `debug`) that drives slash dispatch and `/pc help`, `ns.Print` / `ns.Debug` / `ns.State`, and `ns.RenderSample(fmt)` shared with the panel's per-row sample line. |
| `Schema.lua` | Builds a flat `rows` array and `byPath` lookup from `ns.Defaults` at file-load, plus a load-time path validator (`Schema.validation`). Exposes `ns.Schema` — the **single write path** shared by slash commands and panel widgets. Owns `CATEGORY_ORDER` (the canonical display order, including the virtual `General`). See [schema.md](./schema.md). |
| `Config.lua` | Settings panel built directly on `Settings.RegisterCanvasLayoutCategory` / `RegisterCanvasLayoutSubcategory` with AceGUI body content. `buildGeneralBody` builds the virtual `General` page; `buildCategoryBody` + `buildStringRow` build each format-bearing page; `buildParentBody` renders the parent landing page. UI strings go through `ns.L`. Exposes `ns.Config.RegisterPanels` (called from `PrettyChat:OnEnable`); each sub-page's first `OnShow` calls `ns.Schema.RegisterRefresher(category, refreshFn)` so `Schema.NotifyPanelChange` can re-sync the page after a write. All widget callbacks delegate to `ns.Schema.Set/Get`. See [settings-panel.md](./settings-panel.md). |

## GlobalStrings sub-tree

| Path | Purpose |
|------|---------|
| `GlobalStrings/GlobalStrings.lua` | Bundled Blizzard reference (~1.6 MB, ~22,879 entries). **Not loaded by any TOC** — only used as input to `split_globalstrings.py`. |
| `GlobalStrings/GlobalStrings_001.lua` … `_010.lua` | Chunk files. Each emits `ns.GlobalStrings["KEY"] = "value"` assignments. Loaded *eagerly* by `PrettyChat.toc` and *also* packaged as a LoadOnDemand sub-addon — see [global-strings.md](./global-strings.md) for the dual-load story. |
| `GlobalStrings/GlobalStrings.toc` | LoD sub-addon TOC (`PrettyChat - GlobalStrings`, `LoadOnDemand: 1`). Loads the same chunks. |
| `GlobalStrings/split_globalstrings.py` | Splitter script. Re-run after a WoW patch updates `GlobalStrings.lua`; rewrites the chunk files and updates `GlobalStrings.toc`'s file list. |
| `GlobalStrings/README.md` | Splitter usage instructions (where to source the latest `GlobalStrings.lua`, how to regenerate). |

## Shared infrastructure

- `PrettyChat.toc` — Interface line (`120007`), version, SavedVariables (`PrettyChatDB`), `# Libraries` / `# Addon` section comments, and file load order. Order is dependency order, not alphabetical: `libs/` → `Compat.lua` → `Locale.lua` → `Constants.lua` → `Defaults.lua` → `Database.lua` → GlobalStrings chunks → `PrettyChat.lua` → `Schema.lua` → `Config.lua`.
- `libs/` — vendored Ace3 + LibStub. Tracked in git (standard WoW addon practice).
- `media/` — local copies of the logo + before/after screenshots. The README references CDN URLs, not these — they're kept around as source backups.
- `.gitattributes` — forces CRLF on disk for all text files (overrides per-user `core.autocrlf`).
- `.gitignore` — OS / editor cruft + `TODO.md` + `.claude/`.
- `LICENSE` — MIT.

## Top-level docs

- `README.md` — user-facing.
- `CLAUDE.md` — stub (tier + standard link + pointer to `docs/`); full engineer brief in [agent-context.md](./agent-context.md).
- `docs/ARCHITECTURE.md` — design overview + invariants + doc index (§15.3 sections).
- `docs/*.md` — topic chunks (this file is one of them). Includes [smoke-tests.md](./smoke-tests.md), the manual in-game test suite. Automated headless coverage lives in `tests/` (`lua tests/run.lua`).
