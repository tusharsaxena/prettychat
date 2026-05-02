local addonName, ns = ...

local PrettyChat = LibStub("AceAddon-3.0"):GetAddon("PrettyChat")
local AceGUI = LibStub("AceGUI-3.0")

local Const  = ns.Const
local Schema = ns.Schema
local CATEGORY_ORDER = Schema.CATEGORY_ORDER

local PARENT_TITLE = "Ka0s Pretty Chat"
local TITLE_PREFIX = PARENT_TITLE .. "  |  "

local GOLD  = "|cffffd700"
local GREY  = "|cffaaaaaa"
local RED   = "|cffff5050"
local RESET = "|r"

local TOC_NOTES = (C_AddOns and C_AddOns.GetAddOnMetadata
                   and C_AddOns.GetAddOnMetadata(addonName, "Notes")) or ""

local LOGO_PATH = "Interface\\AddOns\\" .. addonName
                  .. "\\media\\screenshots\\prettychat.logo.v2.tga"
local LOGO_SIZE = 300

-- ---------------------------------------------------------------------
-- Tooltip helper — works on AceGUI widgets (via SetCallback) and plain
-- frames (via HookScript). Anchors on widget.frame for AceGUI widgets.
-- ---------------------------------------------------------------------

local function attachTooltip(widget, label, tooltip)
    if not widget then return end
    local anchor = widget.frame or widget
    if not anchor then return end

    local function show()
        if not GameTooltip then return end
        GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
        if label and label ~= "" then
            GameTooltip:SetText(label, 1, 1, 1)
        end
        if tooltip and tooltip ~= "" then
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end
    local function hide() if GameTooltip then GameTooltip:Hide() end end

    if widget.SetCallback then
        widget:SetCallback("OnEnter", show)
        widget:SetCallback("OnLeave", hide)
    elseif widget.HookScript then
        widget:HookScript("OnEnter", show)
        widget:HookScript("OnLeave", hide)
    end
end

-- ---------------------------------------------------------------------
-- Always-visible scrollbar patch — keeps the right-edge gutter reserved
-- whether or not content overflows so every sub-page lines up at the
-- same x. Restores stock behaviour on widget release so the AceGUI pool
-- isn't polluted for other addons that re-acquire the same instance.
-- Mirrors KickCD's Helpers.PatchAlwaysShowScrollbar.
-- ---------------------------------------------------------------------

