# File index

Where each responsibility lives in the source tree. Match this map to the actual files before editing — `PrettyChat.toc` is the source of truth for load order.

## Top-level Lua

| File | Responsibility |
|------|----------------|
| `PrettyChat.lua` | AceAddon entry. `OnInitialize` (DB + slash registration), `OnEnable` (snapshot Blizzard originals → `ApplyStrings`). Houses `ApplyStrings`, `Test`, the read helpers (`GetStringValue` / `IsAddonEnabled` / `IsCategoryEnabled` / `IsStringEnabled` / `EnsureCategoryDB`), `ResetCategory` / `ResetAll`, the ordered `COMMANDS` table that drives slash dispatch and `/pc help`, the file-local `ns.Print` helper used by every other file, and `ns.RenderSample(fmt)` shared with the panel's per-row sample line. |
| `Defaults.lua` | The `PrettyChatDefaults` global — canonical per-category format strings, labels, and per-category `enabled` flag. Single source of truth for what categories and strings exist. Eight categories with 81 format strings total (Loot 19, Currency 4, Money 8, Reputation 14, Experience 20, Honor 6, Tradeskill 8, Misc 2). |
| `Schema.lua` | Builds a flat `rows` array and `byPath` lookup from `PrettyChatDefaults` at file-load. Exposes `ns.Schema` — the **single write path** shared by slash commands and panel widgets. Owns `CATEGORY_ORDER` (the canonical display order, including the virtual `General`). See [schema.md](./schema.md). |
| `Constants.lua` | Layout constants on `ns.Const` (panel padding / header height / Defaults-button width / spacers). Side-effect-free; loads early so `Config.lua` can read `ns.Const.*` without an existence check. |
| `Config.lua` | Settings panel built directly on `Settings.RegisterCanvasLayoutCategory` / `RegisterCanvasLayoutSubcategory` with AceGUI body content. `buildGeneralBody` builds the virtual `General` page; `buildCategoryBody` + `buildStringRow` build each format-bearing page; `buildParentBody` renders the parent landing page. Overrides `ns.Schema.NotifyPanelChange` with a refresher dispatch. All widget callbacks delegate to `ns.Schema.Set/Get`. See [settings-panel.md](./settings-panel.md). |
| `GlobalStringSearch.lua` | Public search API over the `PrettyChatGlobalStrings` global (`EnsureLoaded` / `FindByKey` / `FindByValue` / `Find`). Loaded with the main addon. **Not currently consumed at runtime** — `Config.lua` reads `_G.PrettyChatGlobalStrings` directly for the panel's "Original" disabled input. Kept for future debug tooling. |

## GlobalStrings sub-tree

| Path | Purpose |
|------|---------|
| `GlobalStrings/GlobalStrings.lua` | Bundled Blizzard reference (~1.6 MB, ~22,879 entries). **Not loaded by any TOC** — only used as input to `split_globalstrings.py`. |
| `GlobalStrings/GlobalStrings_001.lua` … `_010.lua` | Chunk files. Each emits `PrettyChatGlobalStrings["KEY"] = "value"` assignments. Loaded *eagerly* by `PrettyChat.toc` and *also* packaged as a LoadOnDemand sub-addon — see [global-strings.md](./global-strings.md) for the dual-load story. |
| `GlobalStrings/GlobalStrings.toc` | LoD sub-addon TOC (`PrettyChat - GlobalStrings`, `LoadOnDemand: 1`). Loads the same chunks. |
| `GlobalStrings/split_globalstrings.py` | Splitter script. Re-run after a WoW patch updates `GlobalStrings.lua`; rewrites the chunk files and updates `GlobalStrings.toc`'s file list. |
| `GlobalStrings/README.md` | Splitter usage instructions (where to source the latest `GlobalStrings.lua`, how to regenerate). |

## Shared infrastructure

- `PrettyChat.toc` — Interface line (`120000, 120001, 120005`), version, SavedVariables (`PrettyChatDB`), and file load order. Order is dependency order, not alphabetical: Libs → GlobalStrings chunks → `Constants.lua` → `Defaults.lua` → `PrettyChat.lua` → `Schema.lua` → `Config.lua` → `GlobalStringSearch.lua`.
- `Libs/` — vendored Ace3 + LibStub. Tracked in git (standard WoW addon practice).
- `media/` — local copies of the logo + before/after screenshots. The README references CDN URLs, not these — they're kept around as source backups.
- `.gitattributes` — forces CRLF on disk for all text files (overrides per-user `core.autocrlf`).
- `.gitignore` — OS / editor cruft + `TODO.md` + `.claude/`.
- `LICENSE` — MIT.

## Top-level docs

- `README.md` — user-facing.
- `CLAUDE.md` — engineer working notes (hard rules + response style + doc index).
- `ARCHITECTURE.md` — design overview + invariants + doc index.
- `docs/*.md` — topic chunks (this file is one of them).
