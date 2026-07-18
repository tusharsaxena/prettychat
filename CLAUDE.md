# CLAUDE.md — Ka0s Pretty Chat

**Ka0s Pretty Chat** — a WoW addon that reformats system chat messages by overriding Blizzard's `GlobalStrings.lua` format strings (not by parsing chat events).

- **Layout:** modular — source `.lua` lives under `core/`, `defaults/`, `locales/`, `modules/`, `settings/`; libraries are vendored under `libs/`. This is the single Ka0s layout (`layout-§1`), used by every addon regardless of size.
- **Standard:** built to the [Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards) (`standards/STANDARDS.md` in that repo). The most recent compliance audit + remediation is frozen under [docs/audits/2026-07-12/](./docs/audits/2026-07-12/) (that audit predates the modular restructure and the v2.0.0 standard; re-audit with `/wow-addon:standards-audit`). **Accepted, deliberate deviations are recorded as bullets in this file** (see the generated-data and toc-file-§1 TOC-branding exceptions below) — that list is the source of truth for what intentionally diverges.
- **Generated-data exception (`layout`):** `GlobalStrings/` is a **generated-data folder at the repo root** — 10 machine-generated chunk files (~22,879 Blizzard reference strings) plus the source dump and `split_globalstrings.py` splitter. The modular layout has no home for bulk generated reference data, so it stays a documented root exception (loaded after `defaults/`, before `modules/`); regenerate with `python3 GlobalStrings/split_globalstrings.py`.
- **Accepted deviation — debug-console font (`debug-logging-§2`):** the on-screen debug console (`core/DebugLog.lua`) ships its monospace font (JetBrains Mono, OFL, under `media/fonts/`) and applies it via the `Const.FONT_MONO` path directly, **without** LibSharedMedia registration. This is a **deliberate design choice, not an oversight**: the debug console is intentionally fixed-monospace (readability of aligned log output does not depend on player taste), and PrettyChat ships **no font/texture/border picker** anywhere — every other font, texture, and border in the addon is a Blizzard default (see the 2026-07-17 media audit), so LSM has no consumer surface and the path constant alone suffices. Not to be "fixed" by adding LSM unless a user-facing media picker is deliberately introduced.
- **Deliberate deviation from toc-file-§1 (TOC branding):** the `## Title:` keeps its rainbow `|cRRGGBB…|r` colour escapes and `## Author:` keeps its stylised `aDd1kTeD2Ka0s` casing — both are the addon's brand mark, kept intentionally rather than plain-texted/normalised to the standard's `Ka0s Pretty Chat` / `add1kted2ka0s`. `## X-Wago-ID` is intentionally omitted until a real Wago id is available (do not commit a placeholder).
- **TOC section order (`toc-file-§5`) — standard-internal conflict, resolved in favour of section order:** the TOC file-listing follows `toc-file-§5` — `# Locales` sits immediately after `# Libraries` (`locales/enUS.lua` only builds `ns.L` and has no earlier-load dependency, so loading it first is safe). This is in **tension with `layout-§1`'s load-order list** (`defaults → locales`), which would place Locales after Defaults; the two standard rules disagree on where Locales belongs. Resolved here toward `toc-file-§5` — **raise upstream** against WowAddonStandards to reconcile the two. The non-canonical `# GlobalStrings` section is simply the TOC home of the generated-data root exception noted above.

## Standards compliance (read first)

This repo is built to the **Ka0s WoW Addon Standard**
(https://github.com/tusharsaxena/WowAddonStandards). All development here — features, refactors,
doc changes — MUST conform to it. The standard is the source of truth for layout, TOC shape, the
Ace substrate, schema-driven settings, slash/prefix conventions, locales, Compat, tests/lint, and
doc structure.

**If a change would deviate from the standard, STOP and flag the deviation explicitly.** Do not
silently deviate and do not silently "fix" to match. Surface it and let the user decide which of
two things it is:

1. **An accepted deviation** — this addon intentionally differs; record it as a documented
   deviation (e.g. in the TOC/README/`docs/` and in the audit bundle), with the reason.
2. **A change to the standard itself** — the standard's definition should evolve; the update
   belongs upstream in the WowAddonStandards repo, after which this addon conforms to the new rule.

When in doubt, treat standard conformance as a hard requirement and ask.

## Before touching code

Read **[docs/agent-context.md](./docs/agent-context.md)** — the full working brief: hard rules (single write path, master toggle, `ns.L` localization, cyan `[PC]` prefix), the namespace publishing table, and the test gate. Design overview + invariants live in **[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)**; user-facing reference in **[README.md](./README.md)**.

## Non-negotiable guardrails

- **Standards compliance — flag every deviation.** This addon conforms to the Ka0s WoW Addon Standard (linked above); new work must stay conformant. **If any change would deviate from the standard — a new file loose at the repo root instead of under its `core/`/`settings/`/… folder, a TOC field out of canonical order, a skipped test gate, a non-standard naming choice, anything — do NOT silently proceed. Stop and flag the deviation to the user**, and let them decide which of two things it is:
  1. **an accepted deviation** — the addon intentionally diverges; record it as a documented bullet in this file (like the layout-§1 / toc-file-§1 exceptions above), *or*
  2. **a signal the standard itself should change** — raise it against the [WowAddonStandards](https://github.com/tusharsaxena/WowAddonStandards) repo so the standard definition is updated.

  Never resolve the choice yourself, and never quietly conform-or-diverge without surfacing it.
- **Test gate.** After every change, `lua tests/run.lua` must be green and `luacheck .` clean.
- **Keep the test-case inventory & badge in sync (`testing-§5`).** When the suite changes — a case added/removed/renamed or the pass count moves (i.e. whenever a failing test is resolved) — regenerate `docs/test-cases.md` via `lua tests/run.lua --list` **and** update the README `Tests` badge count **in the same change**, not as a follow-up. `docs/test-cases.md` is generated (never hand-edited) and is the authoritative pass count.
- **Static README badges track their source of truth (`documentation-§1`).** The `[WoW]` and `[Tests]` badges are static shields.io images that go stale silently: `[WoW]` ↔ TOC `## Interface:` (they MUST show the same number — bump both together on every client-patch bump); `[Tests]` ↔ the regenerated `docs/test-cases.md` total (rule above). Update the badge in the **same change** that moves its source, never as a follow-up.
- **Never auto-stage, auto-commit, or auto-push.** Leave edits as unstaged working-tree changes unless explicitly told otherwise (the `/wow-addon:commit` skill is the exception — it runs its own confirmation gate).
- **Never bump the version** (`## Version:` in `PrettyChat.toc`, README badges/changelog) without an explicit instruction.
