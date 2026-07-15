-- tests/test_debuglog.lua — the on-screen debug console (core/DebugLog.lua):
-- the two pure line formatters, the FONT_MONO constant, and the /pc debug
-- seam (window toggle vs session-state on/off) plus the gated ns.Debug sink.

local function debugCmd(ns, addon, rest)
    for _, entry in ipairs(ns.COMMANDS) do
        if entry[1] == "debug" then return entry[3](addon, rest) end
    end
    error("no debug command in ns.COMMANDS")
end

return function(ctx)
    local t     = ctx.t
    local inst  = ctx.loadAddon()
    local ns    = inst.ns
    local addon = inst.addon
    local D     = ns.DebugLog

    -- FONT_MONO points at the vendored JetBrains Mono TTF (debug-logging-§2).
    t.truthy(type(ns.Const.FONT_MONO) == "string", "FONT_MONO is a string")
    t.truthy(ns.Const.FONT_MONO:match("JetBrainsMono.-%.ttf$") ~= nil,
        "FONT_MONO points at the vendored JetBrainsMono TTF")

    -- Pure formatters (frame-free, unit-tested so colour can't drift from plain).
    t.eq(D.FormatPlain("15:04:43", "Loot", "item x2"),
        "15:04:43 | [Loot] item x2", "FormatPlain: ts | [tag] msg")
    t.eq(D.FormatPlain("15:04:43", nil, "hi"),
        "15:04:43 | [] hi", "FormatPlain tolerates a nil tag")
    t.eq(D.FormatColored("15:04:43", "Loot", "item x2"),
        "|cff6f8faf15:04:43|r || |cffc9a66b[Loot]|r item x2",
        "FormatColored: steel-blue ts, tan/gold tag, default rest")

    -- /pc debug on|off drives the session flag through the SetEnabled seam.
    ns.State.debug = false
    debugCmd(ns, addon, "on")
    t.eq(ns.State.debug, true, "/pc debug on enables session state")
    debugCmd(ns, addon, "off")
    t.eq(ns.State.debug, false, "/pc debug off disables session state")

    -- Bare /pc debug toggles the window only — it MUST NOT change the flag.
    ns.State.debug = true
    debugCmd(ns, addon, "")
    t.eq(ns.State.debug, true, "bare /pc debug leaves state on")
    ns.State.debug = false
    debugCmd(ns, addon, "")
    t.eq(ns.State.debug, false, "bare /pc debug leaves state off")

    -- The header toggle click flips state through the same seam.
    ns.State.debug = false
    D:Show()
    local click = D._toggleClickForTest
    t.truthy(type(click) == "function", "header toggle click closure is exposed")
    click(); t.eq(ns.State.debug, true,  "header click turns state on")
    click(); t.eq(ns.State.debug, false, "second header click turns state off")

    -- ns.Debug is a no-op when off (zero-alloc gate) and appends when on.
    ns.State.debug = false
    local before = #D.buffer
    ns.Debug("Loot", "%s x%d", "item", 2)
    t.eq(#D.buffer, before, "ns.Debug appends nothing when logging is off")
    ns.State.debug = true
    local n = #D.buffer
    ns.Debug("Loot", "%s x%d", "item", 2)
    t.eq(#D.buffer, n + 1, "ns.Debug appends one line when logging is on")
    t.truthy(D.buffer[#D.buffer]:find("| %[Loot%] item x2$"),
        "ns.Debug renders the format args into a [tag]-prefixed line")

    -- Real producers: a schema write logs both the [Set] and the [Apply] pass it triggers
    -- (the ns.Debug call sites in settings/Schema.lua and modules/Override.lua).
    ns.State.debug = true
    D:Clear()
    ns.Schema.Set("General.enabled", false)
    local joined = table.concat(D.buffer, "\n")
    t.truthy(joined:find("%[Set%] General%.enabled = false"),
        "Schema.Set emits a [Set] debug line")
    t.truthy(joined:find("%[Apply%] addon="),
        "ApplyStrings emits an [Apply] debug line")
end
