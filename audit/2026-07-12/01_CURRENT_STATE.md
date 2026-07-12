# 01 — Current State

**Addon:** Ka0s Pretty Chat (folder `prettychat/`, TOC `PrettyChat.toc`)
**Audit date:** 2026-07-12
**Audited against:** Ka0s WoW Addon Standard **v1.0.0 (2026-07-12)** — `standards/01_STANDARD.md` @ `github.com/tusharsaxena/WowAddonStandards`
**Playbook:** `AUDIT.md` (same repo)
**Deviation-ID prefix:** `PC-` (first standards-audit for this addon; `reviews/2026-05-02/` was a code-review bundle, not a standards-audit, so no prior audit IDs to reuse)

This is a read-only snapshot of what the addon does today, walked section-by-section against the standard. Gaps are catalogued in `02_DEVIATIONS.md`; evidence in `03_EVIDENCE.md`.

---

## Overview

Pretty Chat reformats WoW system chat (loot, currency, money, reputation, XP, honor, tradeskill, misc) by **overriding Blizzard `GlobalStrings.lua` format strings** in `_G` rather than parsing chat events — architecturally taint-free (§9.5 reference pattern). Settings are exposed through a Blizzard Settings canvas landing-page + per-category subcategories, plus a schema-driven `/pc` slash CLI. Both surfaces route every mutation through one write path (`ns.Schema.Set`).

## Tier & layout (§1)

- **Tier:** Effectively **Tier 1 (flat)** — 5 hand-written source files at root (`PrettyChat.lua`, `Schema.lua`, `Config.lua`, `Constants.lua`, `Defaults.lua`) plus a `GlobalStrings/` subfolder of 10 generated data chunks + eager loader. Tier is **not declared** in `CLAUDE.md`.
- Root source files are flat; **`GlobalStrings/` is a source subfolder** holding TOC-loaded `.lua` (generated data).
- Library folder is **`Libs/`** (PascalCase), not lowercase `libs/`.
- Media: everything (logo `.tga/.jpg/.png` + screenshots) lives loose under `media/screenshots/`; there is **no `media/logos/`**.
- All files well under the 1500-LOC cap (largest: `Config.lua` 652, `PrettyChat.lua` 614).

## TOC (§2)

`PrettyChat.toc` declares `## Interface: 120007` (single, current Retail — good), `## Title:` (rainbow colour escapes), `## Version: 1.3.0`, `## Author: aDd1kTeD2Ka0s`, `## Notes:`, `## iconTexture: 2056011`, `## SavedVariables: PrettyChatDB`, `## DefaultState: enabled`, `## Category-enUS: Chat & Communication`, `## X-License: MIT`.

- Field **order departs** from §2.1 (Notes should precede Author; Version follows Author; `iconTexture` should be `IconTexture`).
- **Missing** `## OptionalDeps:`, `## X-Standard:`, and — though the addon is published (CurseForge badge, project 919766) — `## X-Curse-Project-ID:` and `## X-Wago-ID:`.
- File listing loads libs first then data then source, but uses **no `#` section-header comments** (§2.5).
- No hard `## Dependencies:` (good). Single Interface line, no multi-flavor fan-out (good).

## Libraries (§3)

Vendored & committed under `Libs/`: LibStub, CallbackHandler-1.0, AceAddon-3.0, AceDB-3.0, AceConsole-3.0, AceGUI-3.0 — plus **AceConfig-3.0 which is vendored but never loaded or `LibStub`'d** (no Profiles page). No `.pkgmeta externals:` (good). AceEvent/AceTimer are neither vendored nor used (acceptable — the addon registers no events/timers).

## Architecture (§4)

