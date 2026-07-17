# Settings panel

`settings/Panel.lua` builds the settings panel directly on Blizzard's modern `Settings.RegisterCanvasLayoutCategory` / `Settings.RegisterCanvasLayoutSubcategory` API and renders body content with AceGUI. PrettyChat appears under **Ka0s Pretty Chat**; the parent page hosts the logo, tagline, and slash-command list (read-only orientation), and nine sub-pages hold the actionable controls — one per category (`General`, Loot, Currency, Money, Reputation, Experience, Honor, Tradeskill, Misc).

This doc covers: the canvas-layout framework, the unified per-page header, the virtual `General` sub-page, the per-string row, the Test button, and the color palette.

## Canvas-layout framework

`settings/Panel.lua` doesn't go through `AceConfigDialog:AddToBlizOptions` (the older path that auto-renders an AceConfig options table inside the addon's right pane). It builds plain Blizzard `Frame`s for each page, stamps a unified header on each, and uses an AceGUI `ScrollFrame` for the body content. Every category (parent + sub-pages) shares the same header design and right-edge gutter, and the body is laid out the same way on every page.

Registration order from `registerPanels()`:

```lua
Settings.RegisterCanvasLayoutCategory(parentPanel, "Ka0s Pretty Chat")
Settings.RegisterAddOnCategory(mainCategory)        -- adds to the addon list

for _, category in ipairs(CATEGORY_ORDER) do
    Settings.RegisterCanvasLayoutSubcategory(mainCategory, subPanel, category)
end
```

`PrettyChat.optionsCategoryID = mainCategory:GetID()` is what `PrettyChat:OpenConfig()` passes to `Settings.OpenToCategory`. `PrettyChat.optionsCategory` (the category object itself) is what `expandMainCategory` walks for the left-tree disclosure toggle.

`settings/Panel.lua` exposes `ns.Config.RegisterPanels`; `PrettyChat:OnEnable` calls it after the snapshot/`ApplyStrings` pair. AceGUI body rendering is **deferred until the panel's first `OnShow`** — at registration time the body's frame width is zero, and AceGUI's `List` layout sizes children against the container's current width, so building too early produces a stack of misaligned widgets.

## Unified per-page header

`buildHeader(panel, title, opts)` stamps every page with the same layout:

| Element | How |
|---------|-----|
| Title FontString | `GameFontNormalHuge`, anchored TOPLEFT at `(PANEL_PADDING_X, -PANEL_HEADER_TOP)` |
| Atlas divider | `Options_HorizontalDivider`, full-width minus padding, tinted with `titleFS:GetTextColor()` so future theme retunes follow |
| Defaults button (optional) | AceGUI `Button`, anchored TOPRIGHT at `(-PANEL_PADDING_X, -PANEL_HEADER_TOP)`, width `PANEL_DEFAULTS_W` |

The parent page renders its title plain (`"Ka0s Pretty Chat"`) via `opts.isMain = true`. Sub-pages prefix the title to read as a breadcrumb: `"Ka0s Pretty Chat ▸ Loot"`. The chevron is an inline-atlas escape (` |A:common-icon-forwardarrow:16:16|a `) so it renders as a real texture, not a font glyph — font-agnostic and locale-safe. If a future client retires the atlas, swap to `NPE_RightClick` or `chevron-collapse` (same escape syntax, just the atlas name changes). The Blizzard left-tree label always stays unprefixed (driven by `panel.name`) so the indented tree doesn't repeat the parent name.

All layout dimensions live in `core/Constants.lua` (`ns.Const.PANEL_PADDING_X`, `PANEL_HEADER_TOP`, `PANEL_HEADER_HEIGHT`, `PANEL_DEFAULTS_W`, `SECTION_TOP_SPACER`, `SECTION_BOTTOM_SPACER`, `SECTION_HEADING_H`, `ROW_VSPACER`, `STRING_VSPACER`).

## Always-visible scrollbar

`patchAlwaysShowScrollbar(scroll)` rebinds the AceGUI ScrollFrame's `FixScroll` so:

- The scrollbar (and its 20 px right-side gutter) is shown on every page, regardless of overflow. Short pages (General) and long pages (Loot, 19 strings) line up at the same right edge.
- When content fits, the thumb parks at the top, the scrollbar greys out, and mousewheel input is inert. When content overflows, the upstream FixScroll logic runs unchanged.
- On widget release, the original FixScroll / MoveScroll / OnRelease are restored so the AceGUI pool returns clean for any subsequent acquirer.

## The virtual `General` sub-page

`General` is a *virtual category* — no entry in `ns.Defaults`, no per-string rows. It's built by `buildGeneralBody(ctx)` and hosts every actionable addon-wide control:

