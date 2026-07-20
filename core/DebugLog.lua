local addonName, ns = ...
ns.DebugLog = ns.DebugLog or {}
local D = ns.DebugLog
local frame

-- ON/OFF state colours (debug-logging-§5): the chat ack and the title-bar toggle MUST use
-- the same green/red so the flag reads identically in chat and on the console header.
local COL_ON_HEX,  COL_OFF_HEX = "|cff40ff40", "|cffff4040"
local COL_ON_RGB,  COL_OFF_RGB = { 0.25, 1.00, 0.25 }, { 1.00, 0.25, 0.25 }  -- 40ff40 / ff4040

-- On-screen debug console (Ka0s standard, debug-logging). Debug output (ns.Debug) renders
-- here in a monospace font instead of spamming the chat frame. Session-only: the enabled
-- flag lives in ns.State.debug and resets on every reload/login (debug-logging-§5).

-- Plain-text mirror of the log (no colour codes), for the Copy window. Capped like the log.
D.buffer = D.buffer or {}
local MAX_BUFFER = 500

-- Debug-logging-§11 chrome dimensions: the height reserved at the window bottom for the
-- line-counter status bar, and the vertical scrollbar track width down the right edge.
local STATUS_H = 16
local BAR_W    = 8

-- Backdrop shared by the console + copy windows so they read like the addon's own frames.
local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local function applySkin(f)
    if not f.SetBackdrop then return end
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.06, 0.06, 0.07, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)
end

-- Small flat text button for the title bar (Copy / Clear).
local function makeTextButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 18)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    fs:SetTextColor(0.7, 0.7, 0.72)
    b:SetScript("OnEnter", function() fs:SetTextColor(1, 0.82, 0) end)
    b:SetScript("OnLeave", function() fs:SetTextColor(0.7, 0.7, 0.72) end)
    b:SetScript("OnClick", onClick)
    return b
end

local function makeCloseButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("CENTER")
    fs:SetText("\195\151")  -- multiplication sign ×
    fs:SetTextColor(0.7, 0.7, 0.72)
    b:SetScript("OnEnter", function() fs:SetTextColor(1, 0.3, 0.3) end)
    b:SetScript("OnLeave", function() fs:SetTextColor(0.7, 0.7, 0.72) end)
    b:SetScript("OnClick", onClick)
    return b
end

-- Keep the General-page "Debug console" checkbox in sync with the window's
-- actual visibility, however it was shown/hidden (that checkbox, bare
-- /pc debug, the close button, Esc). Guarded: settings/ loads after core/,
-- and this only fires at runtime once a refresher is registered.
local function notifyPanelVisibility()
    if ns.Schema and ns.Schema.NotifyPanelChange then
        ns.Schema.NotifyPanelChange("General")
    end
end