local function patchAlwaysShowScrollbar(scroll)
    if not scroll or scroll._pcAlwaysScrollbar then return end
    scroll._pcAlwaysScrollbar = true

    local origFixScroll  = scroll.FixScroll
    local origMoveScroll = scroll.MoveScroll
    local origOnRelease  = scroll.OnRelease

    local scrollbar = scroll.scrollbar
    local thumb     = scrollbar and scrollbar.GetThumbTexture and scrollbar:GetThumbTexture() or nil
    local sbName    = scrollbar and scrollbar.GetName and scrollbar:GetName() or nil
    local upBtn     = sbName and _G[sbName .. "ScrollUpButton"]   or nil
    local downBtn   = sbName and _G[sbName .. "ScrollDownButton"] or nil

    local currentEnabled
    local function setEnabled(want)
        if currentEnabled == want then return end
        currentEnabled = want
        if not scrollbar then return end
        if want then
            if scrollbar.Enable then scrollbar:Enable() end
            if thumb and thumb.SetVertexColor then thumb:SetVertexColor(1, 1, 1, 1) end
            if upBtn   and upBtn.Enable   then upBtn:Enable()   end
            if downBtn and downBtn.Enable then downBtn:Enable() end
        else
            scrollbar:SetValue(0)
            if scrollbar.Disable then scrollbar:Disable() end
            if thumb and thumb.SetVertexColor then thumb:SetVertexColor(0.5, 0.5, 0.5, 0.6) end
            if upBtn   and upBtn.Disable   then upBtn:Disable()   end
            if downBtn and downBtn.Disable then downBtn:Disable() end
        end
    end

    scroll.scrollBarShown = true
    if scrollbar then scrollbar:Show() end
    if scroll.scrollframe then
        scroll.scrollframe:SetPoint("BOTTOMRIGHT", -20, 0)
    end
    if scroll.content and scroll.content.original_width then
        scroll.content.width = scroll.content.original_width - 20
    end

    scroll.FixScroll = function(self)
        if self.updateLock then return end
        self.updateLock = true

        if not self.scrollBarShown then
            self.scrollBarShown = true
            self.scrollbar:Show()
            self.scrollframe:SetPoint("BOTTOMRIGHT", -20, 0)
            if self.content.original_width then
                self.content.width = self.content.original_width - 20
            end
        end

        local status = self.status or self.localstatus
        local height, viewheight =
            self.scrollframe:GetHeight(), self.content:GetHeight()
        local offset = status.offset or 0

        if viewheight < height + 2 then
            setEnabled(false)
            self.scrollbar:SetValue(0)
            self.scrollframe:SetVerticalScroll(0)
            status.offset = 0
        else
            setEnabled(true)
            local value = (offset / (viewheight - height) * 1000)
            if value > 1000 then value = 1000 end
            self.scrollbar:SetValue(value)
            self:SetScroll(value)
            if value < 1000 then
                self.content:ClearAllPoints()
                self.content:SetPoint("TOPLEFT",  0, offset)
                self.content:SetPoint("TOPRIGHT", 0, offset)
                status.offset = offset
            end
        end
        self.updateLock = nil
    end

    scroll.MoveScroll = function(self, value)
        if currentEnabled == false then return end
        if origMoveScroll then return origMoveScroll(self, value) end
    end

    scroll.OnRelease = function(self)
        self.FixScroll  = origFixScroll
        self.MoveScroll = origMoveScroll
        self.OnRelease  = origOnRelease
        self._pcAlwaysScrollbar = nil
        currentEnabled  = nil
        if thumb and thumb.SetVertexColor then thumb:SetVertexColor(1, 1, 1, 1) end
        if scrollbar and scrollbar.Enable then scrollbar:Enable() end
        if upBtn   and upBtn.Enable   then upBtn:Enable()   end
        if downBtn and downBtn.Enable then downBtn:Enable() end
        if origOnRelease then origOnRelease(self) end
    end
end

-- ---------------------------------------------------------------------
-- Header (title + Defaults button + atlas divider)
-- ---------------------------------------------------------------------

local function buildHeader(panel, title, opts)
    -- Sub-pages prefix the title with "Ka0s Pretty Chat  |  " so the
    -- in-page title reads as a breadcrumb. The parent page opts in to
    -- the unprefixed form via opts.isMain so it doesn't read as
    -- "Ka0s Pretty Chat | Ka0s Pretty Chat".
    local displayTitle = opts.isMain and title or (TITLE_PREFIX .. title)

    local titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", panel, "TOPLEFT",
                     Const.PANEL_PADDING_X, -Const.PANEL_HEADER_TOP)
    titleFS:SetText(displayTitle)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOPLEFT",  panel, "TOPLEFT",
                     Const.PANEL_PADDING_X, -Const.PANEL_HEADER_HEIGHT)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT",
                     -Const.PANEL_PADDING_X, -Const.PANEL_HEADER_HEIGHT)
    divider:SetVertexColor(titleFS:GetTextColor())

    local defaultsBtn
    if opts.defaultsButton then
        defaultsBtn = AceGUI:Create("Button")
        defaultsBtn:SetText("Defaults")
        defaultsBtn:SetWidth(Const.PANEL_DEFAULTS_W)
        defaultsBtn.frame:SetParent(panel)
        defaultsBtn.frame:ClearAllPoints()
        defaultsBtn.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT",
                                   -Const.PANEL_PADDING_X, -Const.PANEL_HEADER_TOP)
        defaultsBtn.frame:Show()
        attachTooltip(defaultsBtn, "Defaults", opts.defaultsTooltip)
    end

    return titleFS, divider, defaultsBtn
end

-- ---------------------------------------------------------------------
-- Panel + scroll
-- ---------------------------------------------------------------------

local function createPanel(name, title, opts)
    opts = opts or {}
    local panel = CreateFrame("Frame", name)
    panel.name = title
    panel:Hide()

    local titleFS, divider, defaultsBtn = buildHeader(panel, title, opts)
    panel.title       = titleFS
    panel.divider     = divider
    panel.defaultsBtn = defaultsBtn

    local body = CreateFrame("Frame", nil, panel)
    body:SetPoint("TOPLEFT",     panel, "TOPLEFT",     0, -(Const.PANEL_HEADER_HEIGHT + 8))
    body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    panel.body = body

    return { panel = panel, body = body, scroll = nil }