- Namespace bootstrap `local addonName, ns = ...` in every file (lowercase `ns`, standard uses `NS`).
- AceAddon registration in `PrettyChat.lua`; other files fetch the addon via `GetAddon("PrettyChat")`.
- **`PrettyChatDefaults` and `PrettyChatGlobalStrings` are created as raw `_G` globals**, not held on `ns`.
- **Schema-as-single-source is implemented well** (§4.5): `ns.Schema` rows drive AceDB defaults, panel widgets, and `/pc get|set|list|reset|resetall`; `Schema.Set` is the sole write path and owns the `ApplyStrings()` + `NotifyPanelChange()` side effects. **No boot-time path-vs-defaults validation** is performed.

## SavedVariables / AceDB (§5)

`PrettyChatDB` single global via `AceDB:New`. Defaults live in `PrettyChat.lua` (`categories = {}`) and `Defaults.lua`. **No `schemaVersion`** anywhere; **no `Database.lua` migration runner**.

## Options UI (§6)

Canonical pattern followed closely: `Settings.RegisterCanvasLayoutCategory` + `RegisterCanvasLayoutSubcategory` (not deprecated `InterfaceOptions_AddCategory`), raw AceGUI content, lazy body build in first `OnShow`, landing page with logo + tagline + `COMMANDS`-generated slash list, breadcrumb header with atlas chevron, always-visible-scrollbar patch (§6.10), combat-lockdown guard on panel open (§6.2). Registration happens eagerly in `OnEnable` (after `Blizzard_Settings` — taint-safe). Layout constants centralised in `Constants.lua`. **Deviations:** per-string editor uses a bespoke 40/60 three-row layout rather than the §6.6 schema-driven 50/50 two-column grid; paired action buttons use `SetRelativeWidth(0.5)` rather than `BUTTON_PAIR_REL` (0.492).

## Slash (§7)

AceConsole `/pc` + `/prettychat` alias. Ordered `COMMANDS` table drives dispatch and help (no if/elseif chain). `help`, `config`, `list`, `get`, `set`, `reset`, `resetall`, `test` all present; unknown verb prints help. Bare `/pc` prints help. Chat output centralised through `ns.Print` which prepends the cyan `[PC]` tag — but the tag is a **file-local `PREFIX`**, not a shared `NS.PREFIX` constant.

## Localization (§8)

**None.** No `Locale.lua` / `locales/`, no `ns.L` metatable. All user-facing strings are hardcoded English inline in `Config.lua` / `PrettyChat.lua`.

## Events / frames / taint (§9)

Overrides `_G[GLOBALSTRING]` instead of hooking chat events — the §9.5 reference pattern (compliant, taint-free). **But** `ApplyStrings` iterates `pairs(PrettyChatDefaults)`, so cross-registered globals (e.g. `LOOT_ITEM_CREATED_SELF` under both Loot and Tradeskill) resolve **non-deterministically** (last-writer-wins) — the code even documents the conflict in `Schema.crossRegisteredGlobals` but does not order the apply.

## Compat (§11)

**No `Compat.lua`.** `C_AddOns.GetAddOnMetadata` is called directly (inline-guarded) in `PrettyChat.lua` and `Config.lua`.

## Debug / logging (§12)

**No debug seam** — no `ns.Debug` sink, no console, no gated logging flag. (As a Tier-1 addon with no main window, §12.7 permits a `PREFIX`-tagged chat fallback, but a debug seam must still exist.)

## Packaging / lint / tests (§13/§14/§14A)

**No `.pkgmeta`, no `.luacheckrc`, no `tests/` harness.** No headless test coverage of the schema, sample-renderer, or apply pipeline.

## Docs (§15)

Root ships `README.md` (full, near-canonical), `LICENSE` (MIT), `ARCHITECTURE.md` (**at root — should live in `docs/`**), and `CLAUDE.md` which is the **full agent brief, not a stub**. `docs/` holds nine topic files but **no `docs/ARCHITECTURE.md`**. README is missing a **standards link** in the badge row, has a non-canonical `## Notes` section, and lacks a **`## Testing`** section. A `TODO.md` exists on disk but is **git-ignored (untracked)** — not shipped.

## Versioning (§17)

Semver `1.3.0` in TOC + README Version History table (in lockstep). No `schemaVersion` to increment (see §5).
</content>
</invoke>