local function EnsureFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "PrettyChatDebugWindow", UIParent, "BackdropTemplate")
    frame:SetSize(700, 344)
    frame:SetPoint("CENTER", 220, -80)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(26)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER")
    title:SetText("Pretty Chat \226\128\148 Debug")
    frame.title = title

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    divider:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    divider:SetHeight(1)
    divider:SetColorTexture(0, 0, 0, 1)
    frame.divider = divider

    local close = makeCloseButton(titleBar, function() D:Hide() end)
    close:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)

    local clear = makeTextButton(titleBar, "Clear", 42, function() D:Clear() end)
    clear:SetPoint("RIGHT", close, "LEFT", -6, 0)

    local copy = makeTextButton(titleBar, "Copy", 40, function() D:ShowCopy() end)
    copy:SetPoint("RIGHT", clear, "LEFT", -6, 0)

    -- Left-aligned debug on/off toggle: resting colour reflects state (green ON / red OFF);
    -- clicking flips state through the shared SetEnabled seam.
    local toggleBtn = CreateFrame("Button", nil, titleBar)
    toggleBtn:SetSize(80, 18)
    toggleBtn:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    local toggleFS = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toggleFS:SetPoint("LEFT")
    toggleBtn:SetScript("OnEnter", function() toggleFS:SetTextColor(1, 0.82, 0) end)
    toggleBtn:SetScript("OnLeave", function() D:RefreshHeader() end)
    local function onToggleClick() D:SetEnabled(not (ns.State and ns.State.debug)) end
    toggleBtn:SetScript("OnClick", onToggleClick)
    frame.debugToggle = toggleFS
    frame.debugToggleBtn = toggleBtn
    D._toggleClickForTest = onToggleClick   -- test seam (mock stubs GetScript)

    local log = CreateFrame("ScrollingMessageFrame", nil, frame)
    log:SetPoint("TOPLEFT", 8, -(26 + 6))
    -- Right inset clears the scrollbar gutter; bottom inset clears the status bar
    -- (and keeps the newest line's descenders off the window border).
    log:SetPoint("BOTTOMRIGHT", -(BAR_W + 8), STATUS_H + 4)
    log:SetFont(ns.Const.FONT_MONO, 10, "")
    log:SetJustifyH("LEFT")
    log:SetFading(false)
    log:SetMaxLines(MAX_BUFFER)
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
        D:UpdateScrollBar()   -- keep the thumb in step with wheel scrolling
    end)
    frame.log = log

    -- Thin flat scrollbar synced to the message frame's scroll offset. A
    -- ScrollingMessageFrame has no native scrollbar (wheel-only), so a plain
    -- vertical Slider drives its offset (debug-logging-§11). Always shown but
    -- inert-when-it-fits, matching the options-panel scrollbar (options-ui-§10).
    -- Vertical Slider convention: value 0 = thumb top = oldest; the message-frame
    -- offset is inverted (0 = newest/bottom), so offset = maxOffset - value.
    local bar = CreateFrame("Slider", nil, frame)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(BAR_W)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(26 + 6))
    bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, STATUS_H + 4)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetValue(0)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.24, 0.24, 0.27, 0.30)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(0.5, 0.5, 0.55, 0.85)
    thumb:SetSize(BAR_W, 36)
    bar:SetThumbTexture(thumb)
    -- Drag → scroll. Guarded by frame._syncing so the UpdateScrollBar → SetValue
    -- feedback path can't loop back through here (debug-logging-§11). Method-presence
    -- + number guards keep the headless mock a clean no-op.
    bar:SetScript("OnValueChanged", function(_, value)
        if frame._syncing then return end
        local l = frame.log
        if not (l.GetMaxScrollRange and l.SetScrollOffset) then return end
        local maxOffset = l:GetMaxScrollRange()
        if type(maxOffset) ~= "number" then return end
        l:SetScrollOffset(maxOffset - math.floor(value + 0.5))
    end)
    frame.scrollBar = bar

    -- Bottom status bar: a 1px divider + a right-aligned "N / MAX lines" counter in
    -- the same monospace font as the log (debug-logging-§11).
    local statusDivider = frame:CreateTexture(nil, "ARTWORK")
    statusDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, STATUS_H)
    statusDivider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, STATUS_H)
    statusDivider:SetHeight(1)
    statusDivider:SetColorTexture(0.24, 0.24, 0.27, 0.85)

    local lineCount = frame:CreateFontString(nil, "OVERLAY")
    lineCount:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 3)
    lineCount:SetFont(ns.Const.FONT_MONO, 10, "")
    lineCount:SetJustifyH("RIGHT")
    lineCount:SetTextColor(0.6, 0.6, 0.62)
    frame.lineCount = lineCount

    applySkin(frame)
    frame:HookScript("OnShow", function() D:RefreshHeader(); notifyPanelVisibility() end)
    frame:HookScript("OnHide", notifyPanelVisibility)
    D:RefreshHeader()

    frame:Hide()
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "PrettyChatDebugWindow")
    end

    -- Initial scrollbar/counter sync LAST (debug-logging-§11 build-order): after the
    -- header, RefreshHeader, and UISpecialFrames registration, so a frame-API surprise
    -- inside the sync can never abort the header-label / ESC-to-close wiring above.
    D:UpdateScrollBar()
    D:UpdateStatus()
    return frame
end

-- Pure plain-text line formatter (no frames, no colour codes): "<ts> | [<tag>] <msg>". This
-- is what the Copy buffer mirrors — clean text with the tag rendered verbatim
-- (debug-logging-§3).
function D.FormatPlain(ts, tag, msg)
    return ("%s | [%s] %s"):format(tostring(ts), tostring(tag or ""), tostring(msg))
end

-- Pure colour-coded line formatter for the console view: timestamp muted steel-blue
-- (6f8faf), [tag] muted tan/gold (c9a66b); the "|" separator and message stay default
-- white. "||" renders one literal pipe inside the colour-coded string (debug-logging-§3).
function D.FormatColored(ts, tag, msg)
    return ("|cff6f8faf%s|r || |cffc9a66b[%s]|r %s"):format(
        tostring(ts), tostring(tag or ""), tostring(msg))
