# CLAUDE.md

**Ka0s Pretty Chat** — a WoW addon that reformats system chat messages by overriding Blizzard's `GlobalStrings.lua` format strings (not by parsing chat events).

- **Tier:** Tier 1 (flat). All source `.lua` lives at the repo root; libraries are vendored under `libs/`.
- **Standard:** built to the [Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards).
- **Exception to §1.1 (flat tier):** `GlobalStrings/` is a **deliberate generated-data subfolder** — 10 machine-generated chunk files (~22,879 Blizzard reference strings) plus the source dump and `split_globalstrings.py` splitter. It is kept nested (not flattened to root) as a documented generated-data exception; regenerate with `python3 GlobalStrings/split_globalstrings.py`.
- **Deliberate deviation from §2.1 (TOC branding):** the `## Title:` keeps its rainbow `|cRRGGBB…|r` colour escapes and `## Author:` keeps its stylised `aDd1kTeD2Ka0s` casing — both are the addon's brand mark, kept intentionally rather than plain-texted/normalised to the standard's `Ka0s Pretty Chat` / `add1kted2ka0s`. `## X-Wago-ID` is intentionally omitted until a real Wago id is available (do not commit a placeholder).

## Before touching code

Read **[docs/agent-context.md](./docs/agent-context.md)** — the full working brief: hard rules (single write path, master toggle, `ns.L` localization, cyan `[PC]` prefix), the namespace publishing table, and the test gate. Design overview + invariants live in **[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)**; user-facing reference in **[README.md](./README.md)**.

## Non-negotiable guardrails

- **Test gate.** After every change, `lua tests/run.lua` must be green and `luacheck .` clean.
- **Never auto-stage, auto-commit, or auto-push.** Leave edits as unstaged working-tree changes unless explicitly told otherwise (the `/wow-addon:commit` skill is the exception — it runs its own confirmation gate).
- **Never bump the version** (`## Version:` in `PrettyChat.toc`, README badges/changelog) without an explicit instruction.
