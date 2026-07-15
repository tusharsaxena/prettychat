# Design — Tier-2 promotion + debug console + slash-§5 conformance

**Date:** 2026-07-14
**Addon:** Ka0s Pretty Chat
**Driver:** smoke-test feedback (D.10, E.11/12) after the 2026-07-12 standards audit.

## Goal

Three deliverables, one PrettyChat spec + one separate WowAddonStandards edit:

1. **Tier-2 promotion.** PrettyChat sits at exactly 8 source files (the Tier-1 ceiling). Adding
   a debug console file trips `tiered-layout-§1`'s "mandatory Tier 2 once >8". Promote to the
   modular layout (`core/ defaults/ locales/ modules/ settings/`).
2. **On-screen debug console** (`debug-logging` standard) — port AbsorbTracker's `core/DebugLog.lua`
   pattern: `700×344` DIALOG-strata `BackdropTemplate`, monospace `ScrollingMessageFrame`,
   `Debug: ON/OFF` header toggle, Copy/Clear, two pure formatters, session-only `ns.State.debug`
   routed through one `SetEnabled` seam. Replaces the current `debug-logging-§7` chat fallback.
3. **Slash `list`/`get`/`set` colour conformance** (`slash-commands-§5`) — green `33ff99`
   "Available settings" header, azure `3399ff` `[category]` group headers, gold `ffff00` key /
   white `ffffff` value via a shared `FormatKV` + schema-driven value formatter; drop trailing
   colons; add the mandated `version` verb.
4. **(separate repo) `options-ui-§2` rewrite** — mandate refuse-with-notice (PrettyChat's existing
   behaviour) in place of defer-and-replay.

## Section 1 — Tier-2 move-map (no behaviour change)

| New path | From | Change |
|---|---|---|
| `core/Compat.lua` | `Compat.lua` | move only |
| `core/Constants.lua` | `Constants.lua` | + `Const.FONT_MONO`, + `Const.Color.azure` |
| `core/Namespace.lua` | new | `ns.name`, `ns.version` bootstrap |
| `core/State.lua` | new | `ns.State = { debug = false }` (peeled from PrettyChat.lua:18) |
| `core/Util.lua` | new | `ns.Util.trim/note/cmd` (peeled locals) |
| `core/Database.lua` | `Database.lua` | move only |
| `core/DebugLog.lua` | new | the console (Phase 2) |
| `core/PrettyChat.lua` | `PrettyChat.lua` (part) | registration + `OnInitialize`/`OnEnable` + `ns.Print` + `OpenConfig` |
| `defaults/Defaults.lua` | `Defaults.lua` | move only |
| `locales/enUS.lua` | `Locale.lua` | move only |
| `modules/Override.lua` | `PrettyChat.lua` (part) | snapshot + `ApplyStrings` + enable-helpers + `RenderSample` + `Test` + reset |
| `settings/Schema.lua` | `Schema.lua` | + `Schema.FormatValue` (Phase 3) |
| `settings/Slash.lua` | `PrettyChat.lua` (part) | the `/pc` dispatcher |
| `settings/Panel.lua` | `Config.lua` | move only |

**Load order** (TOC + `tests/loader.lua`): libs → core (Compat, Constants, Namespace, State, Util,
Database, DebugLog, PrettyChat) → defaults/Defaults → locales/enUS → GlobalStrings chunks →
modules/Override → settings (Schema, Slash, Panel).

**Hard pins:** `settings/Schema.lua` executes at load and needs `:GetAddon("PrettyChat")` (from
`core/PrettyChat`'s `:NewAddon`) and `ns.Defaults` present → both precede it. AceAddon *methods*
(`ApplyStrings`, `IsAddonEnabled`, …) defined in `modules/Override` resolve at call-time, so they
only need to exist by `OnEnable`. `settings/Panel` keeps its runtime `ns.GlobalStrings` dependency
(GlobalStrings chunks precede `settings/`).

## Section 2 — Debug console

- Vendor `media/fonts/JetBrainsMono-Regular.ttf` + `OFL.txt` (copied from AbsorbTracker).
- `core/Constants.lua`: `Const.FONT_MONO = "Interface\\AddOns\\PrettyChat\\media\\fonts\\JetBrainsMono-Regular.ttf"`.
- `core/DebugLog.lua`: AT's `DebugLog` ported to `ns` / `[PC]` / `PrettyChatDebugWindow` /
  `PrettyChatDebugCopyWindow`. Title `"Pretty Chat — Debug"`. Colours per `debug-logging-§3`
  (ts `6f8faf`, tag `c9a66b`). `ns.Debug(tag, fmt, ...)` routes to `DebugLog:Add`, gated + zero-alloc
  when off. `DebugLog:SetEnabled` is the single seam (flag → header → chat ack → console line).
- **LSM deviation (flagged):** `debug-logging-§2` SHOULDs LSM registration; PrettyChat has no LSM
  vendored and no font-picker consumer, so the font is applied via the direct `FONT_MONO` path only,
  with a code comment. Documented SHOULD-deviation.
- `settings/Slash.lua` `runDebug`: `/pc debug` toggles the window; `on`/`off` set the flag via
  `SetEnabled`.
- Test-mock additions (`tests/wow_mock.lua`): `env.date`, `env.wipe`, `env.UISpecialFrames`.
- New `tests/test_debuglog.lua`: the two pure formatters + the `/pc debug on|off|toggle` seam.

## Section 3 — slash-§5 conformance

- `settings/Schema.lua`: `Schema.FormatValue(row, v)` — type-aware, schema-driven (bool → `true`/`false`,
  string → the raw format string). Shared by `list` and `get`/`set`.
- `settings/Slash.lua`: `FormatKV(path, valueStr)` (gold key / white value). `listSettings` prints
  green `Available settings`, azure `[Category]`, indented `FormatKV` rows. `get`/`set` echo the
  single-line `FormatKV`. Drop all trailing colons. Add `version` verb → `[PC] v<version>`.
- **Colour deviation (flagged):** §5 mandates header green `33ff99` (distinct from the brand
  `Const.Color.green` `40ff40`) and azure `3399ff`; both added as `Const.Color` entries and used
  verbatim per the MUST.

## Section 4 — options-ui-§2 rewrite (WowAddonStandards)

Rewrite §2 "Combat lockdown" to mandate: check `InCombatLockdown()` before opening the panel; on
lockdown **refuse** and print a `NS.PREFIX` grey notice — canonical text
"cannot open settings during combat — Blizzard's category-switch is protected" — rather than
deferring with a `PLAYER_REGEN_ENABLED` replay. PrettyChat becomes the described reference impl.
**Ripple flagged:** AbsorbTracker currently defers-and-replays and would become non-conformant — a
follow-up, not done in this change.

## Test gate

`lua tests/run.lua` green + `luacheck .` clean after every phase.
