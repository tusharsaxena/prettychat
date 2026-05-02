# Settings panel

`Config.lua` builds the settings panel directly on Blizzard's modern `Settings.RegisterCanvasLayoutCategory` / `Settings.RegisterCanvasLayoutSubcategory` API and renders body content with AceGUI. PrettyChat appears under **Ka0s Pretty Chat**; the parent page hosts the logo, tagline, and slash-command list (read-only orientation), and nine sub-pages hold the actionable controls — one per category (`General`, Loot, Currency, Money, Reputation, Experience, Honor, Tradeskill, Misc).

This doc covers: the canvas-layout framework, the unified per-page header, the virtual `General` sub-page, the per-string row, the Test button, and the color palette.

## Canvas-layout framework

`Config.lua` doesn't go through `AceConfigDialog:AddToBlizOptions` (the older path that auto-renders an AceConfig options table inside the addon's right pane). It builds plain Blizzard `Frame`s for each page, stamps a unified header on each, and uses an AceGUI `ScrollFrame` for the body content. Every category (parent + sub-pages) shares the same header design and right-edge gutter, and the body is laid out the same way on every page.

Registration order from `registerPanels()`:

```lua
Settings.RegisterCanvasLayoutCategory(parentPanel, "Ka0s Pretty Chat")
Settings.RegisterAddOnCategory(mainCategory)        -- adds to the addon list

for _, category in ipairs(CATEGORY_ORDER) do
    Settings.RegisterCanvasLayoutSubcategory(mainCategory, subPanel, category)
end
```

`PrettyChat.subFrames[category]` stores each subcategory object. `PrettyChat.optionsCategoryID = mainCategory:GetID()` is what `PrettyChat:OpenConfig()` passes to `Settings.OpenToCategory`.

Bootstrap waits for `PLAYER_LOGIN`, then calls `registerPanels()`. AceGUI body rendering is **deferred until the panel's first `OnShow`** — at PLAYER_LOGIN the body's frame width is zero, and AceGUI's `List` layout sizes children against the container's current width, so building too early produces a stack of misaligned widgets.

## Unified per-page header

`buildHeader(panel, title, opts)` stamps every page with the same layout:

| Element | How |
|---------|-----|
| Title FontString | `GameFontNormalHuge`, anchored TOPLEFT at `(PANEL_PADDING_X, -PANEL_HEADER_TOP)` |
| Atlas divider | `Options_HorizontalDivider`, full-width minus padding, tinted with `titleFS:GetTextColor()` so future theme retunes follow |
| Defaults button (optional) | AceGUI `Button`, anchored TOPRIGHT at `(-PANEL_PADDING_X, -PANEL_HEADER_TOP)`, width `PANEL_DEFAULTS_W` |

The parent page renders its title plain (`"Ka0s Pretty Chat"`) via `opts.isMain = true`. Sub-pages prefix the title to read as a breadcrumb: `"Ka0s Pretty Chat  |  Loot"`. The Blizzard left-tree label always stays unprefixed (driven by `panel.name`) so the indented tree doesn't repeat the parent name.

All layout dimensions live in `Constants.lua` (`ns.Const.PANEL_PADDING_X`, `PANEL_HEADER_TOP`, `PANEL_HEADER_HEIGHT`, `PANEL_DEFAULTS_W`, `SECTION_TOP_SPACER`, `SECTION_BOTTOM_SPACER`, `SECTION_HEADING_H`, `ROW_VSPACER`, `STRING_VSPACER`).

## Always-visible scrollbar

`patchAlwaysShowScrollbar(scroll)` rebinds the AceGUI ScrollFrame's `FixScroll` so:

- The scrollbar (and its 20 px right-side gutter) is shown on every page, regardless of overflow. Short pages (General) and long pages (Loot, ~18 strings) line up at the same right edge.
- When content fits, the thumb parks at the top, the scrollbar greys out, and mousewheel input is inert. When content overflows, the upstream FixScroll logic runs unchanged.
- On widget release, the original FixScroll / MoveScroll / OnRelease are restored so the AceGUI pool returns clean for any subsequent acquirer.

## The virtual `General` sub-page

`General` is a *virtual category* — no entry in `PrettyChatDefaults`, no per-string rows. It's built by `buildGeneralBody(ctx)` and hosts every actionable addon-wide control:

| Control | Wire-up |
|---------|---------|
| Description label | One-line explainer: master toggle behaviour. |
| **Enable PrettyChat** toggle | Bound to the `General.enabled` schema row. Master switch — when off, every Blizzard original is restored regardless of per-category settings. |
| **Test** button (50% row) | Calls `PrettyChat:Test()`. Synthesizes a sample chat line from every format string regardless of enable toggles, so the preview works even when the addon is disabled. |
| **Reset all to defaults** button (50% row) | Opens the `PRETTYCHAT_RESET_ALL` StaticPopup; on confirm, calls `PrettyChat:ResetAll()`. |

The General sub-page does not show a `Defaults` button in the header — the in-body "Reset all to defaults" with its popup confirm is the only addon-wide reset surface, and showing both would be redundant.

## Per-category sub-pages

`buildCategoryBody(ctx, category, catData)`:

