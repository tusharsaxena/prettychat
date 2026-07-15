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
    local inst  = ctx.loadAddon()
    local ns    = inst.ns
    local addon = inst.addon
    local env   = inst.env
    local C      = ns.Const.Color
    local PREFIX = ns.PREFIX
    local Schema = ns.Schema

    -- Schema.FormatValue: bool → true/false; string → the raw format with `|` doubled.
    local boolRow = Schema.FindByPath("General.enabled")
    t.eq(Schema.FormatValue(boolRow, true),  "true",  "bool true formats as `true`")
    t.eq(Schema.FormatValue(boolRow, false), "false", "bool false formats as `false`")
    t.eq(Schema.FormatValue({ type = "string" }, "|cffff0000%s|r"),
        "||cffff0000%s||r", "string value doubles pipes so colour escapes show as text")

    -- version verb → `[PC] v<version>` (single greppable line).
    run(ns, addon, "version")
    t.eq(last(env), PREFIX .. "v" .. ctx.mock.metadata.Version,
        "/pc version prints the tagged version line")

    -- get → single-line FormatKV: gold path, ` = `, white value.
    run(ns, addon, "get", "General.enabled")
    t.eq(last(env),
        PREFIX .. C.yellow .. "General.enabled" .. C.reset .. " = " .. C.white .. "true" .. C.reset,
        "/pc get echoes the gold-key/white-value FormatKV line")

    -- list → green "Available settings" header + azure [category] group headers.
    run(ns, addon, "list", "")
    t.truthy(has(env, C.listHead .. "Available settings" .. C.reset),
        "/pc list prints the green Available settings header")
    t.truthy(has(env, C.azure .. "[General]" .. C.reset),
        "/pc list prints azure [category] group headers")
end