| Control | Wire-up |
|---------|---------|
| Description label | One-line explainer: master toggle behaviour. |
| **Enable PrettyChat** toggle (50% row) | Bound to the `General.enabled` schema row. Master switch — when off, every Blizzard original is restored regardless of per-category settings. |
| **Debug console** toggle (50% row, beside Enable) | *Not* schema-backed. Shows/hides the debug console **window** only (`ns.DebugLog:Show()` / `:Hide()`) — the same effect as bare `/pc debug`. It does **not** touch the debug logging flag; logging on/off stays owned by the window's header toggle and `/pc debug on\|off`. Reads `ns.DebugLog:IsShown()`, and the window's OnShow/OnHide fire `Schema.NotifyPanelChange("General")` so the checkbox tracks visibility however it changes (this box, `/pc debug`, the close button, Esc). |
| **Test** button (50% row) | Calls `PrettyChat:Test()`. Synthesizes a sample chat line from every format string regardless of enable toggles, so the preview works even when the addon is disabled. |
| **Reset all to defaults** button (50% row) | Opens the `PRETTYCHAT_RESET_ALL` StaticPopup; on confirm, calls `PrettyChat:ResetAll()`. |

The General sub-page does not show a `Defaults` button in the header — the in-body "Reset all to defaults" with its popup confirm is the only addon-wide reset surface, and showing both would be redundant.

## Per-category sub-pages

`buildCategoryBody(ctx, category, catData)`:

1. **Enable `<Category>`** checkbox at the top, bound to the `<Cat>.enabled` schema row.
2. A 2× row spacer.
3. One per-string row block per format string in `catData.strings`, sorted by global name.

The header carries a **Defaults** button on the right that calls `PrettyChat:ResetCategory(category)` directly — no popup confirm. Per-row reset is preserved via the per-string `Reset` button (see below), and the master `Reset all to defaults` on General has the popup, so a per-category Defaults click is a single recoverable action.

## Per-string block

Each format string renders as a `Heading` + a 3-row × 2-column grid inside the category panel:

```
─── strData.label ───                          ← AceGUI Heading, full width
[Enable]            | Original [disabled EditBox]
GLOBALNAME (grey)   | New      [editable EditBox]
[Reset]             | Preview  [disabled EditBox]
```

| Row | Left (40%) | Right (60%) |
|-----|------------|-------------|
| Heading | Friendly label, `GameFontNormalLarge` flanked by side dividers | — |
| 1 | `[Enable]` checkbox | Original format `EditBox` (disabled, `:SetLabel("Original")`) |
| 2 | `GLOBALNAME` caption (grey) | New format `EditBox` (editable, `:SetLabel("New")`, commits on Enter) |
| 3 | `[Reset]` button | Preview `EditBox` (disabled, `:SetLabel("Preview")`, `ns.RenderSample` output) |

Each row is its own AceGUI `SimpleGroup` with `Flow` layout; the left child uses `:SetRelativeWidth(LEFT_W)` (`0.4`) and the right uses `:SetRelativeWidth(RIGHT_W)` (`0.6`), so the two columns align across all three rows. The right-column EditBox labels (`Original` / `New` / `Preview`) sit above each input via AceGUI's built-in label slot — left-column widgets vertically align with the EditBox itself, not the label.

State derived per block in the block's `refresh()` closure (run on first build and on every `Schema.NotifyPanelChange`):

