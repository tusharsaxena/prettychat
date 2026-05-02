# Settings panel

`Config.lua` builds the AceConfig options tables and registers them with Blizzard's Settings panel. PrettyChat appears under **Ka0s Pretty Chat**; the parent page hosts only a description, and nine sub-pages hold the actionable controls — one per category (`General`, Loot, Currency, Money, Reputation, Experience, Honor, Tradeskill, Misc).

This doc covers: the sub-page registration trick, the virtual `General` page, the per-string row layout, the Test button, and the color palette.

## Sub-pages instead of right-pane tabs

Each category is registered as its own AceConfig options table (`PrettyChat_<Cat>`) and added to the Blizzard panel via:

```lua
AceConfigDialog:AddToBlizOptions(appName, displayName, PARENT_TITLE)
```

The third argument (`PARENT_TITLE = "Ka0s Pretty Chat"`) nests the entry under the parent in the addon list. Each category renders as a sibling row beneath the parent, gets the full right-pane width to itself, and there's no tab strip in the right pane. The parent page itself hosts only a description — no actionable buttons.

The parent must register *before* the children, because `AddToBlizOptions(_, _, parent)` looks up the parent by display name. That's why `Config.lua` calls `AceConfig:RegisterOptionsTable("PrettyChat", parentOptions)` and `AceConfigDialog:AddToBlizOptions("PrettyChat", PARENT_TITLE)` first, then loops through `CATEGORY_ORDER`.

`PrettyChat.subFrames[category]` stores the frame returned by `AddToBlizOptions` for each sub-page. Currently unused at runtime, but available for a future `/pc config <Category>` direct-jump.

## The virtual `General` sub-page

`General` is a *virtual category* — no entry in `PrettyChatDefaults`, no per-string rows. It's built by a dedicated `BuildGeneralOptions()` (separate from the format-string `BuildCategoryOptions` path) and hosts every actionable addon-wide control:

| Control | Wire-up |
|---------|---------|
| **Enable PrettyChat** toggle | Bound to the `General.enabled` schema row. Master switch — when off, every Blizzard original is restored. |
| **Test** button | Calls `PrettyChat:Test()`. Synthesizes a sample chat line from every format string regardless of enable toggles, so the preview works even when the addon is disabled. See below. |
| **Reset All to Defaults** button | Confirm-popup-gated (`confirm = true`, `confirmText = "Reset ALL PrettyChat strings to defaults?"`). Calls `PrettyChat:ResetAll()`. |

Reset All used to live on the parent page and was moved here so every actionable control lives one click in from the addon list.

## Per-category sub-pages

Each format-bearing category sub-page is built by `BuildCategoryOptions(category, catData)` and contains:

1. An **Enable `<Category>`** toggle at the top, bound to the `<Cat>.enabled` schema row.
2. A **Reset `<Category>`** button (confirm-popup-gated) that calls `PrettyChat:ResetCategory(category)`.
3. A spacer.
4. One 12-widget block per format string in `catData.strings`.

The 12-widget block is the visual unit — see below.

## Per-string row layout (12 widgets)

`BuildStringEntry(group, globalName, strData, category, i)` populates twelve AceConfig args per string (increment = 12, so `i = 10, 22, 34, …`):

| Order | Key suffix | Type | Width | Font | Content |
|-------|-----------|------|-------|------|---------|
| i | `_spacer_top` | description | full | — | `"\n"` spacer |
| i+1 | `_toggle` | toggle | 0.4 | — | "Enable" checkbox |
| i+2 | `_toggle_label` | description | 2.0 | large | Gold `strData.label` |
| i+3 | `_toggle_globalname` | description | full | small | White `globalName` |
| i+4 | `_original_label` | description | relWidth 0.5 | medium | Gold "Original Format String" |
| i+5 | `_format_label` | description | relWidth 0.5 | medium | Gold "New Format String" |
| i+6 | `_original` | input | relWidth 0.5 | — | Disabled edit box — Blizzard original from `_G.PrettyChatGlobalStrings[NAME]` |
| i+7 | *(globalName)* | input | relWidth 0.5 | — | Editable format box (escapes `\|` → `\|\|` for raw editing; unescapes on save) |
| i+8 | `_preview_label` | description | full | medium | Gold "Preview" |
| i+9 | `_preview` | input | full | — | Disabled edit box — rendered preview |
| i+10 | `_spacer_bottom` | description | full | — | `"\n"` spacer |
| i+11 | `_hr` | header | — | — | Horizontal rule separator |

