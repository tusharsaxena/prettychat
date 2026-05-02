# Scope

What's in scope, what's out, and the resolved decisions that shaped the contract. The contract itself (formatted chat output, panel UX, slash UX) is documented in [README.md](../README.md) — this doc records the *boundary* decisions so a fresh contributor can tell whether a feature request is in or out of scope without re-litigating it.

## In scope

- **GlobalString overrides** for system chat lines — loot, currency, money, reputation, experience, honor, tradeskill, and a small Misc bucket. Format strings come from `Defaults.lua`; per-string user overrides live in SavedVariables.
- **Three enable layers** — addon-wide master toggle → per-category toggle → per-string toggle. Disabled strings revert to the captured Blizzard original at runtime.
- **Settings panel** integrated into Blizzard's AddOns settings, one sub-page per category (no right-pane tabs), with a virtual `General` sub-page for the master switch / Test / Reset All controls.
- **Schema-driven slash CLI** (`/pc list / get / set / reset / resetall / test`) sharing one write path with the panel. Every panel-shaped operation is reachable from chat by dot path.
- **Live preview** in the panel (renders the format with sample arguments substituted in) and a `/pc test` / Test-button preview that walks every format regardless of enable state.
- **Compatibility with any chat UI** (default Blizzard, ElvUI, Glass, …) by overriding `_G[GLOBALNAME]` rather than hooking chat events.

## Out of scope

These have been considered and explicitly declined. A change of heart needs an issue + design discussion, not a stealth PR.

- **Per-message rewriting / chat event hooks.** Everything routes through Blizzard's `string.format(_G[GLOBALNAME], ...)` path; the addon never sees individual messages.
- **Localization plumbing for the default formats.** The shipped defaults are English. Users on other locales can rewrite any format from the panel — the override is stored verbatim — but the addon doesn't ship per-locale defaults.
- **Per-character / per-class / per-realm profile UI.** AceDB is initialized with a single shared `Default` profile (`db = AceDB:New("PrettyChatDB", defaults, true)`). `AceDBOptions-3.0` is *not* wired in. Adding it is a small contribution if demand emerges — see [schema.md](./schema.md#profiles).
- **Reordering / renaming categories.** The category set and display order live in `Schema.CATEGORY_ORDER`; the eight format-bearing categories mirror `PrettyChatDefaults`'s top-level keys.
- **A "minimal" preset, themes, or palette swap.** The color palette is part of the default-format strings; users edit individual formats to recolor.
- **Editing format strings via slash with raw `|`.** WoW chat input interprets `|c…|r` as inline color escapes the moment Enter is pressed. `/pc set ... <format>` requires double `||`. The settings panel is the recommended editing surface; chat-side editing is a power-user fallback.

## Resolved decisions

Decisions made during requirements review and v1.x.x — these are settled, not open.

- **Master toggle wins.** When `General.enabled` is false, `ApplyStrings` restores every Blizzard original regardless of per-category and per-string state. Customizations stay in the database, just unapplied.
- **Three enable layers, evaluated in order.** addon → category → per-string. A string only renders with the user's format if all three are on. See [override-pipeline.md](./override-pipeline.md).
- **Single shared profile.** `AceDB:New(..., true)` selects the `Default` profile for every character. No profile switcher in the panel.
- **One sub-page per category.** Categories register as `AceConfigDialog:AddToBlizOptions(appName, displayName, PARENT_TITLE)`, nesting them under the parent in the addon list. Chosen over a right-pane tab strip so each category gets the full pane width for the side-by-side Original/New edit boxes.
- **`General` is a virtual category.** No entry in `PrettyChatDefaults`; built by a dedicated `BuildGeneralOptions()` and stored as `db.profile.enabled` at the profile root (not under `db.profile.categories`). It owns the addon-wide toggle, Test, and Reset All.
- **Single write path through `Schema.Set`.** Both AceConfig widget set-callbacks and `/pc set` go through the same row's `set()` closure. Panel and slash never drift.
- **Auto-clear on default match.** For `string_format` rows, writing the value back to the PrettyChat default clears the override entry instead of storing a duplicate. `db.profile.categories[Cat].strings` never collects "override that happens to equal the default".
- **Format-specifier signatures must match Blizzard's.** Each Blizzard string has a fixed signature (`%s`, `%d`, `%.1f`, `%2$s`, …); replacements must consume the same conversions in the same order or `string.format` errors at runtime. The panel's left edit box always shows Blizzard's exact original — copy from there.
- **`/pc config` refuses during combat.** Blizzard's category-switch is protected; opening it under combat lockdown taints the panel.
- **Cyan `[PC]` chat prefix on all addon output.** Every chat line goes through `ns.Print(msg)` in `PrettyChat.lua`, which prepends `|cff00ffff[PC]|r `. The one intentional exception is `Test()`'s sample lines themselves — emitted unprefixed so each preview looks identical to a real chat message; only the header/footer carry the prefix.

## Where the contract lives

- User-facing behavior: [README.md](../README.md) — categories, slash command table, FAQ, troubleshooting.
- Engineer working notes: [../CLAUDE.md](../CLAUDE.md) — hard rules, response style, working environment.
- High-level architecture map: [../ARCHITECTURE.md](../ARCHITECTURE.md).