end

local function ensureScroll(ctx)
    if ctx.scroll then return ctx.scroll end
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll.frame:SetParent(ctx.body)
    scroll.frame:ClearAllPoints()
    scroll.frame:SetPoint("TOPLEFT",     ctx.body, "TOPLEFT",      Const.PANEL_PADDING_X - 4, -8)
    scroll.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -(Const.PANEL_PADDING_X + 12), 8)
    scroll.frame:Show()

    -- AceGUI's ScrollFrame normally has its width/height driven by a parent
    -- AceGUI container; we anchor it to a Blizzard frame instead, so the
    -- OnWidthSet/OnHeightSet callbacks never fire and content.width stays
    -- nil. Forward sizes manually + re-run DoLayout on resize.
    scroll.frame:SetScript("OnSizeChanged", function(_, w, h)
        if scroll.OnWidthSet  then scroll:OnWidthSet(w)  end
        if scroll.OnHeightSet then scroll:OnHeightSet(h) end
        if scroll.DoLayout    then scroll:DoLayout()     end
        if scroll.FixScroll   then scroll:FixScroll()    end
    end)

    patchAlwaysShowScrollbar(scroll)
    ctx.scroll = scroll
    return scroll
end

local function addSpacer(scroll, height)
    local sp = AceGUI:Create("SimpleGroup")
    sp:SetLayout(nil)
    sp:SetFullWidth(true)
    sp:SetHeight(height)
    scroll:AddChild(sp)
    return sp
end

-- ---------------------------------------------------------------------
-- Reset-all popup. The OnAccept body lives in PrettyChat:ResetAll so the
-- popup, the General > "Reset all to defaults" button, and the
-- /pc resetall slash command share a single implementation.
-- ---------------------------------------------------------------------

StaticPopupDialogs["PRETTYCHAT_RESET_ALL"] = {
    text         = "Reset every category and string to defaults?",
    button1      = YES,
    button2      = NO,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function() PrettyChat:ResetAll() end,
}

-- ---------------------------------------------------------------------
-- General sub-page — addon-wide controls. Master Enable + Test +
-- Reset All. Returns a refresh closure so external mutators (slash)
-- re-sync visible widget state.
-- ---------------------------------------------------------------------

local function buildGeneralBody(ctx)
    local scroll = ensureScroll(ctx)

    local desc = AceGUI:Create("Label")
    desc:SetFullWidth(true)
    desc:SetText("Addon-wide controls. The Enable toggle is the master switch — disable it and every Blizzard original is restored regardless of per-category settings.")
    if desc.label and desc.label.SetFontObject and _G.GameFontHighlight then
        desc.label:SetFontObject(_G.GameFontHighlight)
    end
    scroll:AddChild(desc)
    addSpacer(scroll, Const.ROW_VSPACER)

    local enable = AceGUI:Create("CheckBox")
    enable:SetLabel("Enable PrettyChat")
    enable:SetFullWidth(true)
    enable:SetValue(ns.Schema.Get("General.enabled") and true or false)
    enable:SetCallback("OnValueChanged", function(_, _, value)
        ns.Schema.Set("General.enabled", value and true or false)
    end)
    attachTooltip(enable, "Enable PrettyChat",
        "Master switch for the addon. When off, all Blizzard originals are restored.")
    scroll:AddChild(enable)
    addSpacer(scroll, Const.ROW_VSPACER)

    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)

    local testBtn = AceGUI:Create("Button")
    testBtn:SetText("Test")
    testBtn:SetRelativeWidth(0.5)
    testBtn:SetCallback("OnClick", function() PrettyChat:Test() end)
    attachTooltip(testBtn, "Test",
        "Print a sample of every active format string to chat so you can see what real loot/currency/XP messages will look like.")
    row:AddChild(testBtn)

    local resetAllBtn = AceGUI:Create("Button")
    resetAllBtn:SetText("Reset all to defaults")
    resetAllBtn:SetRelativeWidth(0.5)
    resetAllBtn:SetCallback("OnClick", function()
        StaticPopup_Show("PRETTYCHAT_RESET_ALL")
    end)
    attachTooltip(resetAllBtn, "Reset all to defaults",
        "Reset every category and string to its default value.")
    row:AddChild(resetAllBtn)

    scroll:AddChild(row)

    return function()
        enable:SetValue(ns.Schema.Get("General.enabled") and true or false)
    end
