-- tests/test_schema.lua — path resolution, Get/Set, and the single
-- write-path side effects (ApplyStrings runs on every Set).

local function firstFormatRow(Schema, category)
    for _, row in ipairs(Schema.RowsByCategory(category)) do
        if row.kind == "string_format" then return row end
    end
end

return function(ctx)
    local t = ctx.t
    local inst   = ctx.loadAddon()
    local Schema = inst.ns.Schema
    local env    = inst.env

    -- Path resolution.
    t.truthy(Schema.FindByPath("General.enabled"), "General.enabled resolves")
    t.truthy(Schema.FindByPath("Loot.enabled"),    "Loot.enabled resolves")
    t.falsy(Schema.FindByPath("Nope.nope"),        "unknown path is nil")
    t.nilv(Schema.Get("Nope.nope"),               "Get on unknown path is nil")

    -- Category resolution (case-insensitive + prefix).
    t.eq(Schema.ResolveCategory("loot"), "Loot", "case-insensitive category")
    t.eq(Schema.ResolveCategory("Curr"), "Currency", "prefix category")
    t.nilv(Schema.ResolveCategory("zzz"), "unknown category is nil")

    -- Master toggle round-trips through the single write path.
    Schema.Set("General.enabled", false)
    t.eq(Schema.Get("General.enabled"), false, "master set false")
    Schema.Set("General.enabled", true)
    t.eq(Schema.Get("General.enabled"), true, "master set true")

    -- Setting a format writes _G via ApplyStrings (single write path).
    local row = firstFormatRow(Schema, "Loot")
    t.truthy(row, "found a Loot format row")
    Schema.Set(row.path, "CUSTOM %s")
    t.eq(Schema.Get(row.path), "CUSTOM %s", "Get returns stored override")
    t.eq(env[row.globalName], "CUSTOM %s", "ApplyStrings pushed override to _G")

    -- Auto-clear: re-setting to the default drops the stored value.
    Schema.Set(row.path, row.default)
    t.eq(Schema.Get(row.path), row.default, "reset to default via Set")
    local catDB = inst.addon.db.profile.categories[row.category]
    t.truthy(not (catDB and catDB.strings and catDB.strings[row.globalName]),
        "default value auto-clears the stored override")

    -- Set on an unknown path is a no-op returning false.
    t.falsy(Schema.Set("Nope.nope", true), "Set unknown path returns false")

    -- Load-time path validator (PC-15) ran and every path resolved.
    t.truthy(Schema.validation, "schema validation stashed at load")
    t.truthy(Schema.validation.checked > 0, "validator checked rows")
    t.eq(Schema.validation.failed, 0, "every schema path resolves to a backing default")
end
