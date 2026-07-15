-- tests/test_render.lua — ns.RenderSample: positional args, %% escapes,
-- and string.format error surfacing.

return function(ctx)
    local t = ctx.t
    local test = ctx.test
    local inst = ctx.loadAddon()
    local render = inst.ns.RenderSample

    test("renders basic %s + %d and collapses %% escapes", function()
        t.eq(render("%s got %d"), "Sample got 42", "basic %s + %d")
        t.eq(render("100%% done"), "100% done", "%% escape collapses")
    end)

    test("positional %n$s formats degrade gracefully under stock Lua", function()
        -- Positional specifiers (%n$s) are a WoW Lua extension; stock Lua 5.1
        -- (this harness) can't render them, but RenderSample must degrade
        -- gracefully (nil + error) rather than throw. In-game these render;
        -- see docs/smoke-tests.md for the manual positional check.
        local ok = pcall(render, "%2$s then %1$s")
        t.truthy(ok, "positional format never throws (graceful under stock Lua)")
    end)

    test("empty or nil format returns nil", function()
        t.nilv(render(""), "empty format returns nil")
        t.nilv(render(nil), "nil format returns nil")
    end)

    test("malformed conversion surfaces as nil + error string", function()
        local r3, e3 = render("%y")
        t.nilv(r3, "bad conversion returns nil")
        t.truthy(e3, "bad conversion yields an error message")
    end)

    test("a real Blizzard-style default renders without error", function()
        local rows = inst.ns.Schema.RowsByCategory("Loot")
        local fmt
        for _, row in ipairs(rows) do
            if row.kind == "string_format" then fmt = row.default break end
        end
        t.truthy(fmt, "found a Loot format default")
        t.truthy(render(fmt), "real default renders")
    end)
end