end

-- ---------------------------------------------------------------------
-- Per-string row.
--   row 1: [Enable]  <Visible label, gold>
--   row 2: GLOBALNAME caption (small grey)
--   row 3: [original — disabled] | [new — editable]   (50/50)
--   row 4: rendered sample (italic-grey when matches default;
--          red when string.format errors) + [Reset] button on the
--          right, shown only when value diverges from default.
-- ---------------------------------------------------------------------

local function buildStringRow(scroll, category, globalName, strData, refreshers)
    local enabledPath = category .. "." .. globalName .. ".enabled"
    local formatPath  = category .. "." .. globalName .. ".format"

    -- Row 1: Enable + label
    local headerRow = AceGUI:Create("SimpleGroup")
    headerRow:SetLayout("Flow")
    headerRow:SetFullWidth(true)

    local enable = AceGUI:Create("CheckBox")
    enable:SetLabel("Enable")
    enable:SetRelativeWidth(0.25)
    enable:SetCallback("OnValueChanged", function(_, _, value)
        ns.Schema.Set(enabledPath, value and true or false)
    end)
    attachTooltip(enable, "Enable",
        "Use the rewritten format for this message. When unchecked, Blizzard's original is used.")
    headerRow:AddChild(enable)

    local titleLbl = AceGUI:Create("Label")
    titleLbl:SetRelativeWidth(0.74)
    titleLbl:SetText(GOLD .. strData.label .. RESET)
    if titleLbl.label and titleLbl.label.SetFontObject and _G.GameFontNormal then
        titleLbl.label:SetFontObject(_G.GameFontNormal)
    end
    headerRow:AddChild(titleLbl)
    scroll:AddChild(headerRow)

    -- Row 2: GLOBALNAME caption
    local captionLbl = AceGUI:Create("Label")
    captionLbl:SetFullWidth(true)
    captionLbl:SetText(GREY .. globalName .. RESET)
    scroll:AddChild(captionLbl)

    -- Row 3: original | new
    local editRow = AceGUI:Create("SimpleGroup")
    editRow:SetLayout("Flow")
    editRow:SetFullWidth(true)

    local origInput = AceGUI:Create("EditBox")
    origInput:SetLabel("")
    origInput:SetRelativeWidth(0.5)
    origInput:SetDisabled(true)
    local origValue = (PrettyChatGlobalStrings and PrettyChatGlobalStrings[globalName])
                     or "(original not available)"
    origInput:SetText(origValue:gsub("|", "||"))
    attachTooltip(origInput, "Original Format String",
        "Blizzard's original format. Read-only.")
    editRow:AddChild(origInput)

    local newInput = AceGUI:Create("EditBox")
    newInput:SetLabel("")
    newInput:SetRelativeWidth(0.5)
    newInput:SetCallback("OnEnterPressed", function(_, _, value)
        ns.Schema.Set(formatPath, (value or ""):gsub("||", "|"))
    end)
    attachTooltip(newInput, "New Format String",
        "Your replacement. Type `||` for a literal `|` (color codes use this).")
    editRow:AddChild(newInput)
    scroll:AddChild(editRow)

    -- Row 4: rendered sample + reset button
    local sampleRow = AceGUI:Create("SimpleGroup")
    sampleRow:SetLayout("Flow")
    sampleRow:SetFullWidth(true)

    local sampleLbl = AceGUI:Create("Label")
    sampleLbl:SetRelativeWidth(0.78)
    sampleRow:AddChild(sampleLbl)

    local resetBtn = AceGUI:Create("Button")
    resetBtn:SetText("Reset")
    resetBtn:SetRelativeWidth(0.2)
    resetBtn:SetCallback("OnClick", function()
        ns.Schema.Set(formatPath, strData.default)
    end)
    attachTooltip(resetBtn, "Reset",
        "Restore this string to its default.")
    sampleRow:AddChild(resetBtn)
    scroll:AddChild(sampleRow)

    addSpacer(scroll, Const.STRING_VSPACER)

    -- Refresh closure: re-syncs every widget in this row from the DB.
    -- Called on category-level changes (Enable toggled, Defaults pressed,
    -- /pc set, /pc reset). Programmatic SetValue/SetText on AceGUI
    -- widgets do NOT re-fire the user callbacks, so this is safe to call
    -- from within a callback chain.
    local function refresh()
        local current = ns.Schema.Get(formatPath)
        local addonEnabled = PrettyChat:IsAddonEnabled()
        local catEnabled   = PrettyChat:IsCategoryEnabled(category)
        local strEnabled   = PrettyChat:IsStringEnabled(category, globalName)

        enable:SetValue(strEnabled)
        enable:SetDisabled(not (addonEnabled and catEnabled))
        newInput:SetText((current or ""):gsub("|", "||"))
        newInput:SetDisabled(not (addonEnabled and catEnabled and strEnabled))

        if current ~= strData.default then
            local rendered, err = ns.RenderSample(current)
            if rendered then
                sampleLbl:SetText(rendered)
            else
                sampleLbl:SetText(RED .. tostring(err) .. RESET)
            end
            resetBtn.frame:Show()
        else
            local rendered = ns.RenderSample(current)
            sampleLbl:SetText(GREY .. (rendered or "") .. RESET)
            resetBtn.frame:Hide()
        end
    end

    refreshers[#refreshers + 1] = refresh
    refresh()
end

-- ---------------------------------------------------------------------
-- Category sub-page — Enable toggle + per-string rows.
-- ---------------------------------------------------------------------

local function buildCategoryBody(ctx, category, catData)
    local scroll = ensureScroll(ctx)
    local refreshers = {}

    local catEnable = AceGUI:Create("CheckBox")
    catEnable:SetLabel("Enable " .. category)
    catEnable:SetFullWidth(true)
    catEnable:SetValue(ns.Schema.Get(category .. ".enabled") and true or false)
    catEnable:SetCallback("OnValueChanged", function(_, _, value)
        ns.Schema.Set(category .. ".enabled", value and true or false)
    end)
    attachTooltip(catEnable, "Enable " .. category,
        "Enable or disable all " .. category .. " string overrides.")
    scroll:AddChild(catEnable)
    addSpacer(scroll, Const.ROW_VSPACER * 2)

    local sortedNames = {}
    for globalName in pairs(catData.strings) do
        sortedNames[#sortedNames + 1] = globalName
    end
    table.sort(sortedNames)

    for _, globalName in ipairs(sortedNames) do
        buildStringRow(scroll, category, globalName, catData.strings[globalName], refreshers)
    end

    return function()
        catEnable:SetValue(ns.Schema.Get(category .. ".enabled") and true or false)
        for _, fn in ipairs(refreshers) do pcall(fn) end
    end
end

-- ---------------------------------------------------------------------
-- Parent page — logo + tagline + slash-command list. Read-only.
-- ---------------------------------------------------------------------

local function buildParentBody(ctx)
    local scroll = ensureScroll(ctx)

    -- Logo at native size, anchored TOPLEFT in a full-width SimpleGroup
    -- so AceGUI's List layout left-aligns it regardless of panel width.
    local logoGroup = AceGUI:Create("SimpleGroup")
    logoGroup:SetLayout(nil)
    logoGroup:SetFullWidth(true)
    logoGroup:SetHeight(LOGO_SIZE)

    local logoTex = logoGroup.frame:CreateTexture(nil, "ARTWORK")
    logoTex:SetTexture(LOGO_PATH)
    logoTex:SetSize(LOGO_SIZE, LOGO_SIZE)
    logoTex:SetPoint("TOPLEFT", logoGroup.frame, "TOPLEFT", 0, 0)
    scroll:AddChild(logoGroup)
    addSpacer(scroll, Const.ROW_VSPACER)

    if TOC_NOTES ~= "" then
        local tagline = AceGUI:Create("Label")
        tagline:SetFullWidth(true)
        tagline:SetText(TOC_NOTES)
        if tagline.label and tagline.label.SetFontObject and _G.GameFontHighlight then
            tagline.label:SetFontObject(_G.GameFontHighlight)
        end
        scroll:AddChild(tagline)
        addSpacer(scroll, Const.SECTION_TOP_SPACER)
    end

    local heading = AceGUI:Create("Heading")
    heading:SetFullWidth(true)
    heading:SetHeight(Const.SECTION_HEADING_H)
    heading:SetText("Slash Commands")
    if heading.label and heading.label.SetFontObject and _G.GameFontNormalLarge then
        heading.label:SetFontObject(_G.GameFontNormalLarge)
    end
    scroll:AddChild(heading)
    addSpacer(scroll, Const.SECTION_BOTTOM_SPACER)

    local alias = AceGUI:Create("Label")
    alias:SetFullWidth(true)
    alias:SetText(GREY .. "/prettychat is an alias for /pc" .. RESET)
    scroll:AddChild(alias)
    addSpacer(scroll, Const.ROW_VSPACER)

    for _, entry in ipairs(ns.COMMANDS or {}) do
        local row = AceGUI:Create("Label")
        row:SetFullWidth(true)
        row:SetText(("|cffffff00/pc %s|r  |cffffffff—|r  %s"):format(entry[1], entry[2]))
        scroll:AddChild(row)
    end
end

-- ---------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------

PrettyChat.subFrames      = {}
PrettyChat.subRefreshers  = {}

local function registerPanels()
    if not (Settings and Settings.RegisterCanvasLayoutCategory
            and Settings.RegisterCanvasLayoutSubcategory
            and Settings.RegisterAddOnCategory) then
        return
    end

    -- Parent page
    local parentCtx = createPanel("PrettyChatParentPanel", PARENT_TITLE, { isMain = true })
    local parentRendered = false
    parentCtx.panel:SetScript("OnShow", function()
        if parentRendered then return end
        parentRendered = true
        buildParentBody(parentCtx)
    end)

    local mainCategory = Settings.RegisterCanvasLayoutCategory(parentCtx.panel, PARENT_TITLE)
    Settings.RegisterAddOnCategory(mainCategory)
    PrettyChat.optionsCategory   = mainCategory
    PrettyChat.optionsCategoryID = mainCategory:GetID()

    -- Sub-pages
    for _, category in ipairs(CATEGORY_ORDER) do
        local catCtx = createPanel("PrettyChatPanel_" .. category, category, {
            defaultsButton  = (category ~= "General"),
            defaultsTooltip = (category ~= "General")
                and ("Reset all " .. category .. " strings to defaults.")
                or nil,
        })

        local rendered = false
        if category == "General" then
            catCtx.panel:SetScript("OnShow", function()
                if rendered then return end
                rendered = true
                PrettyChat.subRefreshers[category] = buildGeneralBody(catCtx)
            end)
        else
            local catData = PrettyChatDefaults[category]
            if catData then
                if catCtx.defaultsBtn then
                    catCtx.defaultsBtn:SetCallback("OnClick", function()
                        PrettyChat:ResetCategory(category)
                    end)
                end
                catCtx.panel:SetScript("OnShow", function()
                    if rendered then return end
                    rendered = true
                    PrettyChat.subRefreshers[category] = buildCategoryBody(catCtx, category, catData)
                end)
            end
        end

        local subCategory = Settings.RegisterCanvasLayoutSubcategory(
            mainCategory, catCtx.panel, category)
        PrettyChat.subFrames[category] = subCategory
    end
end

-- Replace Schema.NotifyPanelChange (which previously invalidated the
-- AceConfigDialog cache for the matching app) with a refresher dispatch
-- that re-syncs visible widgets on the affected sub-page. Master-toggle
-- changes (category == "General") cascade to every sub-page since
-- per-string disabled state depends on the master.
function ns.Schema.NotifyPanelChange(category)
    if category == "General" or category == nil then
        for _, fn in pairs(PrettyChat.subRefreshers) do pcall(fn) end
        return
    end
    local fn = PrettyChat.subRefreshers[category]
    if fn then pcall(fn) end
end

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("PLAYER_LOGIN")
bootstrap:SetScript("OnEvent", function(self)
    registerPanels()
    self:UnregisterAllEvents()
end)
