-- tests/test_slash.lua — slash-commands-§5 output conformance: the shared
-- schema-driven value formatter, the FormatKV gold/white `get` echo, the
-- green-header / azure-group `list` colours, and the `version` verb.

local function run(ns, addon, name, rest)
    for _, e in ipairs(ns.COMMANDS) do
        if e[1] == name then return e[3](addon, rest or "") end
    end
    error("no '" .. name .. "' command in ns.COMMANDS")
end

local function last(env) return env.DEFAULT_CHAT_FRAME.messages[#env.DEFAULT_CHAT_FRAME.messages] end
local function has(env, needle)
    for _, m in ipairs(env.DEFAULT_CHAT_FRAME.messages) do
        if m:find(needle, 1, true) then return true end
    end
    return false
end

return function(ctx)
    local t     = ctx.t
    local test  = ctx.test
    local inst  = ctx.loadAddon()
    local ns    = inst.ns
    local addon = inst.addon
    local env   = inst.env
    local C      = ns.Const.Color
    local PREFIX = ns.PREFIX
    local Schema = ns.Schema

    test("Schema.FormatValue formats bools and doubles pipes in strings", function()
        -- bool → true/false; string → the raw format with `|` doubled.
        local boolRow = Schema.FindByPath("General.enabled")
        t.eq(Schema.FormatValue(boolRow, true),  "true",  "bool true formats as `true`")
        t.eq(Schema.FormatValue(boolRow, false), "false", "bool false formats as `false`")
        t.eq(Schema.FormatValue({ type = "string" }, "|cffff0000%s|r"),
            "||cffff0000%s||r", "string value doubles pipes so colour escapes show as text")
    end)

    test("ns.Print emits the cyan [PC] tag (reclaimed after the AceConsole embed)", function()
        -- architecture-§2 / anti-pattern #36: NewAddon is passed the ns table, so
        -- AceConsole's :Print embed lands on ns and would clobber the cyan printer.
        -- core/PrettyChat.lua reclaims ns.Print right after registration — assert it
        -- still prepends the [PC] PREFIX, not AceConsole's |cff33ff99Name|r: tag.
        ns.Print("hello")
        local line = last(env)
        t.eq(line, PREFIX .. "hello", "ns.Print prepends the cyan [PC] prefix")
        t.falsy(line:find("|cff33ff99", 1, true), "AceConsole's embed did not win")
    end)

    test("/pc version prints the tagged version line", function()
        run(ns, addon, "version")
        t.eq(last(env), PREFIX .. "v" .. ctx.mock.metadata.Version,
            "/pc version prints the tagged version line")
    end)

    test("/pc get echoes the gold-key/white-value FormatKV line", function()
        run(ns, addon, "get", "General.enabled")
        t.eq(last(env),
            PREFIX .. C.yellow .. "General.enabled" .. C.reset .. " = " .. C.white .. "true" .. C.reset,
            "/pc get echoes the gold-key/white-value FormatKV line")
    end)

    test("/pc test routes every line through the [PC] printer", function()
        -- PC-35 / events-frames-taint-§8: Test() prints through ns.Print, never
        -- straight to the chat frame, so every emitted line carries the [PC] tag.
        local before = #env.DEFAULT_CHAT_FRAME.messages
        run(ns, addon, "test", "category Loot")
        local msgs = env.DEFAULT_CHAT_FRAME.messages
        t.truthy(#msgs > before, "/pc test emits output")
        local allTagged = true
        for i = before + 1, #msgs do
            if msgs[i]:sub(1, #PREFIX) ~= PREFIX then allTagged = false end
        end
        t.truthy(allTagged, "every /pc test line begins with the [PC] prefix")
    end)

    test("/pc list prints the green header and azure category groups", function()
        run(ns, addon, "list", "")
        t.truthy(has(env, C.listHead .. "Available settings" .. C.reset),
            "/pc list prints the green Available settings header")
        t.truthy(has(env, C.azure .. "[General]" .. C.reset),
            "/pc list prints azure [category] group headers")
    end)
end
