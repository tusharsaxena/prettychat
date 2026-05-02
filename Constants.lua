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