1. **Enable `<Category>`** checkbox at the top, bound to the `<Cat>.enabled` schema row.
2. A 2× row spacer.
3. One per-string row block per format string in `catData.strings`, sorted by global name.

The header carries a **Defaults** button on the right that calls `PrettyChat:ResetCategory(category)` directly — no popup confirm. Per-row reset is preserved via the per-string `Reset` button (see below), and the master `Reset all to defaults` on General has the popup, so a per-category Defaults click is a single recoverable action.

## Per-string row

Each format string renders as four logical rows inside the category panel:

| Row | Contents | Layout |
|-----|----------|--------|
| 1 | `[Enable]` checkbox + visible label (gold, `GameFontNormal`) | Flow, 25% / 74% |
| 2 | `GLOBALNAME` caption (grey) | Full width |
| 3 | Original format (disabled `EditBox`) \| New format (editable `EditBox`) | Flow, 50% / 50% |
| 4 | Rendered sample (calls `ns.RenderSample`) + `[Reset]` button | Flow, 78% / 20% |

State derived per row in the row's `refresh()` closure (run on first build and on every `Schema.NotifyPanelChange`):

- `[Enable]` checkbox: `enable:SetValue(strEnabled)` and disabled when master OR category is off.
- New format `EditBox`: `:SetText` from the schema; disabled when master, category, or per-string is off.
- Sample Label:
  - When current value `==` default — render with sample args via `ns.RenderSample`, dim with grey color, hide the Reset button (no diff to revert).
  - When value `~=` default — render with sample args, no dimming, show the Reset button. On `string.format` error, render the error message in red.

The new-format `EditBox` commits on `OnEnterPressed` (Enter or focus loss) through `ns.Schema.Set(formatPath, …)` after un-escaping `||` → `|`. The schema runs `PrettyChat:ApplyStrings()` and calls `Schema.NotifyPanelChange(category)`, which dispatches to the category's refresher (see below).

## Edit-box pipe escaping

WoW's chat input interprets `|c…|r` as inline color escapes the moment Enter is pressed, so a raw `|` typed into the edit box would be eaten. The new-format input wraps `|` ↔ `||` at the UI boundary:

```lua
:SetText(current:gsub("|", "||"))                         -- on read
ns.Schema.Set(formatPath, value:gsub("||", "|"))          -- on commit
```

`ns.Schema` always stores raw single-`|` format strings. The disabled Original input shows the doubled form too (read-only — the user never sends it back through chat input). `/pc set` users have to type `||` themselves; see [slash-commands.md](./slash-commands.md#edit-box-pipe-escaping).

## NotifyPanelChange refresh dispatch

`Config.lua` overrides `ns.Schema.NotifyPanelChange` (originally an AceConfigDialog cache invalidator) with a per-category refresher dispatch:

```lua
function ns.Schema.NotifyPanelChange(category)
    if category == "General" or category == nil then
        for _, fn in pairs(PrettyChat.subRefreshers) do pcall(fn) end
        return
    end
    local fn = PrettyChat.subRefreshers[category]
    if fn then pcall(fn) end
end
```

Each category sub-page's body builder returns a `refresh` closure stored at `PrettyChat.subRefreshers[category]`. A `Schema.Set` from the panel widgets (callback) or the `/pc set` slash both end up calling `Schema.NotifyPanelChange(row.category)` — the closure walks every per-string `refresh` in that category and re-syncs widget values + disabled state from the DB.

Master-toggle (`General.enabled`) changes cascade to every sub-page because per-string disabled state depends on the master.

Programmatic `:SetValue`/`:SetText` on AceGUI widgets do **not** re-fire the user callbacks, so refresh is safe to call from inside a callback chain.

## The Test preview

Both the General sub-page's "Test" button and the `/pc test` slash command call `PrettyChat:Test()` (in `PrettyChat.lua`). The function:

1. Iterates every format string in every category — **regardless of master / per-category / per-string enable toggles**. The preview is for *seeing what your formats look like*, not for verifying which ones are currently applied to live chat.
2. For each string, calls the local `buildSampleArgs(fmt)` — parses `%[flags][width][.precision]type` conversions and produces typed placeholders (`"Sample"` for `%s`, `42` for integer types, `1.5` for floats, `65` for `%c`, `"?"` for unknowns). `%%` escapes are stripped first.
3. `pcall(string.format, fmt, unpack(args))` — a malformed format won't break the loop; it just gets skipped.
4. Emits each sample line via `DEFAULT_CHAT_FRAME:AddMessage` **without** the `[PC]` prefix, so each rendered preview looks identical to a real loot/currency/XP chat message.
5. Header and footer carry the `[PC]` prefix, bracketing the test block. Header includes a notice when `IsAddonEnabled()` is false. Footer reports the printed count (`"end of test output (N strings shown)"`).

`ns.RenderSample(fmt)` (also exposed from `PrettyChat.lua`) is the single-string version used by the per-row sample label: returns `(rendered_string)` on success or `(nil, err)` on `string.format` failure.

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
| `ffd700` | Gold — panel string labels (per-string title) |
| `aaaaaa` | Grey — panel captions, slash alias note, default-state sample line |

WoW color escapes use `|cAARRGGBB...|r` (AA = alpha, always `ff`). The house style for new defaults is `Category | Context | Source | +/- value`, each segment color-coded.