### The width semantics gotcha

In AceConfig, a numeric `width = N` is `N × 170 px` **absolute**. A *percentage* of the row requires `width = "relative", relWidth = N`. The Original / New side-by-side rows use:

```lua
width = "relative", relWidth = 0.5
```

A naive `width = 0.5` would render as `0.5 × 170 = 85 px` absolute, which is roughly half a row at narrow widths and a tiny strip at wide ones — not what you want.

### Edit-box pipe escaping

The format input's `get` / `set` wrap the `||` ↔ `|` escaping at the UI boundary so users see double-escaped strings while editing but `ns.Schema` always stores raw single-`|` format strings:

```lua
get = function() return ns.Schema.Get(formatPath):gsub("|", "||") end,
set = function(_, val) ns.Schema.Set(formatPath, val:gsub("||", "|")) end,
```

This matters because WoW's chat input interprets `|c…|r` as inline color escapes the moment Enter is pressed, so a raw `|` in the edit box would be eaten. The disabled "Original" input does **not** wrap (it's read-only — the user never sends it back through chat input). `/pc set` users have to type `||` themselves; see [slash-commands.md](./slash-commands.md#edit-box-pipe-escaping).

## The Test preview

Both the General sub-page's "Test" button and the `/pc test` slash command call `PrettyChat:Test()` (in `PrettyChat.lua`). The function:

1. Iterates every format string in every category — **regardless of master / per-category / per-string enable toggles**. That's intentional: the preview is for *seeing what your formats look like*, not for verifying which ones are currently applied to live chat.
2. For each string, calls `buildSampleArgs(fmt)` — parses `%[flags][width][.precision]type` conversions and produces typed placeholders (`"Sample"` for `%s`, `42` for integer types, `1.5` for floats, `65` for `%c`, `"?"` for unknowns). `%%` escapes are stripped first.
3. `pcall(string.format, fmt, unpack(args))` — a malformed format won't break the loop; it just gets skipped.
4. Emits each sample line via `DEFAULT_CHAT_FRAME:AddMessage` **without** the `[PC]` prefix, so each rendered preview looks identical to a real loot/currency/XP chat message.
5. Header and footer carry the `[PC]` prefix, bracketing the test block. Header includes a notice when `IsAddonEnabled()` is false. Footer reports the printed count (`"end of test output (N strings shown)"`).

## Color palette

The default formats in `Defaults.lua` use this palette. Edit `Defaults.lua` directly if you want to add a category or shift a hue.

| Color (`ff…`) | Usage |
|--------------|-------|
| `ff0000` | Loot category label |
| `ff9900` | Currency category label |
| `ffff00` | Money category label |
| `00ff00` | Reputation category label |
| `00ffff` | Experience category label; also the `[PC]` chat-output prefix |
| `4a86e8` | Honor category label |
| `ff00ff` | Tradeskill category label |
| `93c47d` | "You" / self-referencing |
| `f6b26b` | Other player names / sources |
| `76a5af` | Bonus / Standing context |
| `e06666` | Negative / Refund / Lost |
| `cccccc` | Generic / secondary labels |
| `ffffff` | Default / value text |
| `ffd700` | Gold (panel-only — the panel's section labels and the `MakeLabel` helper use this) |

WoW color escapes use `|cAARRGGBB...|r` (AA = alpha, always `ff`). The house style for new defaults is `Category | Context | Source | +/- value`, each segment color-coded.
