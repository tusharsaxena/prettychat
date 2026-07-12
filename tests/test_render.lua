-- tests/test_render.lua — ns.RenderSample: positional args, %% escapes,
-- and string.format error surfacing.

return function(ctx)
    local t = ctx.t
    local inst = ctx.loadAddon()
    local render = inst.ns.RenderSample

    t.eq(render("%s got %d"), "Sample got 42", "basic %s + %d")
    t.eq(render("100%% done"), "100% done", "%% escape collapses")

    -- Positional specifiers (%n$s) are a WoW Lua extension; stock Lua 5.1
    -- (this harness) can't render them, but RenderSample must degrade
    -- gracefully (nil + error) rather than throw. In-game these render;
    -- see docs/smoke-tests.md for the manual positional check.
    local ok = pcall(render, "%2$s then %1$s")
    t.truthy(ok, "positional format never throws (graceful under stock Lua)")

    -- Empty / non-string input returns nil + message.
    local r1 = render("")
    t.nilv(r1, "empty format returns nil")
    local r2 = render(nil)
    t.nilv(r2, "nil format returns nil")

    -- Malformed conversion (%y) surfaces as nil + error string.
    local r3, e3 = render("%y")
    t.nilv(r3, "bad conversion returns nil")
    t.truthy(e3, "bad conversion yields an error message")

    -- A real Blizzard-style default renders without error.
    local rows = inst.ns.Schema.RowsByCategory("Loot")
    local fmt
    for _, row in ipairs(rows) do
        if row.kind == "string_format" then fmt = row.default break end
    end
    t.truthy(fmt, "found a Loot format default")
    t.truthy(render(fmt), "real default renders")
end
