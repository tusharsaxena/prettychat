# CLAUDE.md

**Ka0s Pretty Chat** — a WoW addon that reformats system chat messages by overriding Blizzard's `GlobalStrings.lua` format strings (not by parsing chat events).

- **Tier:** Tier 2 (modular). Source `.lua` lives under `core/`, `defaults/`, `locales/`, `modules/`, `settings/`; libraries are vendored under `libs/`. (Promoted from Tier 1 on 2026-07-14 when the on-screen debug console became the 9th source file, past the Tier-1 ≤8-file ceiling — `tiered-layout-§1` makes promotion mandatory at that point.)
- **Standard:** built to the [Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards) (`standards/STANDARDS.md` in that repo). The most recent compliance audit + remediation is frozen under [docs/audits/2026-07-12/](./docs/audits/2026-07-12/) (that audit predates the Tier-2 promotion; re-audit with `/wow-addon:standards-audit`). **Accepted, deliberate deviations are recorded as bullets in this file** (see the generated-data and §2.1 TOC-branding exceptions below) — that list is the source of truth for what intentionally diverges.
- **Generated-data exception (`tiered-layout`):** `GlobalStrings/` is a **generated-data folder at the repo root** — 10 machine-generated chunk files (~22,879 Blizzard reference strings) plus the source dump and `split_globalstrings.py` splitter. The tiered layout has no home for bulk generated reference data, so it stays a documented root exception (loaded between `locales/` and `modules/`); regenerate with `python3 GlobalStrings/split_globalstrings.py`.
- **SHOULD-deviation (`debug-logging-§2`):** the on-screen debug console (`core/DebugLog.lua`) ships its monospace font (JetBrains Mono, OFL, under `media/fonts/`) and applies it via the `Const.FONT_MONO` path directly, **without** LibSharedMedia registration — PrettyChat ships no font-picker consumer, so the path constant alone suffices.
- **Deliberate deviation from §2.1 (TOC branding):** the `## Title:` keeps its rainbow `|cRRGGBB…|r` colour escapes and `## Author:` keeps its stylised `aDd1kTeD2Ka0s` casing — both are the addon's brand mark, kept intentionally rather than plain-texted/normalised to the standard's `Ka0s Pretty Chat` / `add1kted2ka0s`. `## X-Wago-ID` is intentionally omitted until a real Wago id is available (do not commit a placeholder).

## Before touching code

Read **[docs/agent-context.md](./docs/agent-context.md)** — the full working brief: hard rules (single write path, master toggle, `ns.L` localization, cyan `[PC]` prefix), the namespace publishing table, and the test gate. Design overview + invariants live in **[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)**; user-facing reference in **[README.md](./README.md)**.

## Non-negotiable guardrails

- **Standards compliance — flag every deviation.** This addon conforms to the Ka0s WoW Addon Standard (linked above); new work must stay conformant. **If any change would deviate from the standard — a new file placed off-tier, a TOC field out of canonical order, a skipped test gate, a non-standard naming choice, anything — do NOT silently proceed. Stop and flag the deviation to the user**, and let them decide which of two things it is:
  1. **an accepted deviation** — the addon intentionally diverges; record it as a documented bullet in this file (like the §1.1 / §2.1 exceptions above), *or*
  2. **a signal the standard itself should change** — raise it against the [WowAddonStandards](https://github.com/tusharsaxena/WowAddonStandards) repo so the standard definition is updated.

  Never resolve the choice yourself, and never quietly conform-or-diverge without surfacing it.
- **Test gate.** After every change, `lua tests/run.lua` must be green and `luacheck .` clean.
- **Keep the test-case inventory & badge in sync (`testing-§5`).** When the suite changes — a case added/removed/renamed or the pass count moves (i.e. whenever a failing test is resolved) — regenerate `docs/test-cases.md` via `lua tests/run.lua --list` **and** update the README `Tests` badge count **in the same change**, not as a follow-up. `docs/test-cases.md` is generated (never hand-edited) and is the authoritative pass count.
- **Static README badges track their source of truth (`documentation-§1`).** The `[WoW]` and `[Tests]` badges are static shields.io images that go stale silently: `[WoW]` ↔ TOC `## Interface:` (they MUST show the same number — bump both together on every client-patch bump); `[Tests]` ↔ the regenerated `docs/test-cases.md` total (rule above). Update the badge in the **same change** that moves its source, never as a follow-up.
- **Never auto-stage, auto-commit, or auto-push.** Leave edits as unstaged working-tree changes unless explicitly told otherwise (the `/wow-addon:commit` skill is the exception — it runs its own confirmation gate).
- **Never bump the version** (`## Version:` in `PrettyChat.toc`, README badges/changelog) without an explicit instruction.