end

function D:Add(tag, msg)
    local f = EnsureFrame()
    local ts = date("%H:%M:%S")
    -- Secret-safe sink (events-frames-taint-§8): neutralise the message before
    -- it reaches the console/buffer so a combat-protected value can't taint it.
    msg = ns.Util.SafeToString(msg)
    f.log:AddMessage(D.FormatColored(ts, tag, msg))
    D.buffer[#D.buffer + 1] = D.FormatPlain(ts, tag, msg)
    if #D.buffer > MAX_BUFFER then table.remove(D.buffer, 1) end
    D:UpdateScrollBar()
    D:UpdateStatus()
end

-- Sync the scrollbar thumb + range to the log's current scroll offset. Uses the Lua
-- ScrollingMessageFrameMixin API (GetMaxScrollRange / GetScrollOffset), where offset 0 =
-- bottom (newest) and offset == maxRange = top (oldest) — never the old C getters
-- GetNumLinesDisplayed / GetCurrentScroll, which are nil on this mixin and raise on first
-- open (anti-pattern #41). No-op until the frame exists; also a clean no-op under the
-- headless mock, whose stub methods return non-numbers (the type guard catches that).
function D:UpdateScrollBar()
    if not (frame and frame.log and frame.scrollBar) then return end
    local log, bar = frame.log, frame.scrollBar
    if not (log.GetMaxScrollRange and log.GetScrollOffset) then return end
    local maxOffset, off = log:GetMaxScrollRange(), log:GetScrollOffset()
    if type(maxOffset) ~= "number" or type(off) ~= "number" then return end
    frame._syncing = true   -- suppress the OnValueChanged → SetScrollOffset feedback loop
    bar:SetMinMaxValues(0, maxOffset)
    bar:SetValue(maxOffset - off)
    frame._syncing = false
    bar:EnableMouse(maxOffset > 0)   -- inert (but still shown) when everything fits
end

-- Update the bottom status bar's line counter. #D.buffer is the live line count, capped at
-- MAX_BUFFER in lock-step with the log's SetMaxLines (debug-logging-§11).
function D:UpdateStatus()
    if frame and frame.lineCount then
        frame.lineCount:SetText(("%d / %d lines"):format(#D.buffer, MAX_BUFFER))
    end
end

function D:Clear()
    if frame and frame.log then frame.log:Clear() end
    wipe(D.buffer)
    D:UpdateScrollBar()
    D:UpdateStatus()
end

-- ── Copy window: read-through EditBox holding the whole log as plain text (§6) ──────────
local copyFrame
local function EnsureCopyFrame()
    if copyFrame then return copyFrame end

    copyFrame = CreateFrame("Frame", "PrettyChatDebugCopyWindow", UIParent, "BackdropTemplate")
    copyFrame:SetSize(560, 360)
    copyFrame:SetPoint("CENTER")
    copyFrame:SetFrameStrata("FULLSCREEN")
    copyFrame:EnableMouse(true)
    copyFrame:SetMovable(true)
    copyFrame:SetClampedToScreen(true)

    local tbar = CreateFrame("Frame", nil, copyFrame)
    tbar:SetPoint("TOPLEFT", 1, -1)
    tbar:SetPoint("TOPRIGHT", -1, -1)
    tbar:SetHeight(26)
    tbar:EnableMouse(true)
    tbar:RegisterForDrag("LeftButton")
    tbar:SetScript("OnDragStart", function() copyFrame:StartMoving() end)
    tbar:SetScript("OnDragStop", function() copyFrame:StopMovingOrSizing() end)
    local t = tbar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("CENTER")
    t:SetText("Copy log \226\128\148 Ctrl+C, then Esc")
    copyFrame.title = t

    local cclose = makeCloseButton(tbar, function() copyFrame:Hide() end)
    cclose:SetPoint("RIGHT", tbar, "RIGHT", -6, 0)

    local scroll = CreateFrame("ScrollFrame", "PrettyChatDebugCopyScroll", copyFrame,
        "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -30)
    scroll:SetPoint("BOTTOMRIGHT", -28, 10)
    copyFrame.scroll = scroll

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFont(ns.Const.FONT_MONO, 10, "")
    edit:SetAutoFocus(false)
    edit:SetWidth(510)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); copyFrame:Hide() end)
    scroll:SetScrollChild(edit)
    copyFrame.edit = edit

    applySkin(copyFrame)
    copyFrame:Hide()
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "PrettyChatDebugCopyWindow")
    end
    return copyFrame
end

function D:ShowCopy()
    local f = EnsureCopyFrame()
    f.edit:SetWidth(f.scroll:GetWidth() > 0 and f.scroll:GetWidth() or 510)
    f.edit:SetText(table.concat(D.buffer, "\n"))
    f.edit:SetCursorPosition(0)
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end

function D:Show() EnsureFrame():Show() end
function D:Hide() if frame then frame:Hide() end end
-- Is the console window currently visible? Used by the General-page checkbox
-- to mirror window state. Returns false before the frame is ever created.
function D:IsShown() return (frame ~= nil and frame:IsShown()) and true or false end
function D:Toggle()
    local f = EnsureFrame()
    if f:IsShown() then f:Hide() else f:Show() end
end

-- One-line self-identifying summary for the [Init] line (debug-logging-§5/§8): addon
-- name+version, schema/DB version, active profile. Read from the addon's AceDB; guarded so
-- a not-yet-ready db can't error. All values are plain (no combat-secret risk), so direct
-- formatting is safe.
function D.SessionSummary()
    local name    = ns.name or "PrettyChat"
    local version = ns.version or "?"
    local schema, profile = "?", "?"
    local addon = LibStub("AceAddon-3.0"):GetAddon("PrettyChat", true)
    local db = addon and addon.db
    if db then
        if db.global and db.global.schemaVersion ~= nil then
            schema = tostring(db.global.schemaVersion)
        end
        if type(db.GetCurrentProfile) == "function" then
            local ok, p = pcall(db.GetCurrentProfile, db)
            if ok and p then profile = tostring(p) end
        end
    end
    return ("%s v%s, schema v%s, profile '%s'"):format(name, version, schema, profile)
end

-- Single seam for changing debug state. The slash command and the header toggle both call
-- this so the chat ack and the header label stay consistent. Session-only (debug-logging-§5).
function D:SetEnabled(on)
    on = not not on
    ns.State.debug = on
    D:RefreshHeader()
    -- Colour-coded chat ack (debug-logging-§5): the state word is ON green / OFF red,
    -- matching the header toggle, through the shared [PC] printer (never a raw print or a
    -- hand-written tag).
    local word = on and (COL_ON_HEX .. "ON|r") or (COL_OFF_HEX .. "OFF|r")
    ns.Print("debug logging " .. word)
    -- Bracket every session with a console line at both ends. Write through D:Add rather
    -- than ns.Debug so the "disabled" line still lands after ns.State.debug has flipped off
    -- (ns.Debug is gated on the flag, D:Add is not).
    D:Add("Debug", on and "logging enabled" or "logging disabled")
    -- On enable, a self-identifying [Init] session summary immediately after the bracket
    -- (debug-logging-§5/§8): which build, which schema, which profile. Raw D:Add (not the
    -- gated sink). This is the visible boot summary — a login-time one would be gated off
    -- (the flag is session-only, off at login) and never render.
    if on then
        D:Add("Init", D.SessionSummary())
    end
end

function D:RefreshHeader()
    if not (frame and frame.debugToggle) then return end
    local on = ns.State and ns.State.debug
    frame.debugToggle:SetText(on and "Debug: ON" or "Debug: OFF")
    local rgb = on and COL_ON_RGB or COL_OFF_RGB
    frame.debugToggle:SetTextColor(rgb[1], rgb[2], rgb[3])
end

-- Global debug sink. No-op (zero alloc) when debug is off; otherwise appends to the console.
function ns.Debug(tag, fmt, ...)
    if not (ns.State and ns.State.debug) then return end
    local msg = fmt
    local n = select("#", ...)
    if n > 0 then
        -- Neutralise any combat-protected secret before it reaches
        -- string.format (events-frames-taint-§8); safe scalars pass through
        -- with their type intact so %d/%f conversions still work.
        local args = {}
        for i = 1, n do
            local v = select(i, ...)
            if v == nil or type(v) == "boolean" or ns.Util.IsConcatSafe(v) then
                args[i] = v
            else
                args[i] = "<secret>"
            end
        end
        msg = fmt:format(unpack(args, 1, n))
    end
    D:Add(tag, msg)
end
