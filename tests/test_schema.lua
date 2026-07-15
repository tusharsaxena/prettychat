-- tests/test_schema.lua — path resolution, Get/Set, and the single
-- write-path side effects (ApplyStrings runs on every Set).

local function firstFormatRow(Schema, category)
    for _, row in ipairs(Schema.RowsByCategory(category)) do
        if row.kind == "string_format" then return row end
    end
end

return function(ctx)
    local t = ctx.t
    local test = ctx.test
    local inst   = ctx.loadAddon()
    local Schema = inst.ns.Schema
    local env    = inst.env
    local row    = firstFormatRow(Schema, "Loot")

    test("resolves known setting paths and returns nil for unknown ones", function()
        t.truthy(Schema.FindByPath("General.enabled"), "General.enabled resolves")
        t.truthy(Schema.FindByPath("Loot.enabled"),    "Loot.enabled resolves")
        t.falsy(Schema.FindByPath("Nope.nope"),        "unknown path is nil")
        t.nilv(Schema.Get("Nope.nope"),               "Get on unknown path is nil")
    end)

    test("resolves categories case-insensitively and by prefix", function()
        t.eq(Schema.ResolveCategory("loot"), "Loot", "case-insensitive category")
        t.eq(Schema.ResolveCategory("Curr"), "Currency", "prefix category")
        t.nilv(Schema.ResolveCategory("zzz"), "unknown category is nil")
    end)

    test("master toggle round-trips through the single write path", function()
        Schema.Set("General.enabled", false)
        t.eq(Schema.Get("General.enabled"), false, "master set false")
        Schema.Set("General.enabled", true)
        t.eq(Schema.Get("General.enabled"), true, "master set true")
    end)

    test("Set on a format pushes the override to _G via ApplyStrings", function()
        t.truthy(row, "found a Loot format row")
        Schema.Set(row.path, "CUSTOM %s")
        t.eq(Schema.Get(row.path), "CUSTOM %s", "Get returns stored override")
        t.eq(env[row.globalName], "CUSTOM %s", "ApplyStrings pushed override to _G")
    end)

    test("re-setting a format to its default auto-clears the stored override", function()
        Schema.Set(row.path, row.default)
        t.eq(Schema.Get(row.path), row.default, "reset to default via Set")
        local catDB = inst.addon.db.profile.categories[row.category]
        t.truthy(not (catDB and catDB.strings and catDB.strings[row.globalName]),
            "default value auto-clears the stored override")
    end)

    test("Set on an unknown path is a no-op returning false", function()
        t.falsy(Schema.Set("Nope.nope", true), "Set unknown path returns false")
    end)

    test("load-time schema path validation resolved every path", function()
        t.truthy(Schema.validation, "schema validation stashed at load")
        t.truthy(Schema.validation.checked > 0, "validator checked rows")
        t.eq(Schema.validation.failed, 0, "every schema path resolves to a backing default")
    end)
end
