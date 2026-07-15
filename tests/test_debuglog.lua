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
    local test  = ctx.test
    local inst  = ctx.loadAddon()
    local ns    = inst.ns
    local addon = inst.addon
    local env   = inst.env
    local D     = ns.DebugLog

    test("FONT_MONO points at the vendored JetBrainsMono TTF", function()
        -- debug-logging-§2.
        t.truthy(type(ns.Const.FONT_MONO) == "string", "FONT_MONO is a string")
        t.truthy(ns.Const.FONT_MONO:match("JetBrainsMono.-%.ttf$") ~= nil,
            "FONT_MONO points at the vendored JetBrainsMono TTF")
    end)

    test("pure line formatters render plain and coloured lines", function()
        -- Frame-free, unit-tested so colour can't drift from plain.
        t.eq(D.FormatPlain("15:04:43", "Loot", "item x2"),
            "15:04:43 | [Loot] item x2", "FormatPlain: ts | [tag] msg")
        t.eq(D.FormatPlain("15:04:43", nil, "hi"),
            "15:04:43 | [] hi", "FormatPlain tolerates a nil tag")
        t.eq(D.FormatColored("15:04:43", "Loot", "item x2"),
            "|cff6f8faf15:04:43|r || |cffc9a66b[Loot]|r item x2",
            "FormatColored: steel-blue ts, tan/gold tag, default rest")
    end)

    test("/pc debug on|off drives the session flag through the SetEnabled seam", function()
        ns.State.debug = false
        debugCmd(ns, addon, "on")
        t.eq(ns.State.debug, true, "/pc debug on enables session state")
        debugCmd(ns, addon, "off")
        t.eq(ns.State.debug, false, "/pc debug off disables session state")
    end)

    test("colour-coded chat ack: ON green, OFF red, via [PC]", function()
        -- debug-logging-§5.
        local msgs = env.DEFAULT_CHAT_FRAME.messages
        debugCmd(ns, addon, "on")
        t.truthy(msgs[#msgs]:find("|cff40ff40ON|r", 1, true), "on ack colours ON green (40ff40)")
        debugCmd(ns, addon, "off")
        t.truthy(msgs[#msgs]:find("|cffff4040OFF|r", 1, true), "off ack colours OFF red (ff4040)")
    end)

    test("enable emits the [Init] session summary after the bracket", function()
        -- §5/§8: [Init] session summary emitted on enable, immediately after the bracket.
        D:Clear()
        D:SetEnabled(true)
        local bracketIdx, initIdx
        for i, line in ipairs(D.buffer) do
            if line:find("%[Debug%] logging enabled") then bracketIdx = i end
            if line:find("%[Init%]") then initIdx = i end
        end
        t.truthy(bracketIdx, "enable writes the [Debug] logging enabled bracket line")
        t.truthy(initIdx and bracketIdx and initIdx > bracketIdx,
            "[Init] session summary follows the enable bracket")
        t.truthy(initIdx and D.buffer[initIdx]:find("PrettyChat v", 1, true),
            "[Init] carries the addon name + version")
        t.truthy(initIdx and D.buffer[initIdx]:find("schema v", 1, true),
            "[Init] carries the schema/DB version")
        t.truthy(initIdx and D.buffer[initIdx]:find("profile 'Default'", 1, true),
            "[Init] carries the active profile")
        D:SetEnabled(false)  -- leave logging off for the blocks below
    end)

    test("bare /pc debug toggles the window without changing the flag", function()
        ns.State.debug = true
        debugCmd(ns, addon, "")
        t.eq(ns.State.debug, true, "bare /pc debug leaves state on")
        ns.State.debug = false
        debugCmd(ns, addon, "")
        t.eq(ns.State.debug, false, "bare /pc debug leaves state off")
    end)

    test("header toggle click flips state through the same seam", function()
        ns.State.debug = false
        D:Show()
        local click = D._toggleClickForTest
        t.truthy(type(click) == "function", "header toggle click closure is exposed")
        click(); t.eq(ns.State.debug, true,  "header click turns state on")
        click(); t.eq(ns.State.debug, false, "second header click turns state off")
    end)

    test("ns.Debug is a no-op when off and appends one line when on", function()
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
    end)

    test("Schema.Set emits one [Set] line with no separate [Apply] echo", function()
        -- Producers (debug-logging-§8/§9/§10): a settings change logs exactly one [Set]
        -- line at the write seam — no separate [Apply] echo (folded per §10).
        ns.State.debug = true
        D:Clear()
        ns.Schema.Set("General.enabled", false)
        local setJoined = table.concat(D.buffer, "\n")
        t.truthy(setJoined:find("%[Set%] General%.enabled = false"),
            "Schema.Set emits one [Set] <path> = <value> line")
        t.falsy(setJoined:find("%[Apply%]"),
            "no separate [Apply] line per settings change")
    end)

    test("ResetAll emits one [Reset] summary carrying apply counts", function()
        -- A bulk reset bypasses the write seam, so it logs one [Reset] summary.
        D:Clear()
        addon:ResetAll()
        local resetJoined = table.concat(D.buffer, "\n")
        t.truthy(resetJoined:find("%[Reset%] all"),
            "ResetAll emits a [Reset] summary line")
        t.truthy(resetJoined:find("applied %d+ restored %d+"),
            "[Reset] carries the material apply counts")
    end)
end
