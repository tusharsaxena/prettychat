local addonName, ns = ...

ns.Const = ns.Const or {}
local Const = ns.Const

-- Horizontal padding from the panel's left and right edges to its
-- header / divider / body content. Single value used for both edges so
-- the layout stays symmetric.
Const.PANEL_PADDING_X     = 16

-- Vertical inset of the title (and the per-panel "Defaults" button next
-- to it) from the top of the panel. Roughly half the height of the
-- GameFontNormalHuge title glyph so the header doesn't crowd the
-- panel's top edge.
Const.PANEL_HEADER_TOP    = 20

-- Distance from the top of the panel to the divider underneath the
-- title. Sits in lockstep with PANEL_HEADER_TOP so the title-to-divider
-- gap (and divider-to-body gap below it) stay unchanged when the header
-- block is repositioned vertically.
Const.PANEL_HEADER_HEIGHT = 54

-- Width of the per-panel "Defaults" button in the header.
Const.PANEL_DEFAULTS_W    = 110

-- Relative width for a pair of cell-filling side-by-side buttons in a
-- Flow-layout row. Slightly under 0.5 so AceGUI's inter-widget padding
-- doesn't wrap the second button onto a new line.
Const.BUTTON_PAIR_REL     = 0.492

-- AceGUI Heading widget height + breathing-room spacers above and
-- below it. Skipped above the first heading on a page (the page header
-- already provides whitespace).
Const.SECTION_TOP_SPACER    = 10
Const.SECTION_BOTTOM_SPACER = 6
Const.SECTION_HEADING_H     = 26

-- Vertical gap between consecutive widget rows inside a panel.
Const.ROW_VSPACER = 8

-- Per-string entry — vertical gap that bottoms each string entry and
-- keeps adjacent strings from butting against each other.
Const.STRING_VSPACER = 14

-- Single source for the chat-color escapes used across PrettyChat.lua
-- (slash output, [PC] prefix, Test header/footer) and Config.lua (panel
-- captions, alias label). `cyan` is the [PC] prefix color — the cyan
-- /reset pair is the addon's brand mark and must not change without a
-- visual review.
Const.Color = {
    gold   = "|cffffd700",
    grey   = "|cffaaaaaa",
    red    = "|cffff5050",
    yellow = "|cffffff00",   -- also the slash-§5 schema-path/key colour (ffff00)
    white  = "|cffffffff",   -- also the slash-§5 value colour (ffffff)
    cyan   = "|cff00ffff",
    green  = "|cff40ff40",   -- brand green (Test labels + existing UI)
    -- slash-commands-§5 mandated schema-output palette. These exact codes are a MUST —
    -- they read identically across every Ka0s addon, so MUST NOT be substituted. Note the
    -- header green (33ff99) is deliberately distinct from the brand green above (40ff40).
    listHead = "|cff33ff99",  -- `list` "Available settings" header
    azure    = "|cff3399ff",  -- `list` [category] group headers
    reset  = "|r",
}

-- Shared cyan [PC] chat tag. Single source for every module's chat
-- output — ns.Print prepends it. Cyan is the addon's brand mark.
Const.PREFIX = Const.Color.cyan .. "[PC]" .. Const.Color.reset .. " "
ns.PREFIX    = Const.PREFIX

-- Monospace font for the on-screen debug console (debug-logging-§2). Vendored under
-- media/fonts/ (JetBrains Mono, OFL) rather than depending on a user-installed font, and
-- applied via this direct path in core/DebugLog.lua. LibSharedMedia registration is
-- intentionally omitted: PrettyChat ships no font-picker consumer, so the path constant
-- alone suffices — a documented SHOULD-deviation from debug-logging-§2.
Const.FONT_MONO = "Interface\\AddOns\\PrettyChat\\media\\fonts\\JetBrainsMono-Regular.ttf"
