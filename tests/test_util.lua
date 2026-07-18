-- tests/test_util.lua — ns.Util secret-safe output helpers (events-frames-taint-§8).
-- A Blizzard combat "secret" raises when it hits `..` / string.format, so the shared
-- printer and debug sink route values through these: IsConcatSafe probes with
-- table.concat (never `..`, which would itself raise on a secret); SafeToString
-- returns a display string, substituting "<secret>" for anything the probe rejects.

return function(ctx)
    local t    = ctx.t
    local test = ctx.test
    local ns   = ctx.loadAddon().ns
    local U    = ns.Util

    test("SafeToString renders scalars and nil verbatim", function()
        t.eq(U.SafeToString("hi"),  "hi",    "string passes through")
        t.eq(U.SafeToString(42),    "42",    "number stringifies")
        t.eq(U.SafeToString(true),  "true",  "boolean true")
        t.eq(U.SafeToString(false), "false", "boolean false")
        t.eq(U.SafeToString(nil),   "nil",   "nil renders as the word nil")
    end)

    test("SafeToString substitutes <secret> for a value table.concat rejects", function()
        -- Stand-in for a combat "secret": a table whose use in a `..` / table.concat
        -- chain raises. SafeToString must neither throw nor leak the value.
        local secret = setmetatable({}, { __concat = function() error("secret") end })
        local ok, res = pcall(U.SafeToString, secret)
        t.truthy(ok, "SafeToString never raises on an unconcatenable value")
        t.eq(res, "<secret>", "unconcatenable value renders as <secret>")
    end)

    test("IsConcatSafe probes concatenability via table.concat, not ..", function()
        t.truthy(U.IsConcatSafe("s"), "strings are concat-safe")
        t.truthy(U.IsConcatSafe(7),   "numbers are concat-safe")
        t.falsy(U.IsConcatSafe(true), "booleans are not directly concat-safe")
        t.falsy(U.IsConcatSafe({}),   "tables are not concat-safe")
    end)
end