- `[Enable]` checkbox: `enable:SetValue(strEnabled)` and disabled when master OR category is off.
- New format `EditBox`: `:SetText` from the schema; disabled when master, category, or per-string is off.
- Preview `EditBox`: always shows `ns.RenderSample(current)` — the rendered sample with sample args substituted in. The backing `InputBoxTemplate` FontString renders WoW `|c…|r` color escapes, so the preview shows with its formatting intact. On `string.format` failure, the error message is shown instead.
- `[Reset]` button: always visible. Clicking when the value already equals the default is a harmless no-op (the schema's auto-clear-on-default short-circuits to nil).

The new-format `EditBox` commits on `OnEnterPressed` through `ns.Schema.Set(formatPath, …)` after un-escaping `||` → `|`. The schema runs `PrettyChat:ApplyStrings()` and calls `Schema.NotifyPanelChange(category)`, which dispatches to the category's refresher (see below).

## Edit-box pipe escaping

WoW's chat input interprets `|c…|r` as inline color escapes the moment Enter is pressed, so a raw `|` typed into the edit box would be eaten. The new-format input wraps `|` ↔ `||` at the UI boundary:

```lua
:SetText(current:gsub("|", "||"))                         -- on read
ns.Schema.Set(formatPath, value:gsub("||", "|"))          -- on commit
```

`ns.Schema` always stores raw single-`|` format strings. The disabled Original input shows the doubled form too (read-only — the user never sends it back through chat input). `/pc set` users have to type `||` themselves; see [slash-commands.md](./slash-commands.md#edit-box-pipe-escaping).

## NotifyPanelChange refresh dispatch

`Schema.NotifyPanelChange(category)` invokes a per-sub-page refresh closure that `settings/Panel.lua` registers on first `OnShow`:

```lua
-- settings/Schema.lua
Schema.refreshers = {}

function Schema.RegisterRefresher(category, fn)
    Schema.refreshers[category] = fn
end

function Schema.NotifyPanelChange(category)
    if category == "General" or category == nil then
        for _, fn in pairs(Schema.refreshers) do pcall(fn) end
        return
    end
    local fn = Schema.refreshers[category]
    if fn then pcall(fn) end
end
```

`settings/Panel.lua`'s sub-page builder returns a `refresh` closure; the panel's `OnShow` calls `Schema.RegisterRefresher(category, refresh)`. A `Schema.Set` from the panel widgets (callback) or the `/pc set` slash both end up calling `Schema.NotifyPanelChange(row.category)` — the registered closure walks every per-string `refresh` in that category and re-syncs widget values + disabled state from the DB.

Master-toggle (`General.enabled`) changes cascade to every sub-page because per-string disabled state depends on the master.

Sub-pages that have never been opened have no entry in `Schema.refreshers`. That's correct: their first `OnShow` builds widgets seeded from the live DB, so they cannot show stale state — there is nothing to refresh until the user has opened the page at least once.

Programmatic `:SetValue`/`:SetText` on AceGUI widgets do **not** re-fire the user callbacks, so refresh is safe to call from inside a callback chain.

## The Test preview

Both the General sub-page's "Test" button and the `/pc test` slash command call `PrettyChat:Test(filter)` (in `modules/Override.lua`). The button calls it with no filter (every category, every string); the slash dispatcher (`runTest`) forwards `{kind="category", value=…}` or `{kind="formatstring", value=…}` for the subcommand variants. See [slash-commands.md](./slash-commands.md#command-reference) for the user-facing forms.

The function:

1. Walks `Schema.CATEGORY_ORDER` (so output order matches the panel left-rail). Per category, the strings table is sorted alphabetically by global name. The `filter` argument is applied at both layers — a category filter skips non-matching categories before iterating their strings, a formatstring filter is applied per-string and shows the global under every category it's registered in (so `LOOT_ITEM_CREATED_SELF` prints under both Loot and Tradeskill).
2. For each emitted string, prints a 3-line block: `Name: <GLOBALNAME>`, `Original: <rendered Blizzard original>`, `Formatted: <rendered PrettyChat-configured value>`. Labels are green; the category header above each block (`Category: <name>`) is gold. The Original is rendered from `self.originalStrings[globalName]` (the snapshot taken in `OnEnable`); the Formatted side is rendered from `self:GetStringValue(category, globalName)`.
3. Both renders go through `ns.RenderSample(fmt)` — the same path the per-row Preview EditBox uses, so test output and panel preview can never drift on placeholder choices or positional-arg handling. `RenderSample` walks `%[n$][flags][width][.precision]type` conversions (positional `%n$type` is honored), produces typed placeholders (`"Sample"` for `%s`, `42` for integer types, `1.5` for floats, `65` for `%c`, `"?"` for unknowns), strips `%%` escapes first, and `pcall`s `string.format`. On failure the rendered cell is replaced by an inline grey `(error: <msg>)` and the row counts toward the errored tally.
4. **Every line — header, category banner, body lines, blank-line separators, footer — carries the `[PC]` prefix**, so the report stays distinguishable from real chat traffic interleaved with it. Header includes a notice when `IsAddonEnabled()` is false. Footer reports both counts: `"end of test output (N strings shown, K errored)"` (the `K errored` clause is omitted when zero). When the filter matches no strings (e.g. `/pc test category General` — the virtual category has no strings) the function emits `(no matching strings)` and skips the footer.

Test output ignores the master / per-category / per-string enable toggles — the preview is for *seeing what your formats look like*, not for verifying which ones are currently applied to live chat. The toggles only affect what `ApplyStrings` writes to live `_G[GLOBALNAME]`.

`ns.RenderSample(fmt)` (also exposed from `modules/Override.lua`) is the single-string version used by the per-row sample label: returns `(rendered_string)` on success or `(nil, err)` on `string.format` failure.

## Color palette

The default formats in `defaults/Defaults.lua` use this palette. Edit `defaults/Defaults.lua` directly if you want to add a category or shift a hue.

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
| `ffd700` | Gold — panel string labels (per-string title) |
| `aaaaaa` | Grey — panel captions, slash alias note, default-state sample line |

WoW color escapes use `|cAARRGGBB...|r` (AA = alpha, always `ff`). The house style for new defaults is `Category | Context | Source | +/- value`, each segment color-coded.

Addon UI escapes (slash output, `[PC]` prefix, panel grey captions, command-list colors, `/pc test` block markers) are centralized in `ns.Const.Color` (`core/Constants.lua`) — `cyan`/`reset` build the `[PC]` prefix, `yellow`/`white` colour the slash-help command names + descriptions (and the gold-key / white-value `/pc list` / `get` / `set` rows), `grey` colours the alias note and the per-string GLOBALNAME caption, `gold` is used for the `Category:` header in `/pc test` output, `green` is used for the `Name:` / `Original:` / `Formatted:` labels in the same. The mandated slash-commands-§5 output palette adds `listHead` (green "Available settings" / count headers) and `azure` (the `[Category]` group headers) — these exact codes are fixed across every Ka0s addon and must not be substituted. Edit `core/Constants.lua` to retune the addon UI palette; this table above governs the chat-message palette.
